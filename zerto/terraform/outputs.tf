###############################################################################
# OUTPUTS - ZERTO DISASTER RECOVERY
###############################################################################
# Description: Sorties Terraform pour la configuration Zerto
# Usage: Informations de configuration et endpoints pour monitoring
###############################################################################

###############################################################################
# OUTPUTS VPG RBX -> SBG
###############################################################################

output "vpg_rbx_to_sbg_id" {
  description = "ID du Virtual Protection Group RBX vers SBG"
  value       = module.zerto_rbx_to_sbg.vpg_id
}

output "vpg_rbx_to_sbg_name" {
  description = "Nom du Virtual Protection Group RBX vers SBG"
  value       = module.zerto_rbx_to_sbg.vpg_name
}

output "vpg_rbx_to_sbg_status" {
  description = "État du Virtual Protection Group RBX vers SBG"
  value       = module.zerto_rbx_to_sbg.vpg_status
}

output "vpg_rbx_to_sbg_rpo" {
  description = "RPO actuel du VPG RBX vers SBG"
  value       = module.zerto_rbx_to_sbg.current_rpo
}

output "rbx_to_sbg_protected_vms" {
  description = "Liste des VMs protégées de RBX vers SBG"
  value = [
    for vm in module.zerto_rbx_to_sbg.protected_vms : {
      name        = vm.name
      status      = vm.status
      failover_ip = vm.failover_ip
    }
  ]
}

###############################################################################
# OUTPUTS VPG SBG -> RBX
###############################################################################

output "vpg_sbg_to_rbx_id" {
  description = "ID du Virtual Protection Group SBG vers RBX"
  value       = module.zerto_sbg_to_rbx.vpg_id
}

output "vpg_sbg_to_rbx_name" {
  description = "Nom du Virtual Protection Group SBG vers RBX"
  value       = module.zerto_sbg_to_rbx.vpg_name
}

output "vpg_sbg_to_rbx_status" {
  description = "État du Virtual Protection Group SBG vers RBX"
  value       = module.zerto_sbg_to_rbx.vpg_status
}

output "vpg_sbg_to_rbx_rpo" {
  description = "RPO actuel du VPG SBG vers RBX"
  value       = module.zerto_sbg_to_rbx.current_rpo
}

output "sbg_to_rbx_protected_vms" {
  description = "Liste des VMs protégées de SBG vers RBX"
  value = [
    for vm in module.zerto_sbg_to_rbx.protected_vms : {
      name        = vm.name
      status      = vm.status
      failover_ip = vm.failover_ip
    }
  ]
}

###############################################################################
# OUTPUTS CONFIGURATION RÉSEAU
###############################################################################

output "rbx_fortigate_config" {
  description = "Configuration du Fortigate RBX"
  value = {
    ip_address = var.rbx_fortigate_ip
    status     = module.zerto_fortigate_config.rbx_fortigate_status
    bgp_status = module.zerto_fortigate_config.rbx_bgp_status
  }
}

output "sbg_fortigate_config" {
  description = "Configuration du Fortigate SBG"
  value = {
    ip_address = var.sbg_fortigate_ip
    status     = module.zerto_fortigate_config.sbg_fortigate_status
    bgp_status = module.zerto_fortigate_config.sbg_bgp_status
  }
}

output "bgp_peering_status" {
  description = "État du peering BGP entre RBX et SBG"
  value = {
    peering_established = module.zerto_fortigate_config.bgp_peering_established
    rbx_routes_announced = module.zerto_fortigate_config.rbx_routes_count
    sbg_routes_announced = module.zerto_fortigate_config.sbg_routes_count
  }
}

###############################################################################
# OUTPUTS MONITORING
###############################################################################

output "monitoring_dashboard_url" {
  description = "URL du dashboard de monitoring Zerto"
  value       = module.zerto_monitoring.dashboard_url
}

output "zerto_health_status" {
  description = "État de santé global de la configuration Zerto"
  value = {
    overall_status    = module.zerto_monitoring.overall_health
    rbx_to_sbg_health = module.zerto_monitoring.rbx_to_sbg_health
    sbg_to_rbx_health = module.zerto_monitoring.sbg_to_rbx_health
    last_check        = module.zerto_monitoring.last_health_check
  }
}

output "alert_configuration" {
  description = "Configuration des alertes"
  value = {
    emails_configured = length(var.alert_emails) > 0
    webhook_configured = var.alert_webhook_url != ""
    alert_count       = module.zerto_monitoring.active_alerts_count
  }
}

###############################################################################
# OUTPUTS INFORMATIONS GÉNÉRALES
###############################################################################

output "deployment_summary" {
  description = "Résumé du déploiement Zerto"
  value = {
    environment        = var.environment
    source_regions     = [var.region_rbx, var.region_sbg]
    target_regions     = [var.region_sbg, var.region_rbx]
    total_protected_vms = length(var.rbx_protected_vms) + length(var.sbg_protected_vms)
    rpo_seconds        = var.zerto_rpo_seconds
    journal_hours      = var.zerto_journal_hours
    encryption_enabled = var.zerto_enable_encryption
    compression_enabled = var.zerto_enable_compression
  }
}

output "failover_endpoints" {
  description = "Points de terminaison pour les opérations de failover"
  value = {
    rbx_to_sbg_failover_script = "${path.module}/../../scripts/failover-rbx-to-sbg.sh"
    sbg_to_rbx_failover_script = "${path.module}/../../scripts/failover-sbg-to-rbx.sh"
    failback_script            = "${path.module}/../../scripts/failback.sh"
    test_failover_script       = "${path.module}/../../scripts/test-failover.sh"
  }
}

output "network_configuration" {
  description = "Configuration réseau pour les deux sites"
  value = {
    rbx = {
      network_id    = var.rbx_target_network_id
      subnet_id     = var.rbx_target_subnet_id
      gateway       = var.rbx_failover_network_config.gateway
      network_range = var.rbx_network_ranges
    }
    sbg = {
      network_id    = var.sbg_target_network_id
      subnet_id     = var.sbg_target_subnet_id
      gateway       = var.sbg_failover_network_config.gateway
      network_range = var.sbg_network_ranges
    }
  }
}

###############################################################################
# OUTPUTS POUR AUTOMATION
###############################################################################

output "automation_config" {
  description = "Configuration pour les scripts d'automation"
  value = {
    vpg_ids = {
      rbx_to_sbg = module.zerto_rbx_to_sbg.vpg_id
      sbg_to_rbx = module.zerto_sbg_to_rbx.vpg_id
    }
    zerto_sites = {
      rbx = var.zerto_site_id_rbx
      sbg = var.zerto_site_id_sbg
    }
    fortigate_ips = {
      rbx = var.rbx_fortigate_ip
      sbg = var.sbg_fortigate_ip
    }
  }
  sensitive = false
}

###############################################################################
# OUTPUTS POUR DOCUMENTATION
###############################################################################

output "configuration_files" {
  description = "Emplacements des fichiers de configuration générés"
  value = {
    terraform_state    = "terraform.tfstate"
    ansible_inventory  = "${path.module}/../../ansible/inventory/zerto_hosts.yml"
    monitoring_config  = "${path.module}/../../ansible/playbooks/monitoring-config.yml"
  }
}
