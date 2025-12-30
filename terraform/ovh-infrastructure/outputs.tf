# ==============================================================================
# Outputs Terraform - OVH VMware Infrastructure
# ==============================================================================

# ------------------------------------------------------------------------------
# Réseau
# ------------------------------------------------------------------------------

output "network_summary" {
  description = "Résumé de la configuration réseau vRack"
  value       = module.network_config.network_summary
}

# ------------------------------------------------------------------------------
# VMs Docker
# ------------------------------------------------------------------------------

output "docker_vm_rbx_info" {
  description = "Informations VM Docker RBX"
  value = {
    name             = module.docker_vm_rbx.vm_name
    ip               = module.docker_vm_rbx.vm_ipv4_address
    ssh              = module.docker_vm_rbx.ssh_connection_string
    docker_version   = module.docker_vm_rbx.docker_version
    monitoring       = module.docker_vm_rbx.monitoring_enabled
    zerto_info       = module.docker_vm_rbx.zerto_vm_info
  }
}

output "docker_vm_sbg_info" {
  description = "Informations VM Docker SBG"
  value = {
    name             = module.docker_vm_sbg.vm_name
    ip               = module.docker_vm_sbg.vm_ipv4_address
    ssh              = module.docker_vm_sbg.ssh_connection_string
    docker_version   = module.docker_vm_sbg.docker_version
    monitoring       = module.docker_vm_sbg.monitoring_enabled
    zerto_info       = module.docker_vm_sbg.zerto_vm_info
  }
}

# ------------------------------------------------------------------------------
# VMs MySQL
# ------------------------------------------------------------------------------

output "mysql_vm_rbx_info" {
  description = "Informations VM MySQL RBX"
  value = {
    name               = module.mysql_vm_rbx.vm_name
    ip                 = module.mysql_vm_rbx.vm_ipv4_address
    ssh                = module.mysql_vm_rbx.ssh_connection_string
    mysql_host         = module.mysql_vm_rbx.mysql_host
    mysql_database     = module.mysql_vm_rbx.mysql_database_name
    mysql_user         = module.mysql_vm_rbx.mysql_app_user
    backup_enabled     = module.mysql_vm_rbx.mysql_backup_enabled
    monitoring_enabled = module.mysql_vm_rbx.monitoring_enabled
    zerto_info         = module.mysql_vm_rbx.zerto_vm_info
  }
}

output "mysql_vm_sbg_info" {
  description = "Informations VM MySQL SBG"
  value = {
    name               = module.mysql_vm_sbg.vm_name
    ip                 = module.mysql_vm_sbg.vm_ipv4_address
    ssh                = module.mysql_vm_sbg.ssh_connection_string
    mysql_host         = module.mysql_vm_sbg.mysql_host
    mysql_database     = module.mysql_vm_sbg.mysql_database_name
    mysql_user         = module.mysql_vm_sbg.mysql_app_user
    backup_enabled     = module.mysql_vm_sbg.mysql_backup_enabled
    monitoring_enabled = module.mysql_vm_sbg.monitoring_enabled
    zerto_info         = module.mysql_vm_sbg.zerto_vm_info
  }
}

# ------------------------------------------------------------------------------
# FortiGate Rules
# ------------------------------------------------------------------------------

output "fortigate_rules_summary" {
  description = "Résumé des règles firewall FortiGate"
  value       = module.fortigate_rules.firewall_rules_summary
}

# ------------------------------------------------------------------------------
# Informations de déploiement consolidées
# ------------------------------------------------------------------------------

output "deployment_summary" {
  description = "Résumé complet du déploiement"
  value = {
    environment = var.environment
    project     = var.project_name
    owner       = var.owner

    rbx_site = {
      docker_vm = module.docker_vm_rbx.vm_name
      mysql_vm  = module.mysql_vm_rbx.vm_name
      network   = var.vrack_vlan_rbx_cidr
    }

    sbg_site = {
      docker_vm = module.docker_vm_sbg.vm_name
      mysql_vm  = module.mysql_vm_sbg.vm_name
      network   = var.vrack_vlan_sbg_cidr
    }

    next_steps = [
      "1. Vérifier la connectivité SSH vers toutes les VMs",
      "2. Exécuter les playbooks Ansible pour configuration post-déploiement",
      "3. Créer les Virtual Protection Groups (VPG) Zerto",
      "4. Tester le failover RBX → SBG",
      "5. Déployer les applications Docker via docker-compose"
    ]
  }
}

# ------------------------------------------------------------------------------
# Fichier inventory Ansible généré automatiquement
# ------------------------------------------------------------------------------

output "ansible_inventory" {
  description = "Inventory Ansible généré pour post-configuration"
  value = templatefile("${path.module}/templates/inventory.yml.tpl", {
    docker_rbx_ip   = module.docker_vm_rbx.vm_ipv4_address
    docker_sbg_ip   = module.docker_vm_sbg.vm_ipv4_address
    mysql_rbx_ip    = module.mysql_vm_rbx.vm_ipv4_address
    mysql_sbg_ip    = module.mysql_vm_sbg.vm_ipv4_address
    admin_username  = var.admin_username
  })
}
