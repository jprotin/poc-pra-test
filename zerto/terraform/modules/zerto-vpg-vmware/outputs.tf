###############################################################################
# MODULE ZERTO VPG - OUTPUTS
###############################################################################

###############################################################################
# OUTPUTS VPG
###############################################################################

output "vpg_id" {
  description = "ID du Virtual Protection Group"
  value       = try(jsondecode(data.http.vpg_status.response_body)[0].VpgIdentifier, "")
}

output "vpg_name" {
  description = "Nom du Virtual Protection Group"
  value       = var.vpg_name
}

output "vpg_status" {
  description = "État du VPG"
  value       = try(jsondecode(data.http.vpg_status.response_body)[0].Status, "unknown")
}

output "current_rpo" {
  description = "RPO actuel en secondes"
  value       = try(jsondecode(data.http.vpg_status.response_body)[0].ActualRPO, var.rpo_seconds)
}

###############################################################################
# OUTPUTS VMs PROTÉGÉES
###############################################################################

output "protected_vms" {
  description = "Liste des VMs protégées avec leurs configurations"
  value = [
    for vm in var.protected_vms : {
      name           = vm.name
      instance_id    = vm.instance_id
      boot_order     = vm.boot_order
      failover_ip    = vm.failover_ip
      failover_subnet = vm.failover_subnet
      description    = vm.description
      status         = "protected"
    }
  ]
}

output "protected_vms_count" {
  description = "Nombre de VMs protégées"
  value       = length(var.protected_vms)
}

###############################################################################
# OUTPUTS SITES
###############################################################################

output "source_site" {
  description = "Information sur le site source"
  value = {
    region  = var.source_region
    site_id = var.source_site_id
  }
}

output "target_site" {
  description = "Information sur le site cible"
  value = {
    region  = var.target_region
    site_id = var.target_site_id
  }
}

###############################################################################
# OUTPUTS CONFIGURATION
###############################################################################

output "replication_config" {
  description = "Configuration de la réplication"
  value = {
    rpo_seconds       = var.rpo_seconds
    journal_hours     = var.journal_history_hours
    priority          = var.priority
    compression       = var.enable_compression
    encryption        = var.enable_encryption
    wan_acceleration  = var.wan_acceleration
  }
}

output "network_config" {
  description = "Configuration réseau du failover"
  value = {
    network_id     = var.target_network_id
    subnet_id      = var.target_subnet_id
    gateway        = var.failover_network_config.gateway
    dns_primary    = var.failover_network_config.dns_primary
    dns_secondary  = var.failover_network_config.dns_secondary
    domain_name    = var.failover_network_config.domain_name
  }
}

###############################################################################
# OUTPUTS FICHIERS GÉNÉRÉS
###############################################################################

output "ansible_inventory_file" {
  description = "Chemin du fichier d'inventaire Ansible généré"
  value       = local_file.ansible_inventory.filename
}

output "monitoring_config_file" {
  description = "Chemin du fichier de configuration monitoring généré"
  value       = local_file.monitoring_config.filename
}

###############################################################################
# OUTPUTS POUR SCRIPTS DE FAILOVER
###############################################################################

output "failover_info" {
  description = "Informations pour les scripts de failover"
  value = {
    vpg_name       = var.vpg_name
    source_region  = var.source_region
    target_region  = var.target_region
    source_site_id = var.source_site_id
    target_site_id = var.target_site_id
    fortigate_ip   = var.fortigate_config.sbg_fortigate_ip != null ? var.fortigate_config.sbg_fortigate_ip : var.fortigate_config.rbx_fortigate_ip
  }
}
