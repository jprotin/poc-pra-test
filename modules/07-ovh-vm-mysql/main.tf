# ==============================================================================
# Module Terraform : OVH VMware VM MySQL
# ==============================================================================
# Description : Provisioning d'une VM Ubuntu avec MySQL 8.0 optimisée
#               pour bases de données de production sur vSphere OVH
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

locals {
  cloud_init_config = templatefile("${path.module}/templates/cloud-init.yaml.tpl", {
    hostname                     = var.vm_name
    domain                       = var.vm_domain_name
    admin_username               = var.admin_username
    admin_ssh_public_key         = var.admin_ssh_public_key
    mysql_version                = var.mysql_version
    mysql_root_password          = var.mysql_root_password
    mysql_database_name          = var.mysql_database_name
    mysql_app_user               = var.mysql_app_user
    mysql_app_password           = var.mysql_app_password
    mysql_allowed_hosts          = jsonencode(var.mysql_allowed_hosts)
    mysql_innodb_buffer_pool     = var.mysql_innodb_buffer_pool_size
    mysql_max_connections        = var.mysql_max_connections
    enable_mysql_backup          = var.enable_mysql_backup
    mysql_backup_retention_days  = var.mysql_backup_retention_days
    enable_mysql_monitoring      = var.enable_mysql_monitoring
    enable_firewall              = var.enable_firewall
    allowed_mysql_cidrs          = jsonencode(var.allowed_mysql_cidrs)
    allowed_ssh_cidrs            = jsonencode(var.allowed_ssh_cidrs)
    enable_automatic_updates     = var.enable_automatic_updates
    timezone                     = "Europe/Paris"
    dns_servers                  = jsonencode(var.vm_dns_servers)
  })

  # Métadonnées additionnelles
  vm_tags = merge(
    {
      "Name"        = var.vm_name
      "Environment" = var.environment
      "Project"     = var.project_name
      "Owner"       = var.owner
      "Role"        = "mysql-database"
      "ManagedBy"   = "terraform"
      "CreatedDate" = timestamp()
    },
    var.tags
  )
}

# ------------------------------------------------------------------------------
# Virtual Machine - MySQL Database
# ------------------------------------------------------------------------------

resource "vsphere_virtual_machine" "mysql_vm" {
  name             = var.vm_name
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = "/${var.vsphere_datacenter}/vm/${var.project_name}"

  num_cpus               = var.vm_num_cpus
  num_cores_per_socket   = 2
  memory                 = var.vm_memory_mb
  guest_id               = data.vsphere_virtual_machine.template.guest_id
  firmware               = "efi"
  efi_secure_boot_enabled = true

  # Options de performance (MySQL nécessite CPU/RAM stables)
  cpu_hot_add_enabled    = true
  memory_hot_add_enabled = true
  cpu_reservation        = var.vm_num_cpus * 1000 # Réservation 1 GHz par vCPU
  memory_reservation     = var.vm_memory_mb        # Réservation totale RAM

  # Network Interface Card (NIC)
  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  # Disque 0 : OS (Ubuntu)
  disk {
    label            = "${var.vm_name}-disk0-os"
    size             = var.vm_disk_size_gb
    thin_provisioned = true
    eagerly_scrub    = false
  }

  # Disque 1 : Données MySQL (/var/lib/mysql)
  # Utilisation de thick provisioning eager zeroed pour meilleures performances
  disk {
    label            = "${var.vm_name}-disk1-data"
    size             = var.vm_data_disk_size_gb
    thin_provisioned = false
    eagerly_scrub    = true # Meilleure performance pour I/O MySQL
    unit_number      = 1
  }

  # Disque 2 : Logs MySQL (optionnel, /var/log/mysql)
  dynamic "disk" {
    for_each = var.vm_log_disk_size_gb > 0 ? [1] : []
    content {
      label            = "${var.vm_name}-disk2-logs"
      size             = var.vm_log_disk_size_gb
      thin_provisioned = false
      eagerly_scrub    = true
      unit_number      = 2
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
  extra_config = {
    "guestinfo.metadata"          = base64encode(local.cloud_init_config)
    "guestinfo.metadata.encoding" = "base64"
    "guestinfo.userdata"          = base64encode(local.cloud_init_config)
    "guestinfo.userdata.encoding" = "base64"
  }

  # Cycle de vie
  lifecycle {
    ignore_changes = [
      clone[0].template_uuid,
      extra_config,
    ]
    create_before_destroy = false
  }

  # Attendre que VMware Tools soit démarré
  wait_for_guest_net_timeout  = 15 # minutes (MySQL init peut être long)
  wait_for_guest_net_routable = true
}

# ------------------------------------------------------------------------------
# Provisioning post-déploiement
# ------------------------------------------------------------------------------

# Attendre que cloud-init soit terminé et MySQL démarré
resource "null_resource" "wait_mysql_ready" {
  depends_on = [vsphere_virtual_machine.mysql_vm]

  provisioner "local-exec" {
    command = <<-EOT
      echo "⏳ Attente de la fin de cloud-init et démarrage MySQL sur ${var.vm_name}..."
      max_attempts=60
      attempt=1

      while [ $attempt -le $max_attempts ]; do
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
               ${var.admin_username}@${var.vm_ipv4_address} \
               "cloud-init status --wait && systemctl is-active mysql" 2>/dev/null; then
          echo "✅ MySQL démarré avec succès"
          exit 0
        fi
        echo "Tentative $attempt/$max_attempts - Attente 10s..."
        sleep 10
        attempt=$((attempt + 1))
      done

      echo "⚠️  Timeout: MySQL n'a pas démarré après 10 minutes"
      exit 1
    EOT
  }

  triggers = {
    vm_id = vsphere_virtual_machine.mysql_vm.id
  }
}
