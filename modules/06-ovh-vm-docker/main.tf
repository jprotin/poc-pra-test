# ==============================================================================
# Module Terraform : OVH VMware VM Docker
# ==============================================================================
# Description : Provisioning d'une VM Ubuntu avec Docker et Docker Compose
#               sur infrastructure OVH Private Cloud VMware vSphere
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.6"
    }
  }
}

# ------------------------------------------------------------------------------
# Data Sources - vSphere Objects
# ------------------------------------------------------------------------------

# Récupération du datacenter vSphere
data "vsphere_datacenter" "dc" {
  name = var.vsphere_datacenter
}

# Récupération du cluster vSphere
data "vsphere_compute_cluster" "cluster" {
  name          = var.vsphere_cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Récupération du datastore
data "vsphere_datastore" "datastore" {
  name          = var.vsphere_datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Récupération du réseau (port group)
data "vsphere_network" "network" {
  name          = var.vsphere_network
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Récupération du template Ubuntu
data "vsphere_virtual_machine" "template" {
  name          = var.vm_template
  datacenter_id = data.vsphere_datacenter.dc.id
}

# ------------------------------------------------------------------------------
# Cloud-init Configuration
# ------------------------------------------------------------------------------

# Script cloud-init pour installation Docker et hardening
locals {
  cloud_init_config = templatefile("${path.module}/templates/cloud-init.yaml.tpl", {
    hostname                 = var.vm_name
    domain                   = var.vm_domain_name
    admin_username           = var.admin_username
    admin_ssh_public_key     = var.admin_ssh_public_key
    docker_version           = var.docker_version
    docker_compose_version   = var.docker_compose_version
    enable_docker_monitoring = var.enable_docker_monitoring
    enable_firewall          = var.enable_firewall
    allowed_ssh_cidrs        = jsonencode(var.allowed_ssh_cidrs)
    enable_automatic_updates = var.enable_automatic_updates
    timezone                 = "Europe/Paris"
    dns_servers              = jsonencode(var.vm_dns_servers)
  })

  # Métadonnées additionnelles
  vm_tags = merge(
    {
      "Name"        = var.vm_name
      "Environment" = var.environment
      "Project"     = var.project_name
      "Owner"       = var.owner
      "Role"        = "docker-host"
      "ManagedBy"   = "terraform"
      "CreatedDate" = timestamp()
    },
    var.tags
  )
}

# ------------------------------------------------------------------------------
# Virtual Machine - Docker Host
# ------------------------------------------------------------------------------

resource "vsphere_virtual_machine" "docker_vm" {
  name             = var.vm_name
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = "/${var.vsphere_datacenter}/vm/${var.project_name}"

  num_cpus               = var.vm_num_cpus
  num_cores_per_socket   = 2 # Optimisation performance (2 sockets pour 4 vCPUs)
  memory                 = var.vm_memory_mb
  guest_id               = data.vsphere_virtual_machine.template.guest_id
  firmware               = "efi" # EFI pour support Secure Boot
  efi_secure_boot_enabled = true

  # Options de performance
  cpu_hot_add_enabled    = true
  memory_hot_add_enabled = true

  # Network Interface Card (NIC)
  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  # Disque principal (OS + Docker)
  disk {
    label            = "${var.vm_name}-disk0"
    size             = var.vm_disk_size_gb
    thin_provisioned = true # Thin provisioning pour économie d'espace
    eagerly_scrub    = false
  }

  # Disque additionnel optionnel pour volumes Docker
  dynamic "disk" {
    for_each = var.vm_additional_disk_size_gb > 0 ? [1] : []
    content {
      label            = "${var.vm_name}-docker-volumes"
      size             = var.vm_additional_disk_size_gb
      thin_provisioned = true
      unit_number      = 1
    }
  }

  # Clonage depuis template Ubuntu
  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      linux_options {
        host_name = var.vm_name
        domain    = var.vm_domain_name
        time_zone = "Europe/Paris"
      }

      network_interface {
        ipv4_address = var.vm_ipv4_address
        ipv4_netmask = var.vm_ipv4_netmask
      }

      ipv4_gateway    = var.vm_ipv4_gateway
      dns_server_list = var.vm_dns_servers
    }
  }

  # Injection de cloud-init via vApp properties
  extra_config = merge(
    {
      "guestinfo.metadata"          = base64encode(local.cloud_init_config)
      "guestinfo.metadata.encoding" = "base64"
      "guestinfo.userdata"          = base64encode(local.cloud_init_config)
      "guestinfo.userdata.encoding" = "base64"
    },
    # Configuration PRA - Failback Mode Pause (ADR-2025-12-30)
    var.enable_failback_pause_mode ? {
      "pra.failback.startup_mode" = "suspended"
      "pra.failback.site"         = var.failback_site
      "pra.failback.enabled"      = "true"
    } : {}
  )

  # Cycle de vie
  lifecycle {
    ignore_changes = [
      clone[0].template_uuid, # Ignore les changements de template après création
      extra_config,           # Ignore les changements de cloud-init post-déploiement
    ]
    create_before_destroy = false
  }

  # Attendre que VMware Tools soit démarré
  wait_for_guest_net_timeout  = 10 # minutes
  wait_for_guest_net_routable = true

  # Tags vSphere (si supporté par la version vCenter)
  # Note: Nécessite vCenter 6.5+ avec tagging activé
  # tags = [for k, v in local.vm_tags : "${k}:${v}"]
}

# ------------------------------------------------------------------------------
# Provisioning post-déploiement (optionnel)
# ------------------------------------------------------------------------------

# Attendre que cloud-init soit terminé avant de considérer la VM prête
resource "null_resource" "wait_cloud_init" {
  depends_on = [vsphere_virtual_machine.docker_vm]

  # Utilisation de provisioner local-exec pour vérifier cloud-init via SSH
  provisioner "local-exec" {
    command = <<-EOT
      echo "⏳ Attente de la fin de cloud-init sur ${var.vm_name}..."
      max_attempts=30
      attempt=1

      while [ $attempt -le $max_attempts ]; do
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
               ${var.admin_username}@${var.vm_ipv4_address} \
               "cloud-init status --wait" 2>/dev/null; then
          echo "✅ Cloud-init terminé avec succès"
          exit 0
        fi
        echo "Tentative $attempt/$max_attempts - Attente 10s..."
        sleep 10
        attempt=$((attempt + 1))
      done

      echo "⚠️  Timeout: cloud-init n'a pas terminé après 5 minutes"
      exit 1
    EOT
  }

  triggers = {
    vm_id = vsphere_virtual_machine.docker_vm.id
  }
}
