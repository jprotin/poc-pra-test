###############################################################################
# MODULE ZERTO VPG - VMware vSphere
###############################################################################
# Description: Module pour créer et gérer un Virtual Protection Group Zerto
#              sur VMware Hosted Private Cloud OVHcloud
# Usage: Protection bi-directionnelle entre RBX et SBG
###############################################################################

terraform {
  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}

###############################################################################
# LOCALS - CALCULS ET TRANSFORMATIONS
###############################################################################

locals {
  # Génération du nom complet du VPG
  vpg_full_name = "${var.vpg_name}-${formatdate("YYYYMMDD", timestamp())}"

  # Mapping des VMs avec leurs configurations VMware
  vm_configs = {
    for vm in var.protected_vms : vm.name => {
      vm_name_vcenter = vm.vm_name_vcenter
      vm_uuid        = vm.vm_uuid
      boot_order     = vm.boot_order
      failover_ip    = vm.failover_ip
      failover_subnet = vm.failover_subnet
      description    = vm.description
    }
  }

  # Configuration du journal Zerto
  journal_datastore_size_gb = var.journal_history_hours * 10  # 10 GB par heure (estimation)

  # Tags fusionnés avec les tags du module
  merged_tags = merge(
    var.tags,
    {
      "VPG-Name"         = var.vpg_name
      "Source-Site"      = var.source_site_name
      "Target-Site"      = var.target_site_name
      "Source-vCenter"   = var.source_vcenter
      "Target-vCenter"   = var.target_vcenter
      "Created-Date"     = formatdate("YYYY-MM-DD", timestamp())
      "Terraform-Module" = "zerto-vpg-vmware"
      "Platform"         = "VMware-vSphere"
    }
  )
}

###############################################################################
# RESSOURCE NULL - CRÉATION DU VPG VIA API ZERTO
###############################################################################

# Note: Zerto n'a pas de provider Terraform officiel
# Utilisation de l'API REST Zerto via provisioners et scripts externes

resource "null_resource" "zerto_vpg" {
  # Recréer si les VMs protégées changent
  triggers = {
    vpg_name      = var.vpg_name
    source_site   = var.source_site_id
    target_site   = var.target_site_id
    protected_vms = jsonencode(var.protected_vms)
    rpo_seconds   = var.rpo_seconds
  }

  # Création du VPG via script Shell/API
  provisioner "local-exec" {
    command = "${path.module}/scripts/create-vpg.sh"

    environment = {
      # Identification VPG
      VPG_NAME           = var.vpg_name
      VPG_DESCRIPTION    = var.description

      # Sites Zerto
      SOURCE_SITE_ID     = var.source_site_id
      TARGET_SITE_ID     = var.target_site_id
      SOURCE_SITE_NAME   = var.source_site_name
      TARGET_SITE_NAME   = var.target_site_name

      # vCenter source et cible
      SOURCE_VCENTER     = var.source_vcenter
      SOURCE_DATACENTER  = var.source_datacenter
      SOURCE_CLUSTER     = var.source_cluster
      TARGET_VCENTER     = var.target_vcenter
      TARGET_DATACENTER  = var.target_datacenter
      TARGET_CLUSTER     = var.target_cluster

      # Configuration Zerto
      RPO_SECONDS        = var.rpo_seconds
      JOURNAL_HOURS      = var.journal_history_hours
      PRIORITY           = var.priority
      ENABLE_COMPRESSION = var.enable_compression
      ENABLE_ENCRYPTION  = var.enable_encryption
      WAN_ACCELERATION   = var.wan_acceleration

      # VMs à protéger (JSON avec UUIDs vSphere)
      PROTECTED_VMS_JSON = jsonencode(var.protected_vms)

      # Configuration réseau cible
      TARGET_NETWORK_NAME     = var.target_network_name
      TARGET_DATASTORE_NAME   = var.target_datastore_name
      TARGET_RESOURCE_POOL_ID = var.target_resource_pool_id
      NETWORK_CONFIG_JSON     = jsonencode(var.failover_network_config)
      FORTIGATE_CONFIG_JSON   = jsonencode(var.fortigate_config)

      # API Zerto
      ZERTO_API_ENDPOINT = var.zerto_api_endpoint
      ZERTO_API_TOKEN    = var.zerto_api_token
    }
  }

  # Suppression du VPG
  provisioner "local-exec" {
    when    = destroy
    command = "${path.module}/scripts/delete-vpg.sh ${self.triggers.vpg_name}"

    environment = {
      ZERTO_API_ENDPOINT = var.zerto_api_endpoint
      ZERTO_API_TOKEN    = var.zerto_api_token
    }
  }
}

###############################################################################
# DATA SOURCE - RÉCUPÉRATION DES INFORMATIONS DU VPG CRÉÉ
###############################################################################

# Attendre que le VPG soit créé avant de récupérer ses informations
data "http" "vpg_status" {
  url = "${var.zerto_api_endpoint}/v1/vpgs?name=${var.vpg_name}"

  request_headers = {
    "Authorization" = "Bearer ${var.zerto_api_token}"
    "Content-Type"  = "application/json"
  }

  depends_on = [null_resource.zerto_vpg]
}

###############################################################################
# RESSOURCE NULL - CONFIGURATION DES VMs DANS LE VPG
###############################################################################

resource "null_resource" "configure_vms" {
  for_each = local.vm_configs

  triggers = {
    vm_name     = each.key
    failover_ip = each.value.failover_ip
    boot_order  = each.value.boot_order
    vpg_name    = var.vpg_name
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/configure-vm.sh"

    environment = {
      VPG_NAME          = var.vpg_name
      VM_NAME           = each.key
      VM_NAME_VCENTER   = each.value.vm_name_vcenter
      VM_UUID           = each.value.vm_uuid
      BOOT_ORDER        = each.value.boot_order
      FAILOVER_IP       = each.value.failover_ip
      FAILOVER_SUBNET   = each.value.failover_subnet
      VM_DESCRIPTION    = each.value.description
      ZERTO_API_ENDPOINT = var.zerto_api_endpoint
      ZERTO_API_TOKEN   = var.zerto_api_token
    }
  }

  depends_on = [null_resource.zerto_vpg]
}

###############################################################################
# RESSOURCE NULL - CONFIGURATION DES SCRIPTS DE FAILOVER
###############################################################################

resource "null_resource" "failover_scripts" {
  triggers = {
    vpg_name     = var.vpg_name
    source_site  = var.source_site_id
    target_site  = var.target_site_id
    fortigate_ip = var.fortigate_config.sbg_fortigate_ip != null ? var.fortigate_config.sbg_fortigate_ip : var.fortigate_config.rbx_fortigate_ip
  }

  # Générer les scripts de failover personnalisés
  provisioner "local-exec" {
    command = "${path.module}/scripts/generate-failover-scripts.sh"

    environment = {
      VPG_NAME          = var.vpg_name
      SOURCE_SITE_ID    = var.source_site_id
      TARGET_SITE_ID    = var.target_site_id
      SOURCE_SITE_NAME  = var.source_site_name
      TARGET_SITE_NAME  = var.target_site_name
      FORTIGATE_CONFIG  = jsonencode(var.fortigate_config)
      NETWORK_CONFIG    = jsonencode(var.failover_network_config)
      OUTPUT_DIR        = "${path.root}/../../scripts/generated"
    }
  }

  depends_on = [
    null_resource.zerto_vpg,
    null_resource.configure_vms
  ]
}

###############################################################################
# FICHIER LOCAL - INVENTAIRE ANSIBLE POUR CE VPG
###############################################################################

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/ansible-inventory.tpl", {
    vpg_name         = var.vpg_name
    source_site      = var.source_site_name
    target_site      = var.target_site_name
    source_vcenter   = var.source_vcenter
    target_vcenter   = var.target_vcenter
    protected_vms    = var.protected_vms
    fortigate_config = var.fortigate_config
  })

  filename = "${path.root}/../../ansible/inventory/vpg-${var.vpg_name}.yml"

  depends_on = [null_resource.zerto_vpg]
}

###############################################################################
# FICHIER LOCAL - CONFIGURATION DE MONITORING
###############################################################################

resource "local_file" "monitoring_config" {
  content = templatefile("${path.module}/templates/monitoring-config.tpl", {
    vpg_name          = var.vpg_name
    rpo_seconds       = var.rpo_seconds
    journal_hours     = var.journal_history_hours
    test_interval     = var.test_interval_hours
    source_site_id    = var.source_site_id
    target_site_id    = var.target_site_id
    source_vcenter    = var.source_vcenter
    target_vcenter    = var.target_vcenter
  })

  filename = "${path.root}/../../ansible/playbooks/configs/monitoring-${var.vpg_name}.yml"

  depends_on = [null_resource.zerto_vpg]
}
