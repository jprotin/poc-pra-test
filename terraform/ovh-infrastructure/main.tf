# ==============================================================================
# Terraform Main - OVH VMware Infrastructure Applicative
# ==============================================================================
# Description : Déploiement complet de l'infrastructure applicative sur
#               OVH Private Cloud VMware (RBX + SBG) avec Docker, MySQL,
#               configuration réseau (vRack) et intégration Zerto PRA
# ==============================================================================

# ==============================================================================
# MODULES - CONFIGURATION RÉSEAU
# ==============================================================================

# Configuration des port groups vSphere pour vRack OVH
module "network_config" {
  source = "../../modules/08-ovh-network-config"

  # vSphere RBX
  vsphere_rbx_server              = var.vsphere_rbx_server
  vsphere_rbx_datacenter          = var.vsphere_rbx_datacenter
  vsphere_rbx_distributed_switch  = var.vsphere_rbx_distributed_switch

  # vSphere SBG
  vsphere_sbg_server              = var.vsphere_sbg_server
  vsphere_sbg_datacenter          = var.vsphere_sbg_datacenter
  vsphere_sbg_distributed_switch  = var.vsphere_sbg_distributed_switch

  # VLANs vRack
  vrack_vlan_rbx_id       = var.vrack_vlan_rbx_id
  vrack_vlan_rbx_cidr     = var.vrack_vlan_rbx_cidr
  vrack_vlan_sbg_id       = var.vrack_vlan_sbg_id
  vrack_vlan_sbg_cidr     = var.vrack_vlan_sbg_cidr
  vrack_vlan_backbone_id  = var.vrack_vlan_backbone_id
  vrack_vlan_backbone_cidr = var.vrack_vlan_backbone_cidr

  environment  = var.environment
  project_name = var.project_name
}

# ==============================================================================
# MODULES - VMs DOCKER
# ==============================================================================

# VM Docker Application A - RBX
module "docker_vm_rbx" {
  source = "../../modules/06-ovh-vm-docker"

  providers = {
    vsphere = vsphere.rbx
  }

  # Configuration vSphere
  vsphere_server     = var.vsphere_rbx_server
  vsphere_user       = var.vsphere_rbx_user
  vsphere_password   = var.vsphere_rbx_password
  vsphere_datacenter = var.vsphere_rbx_datacenter
  vsphere_cluster    = var.vsphere_rbx_cluster
  vsphere_datastore  = var.vsphere_rbx_datastore
  vsphere_network    = module.network_config.rbx_private_port_group_name

  # Configuration VM
  vm_name                 = "VM-DOCKER-APP-A-RBX"
  vm_template             = var.vm_template
  vm_num_cpus             = var.docker_vm_num_cpus
  vm_memory_mb            = var.docker_vm_memory_mb
  vm_disk_size_gb         = var.docker_vm_disk_size_gb
  vm_additional_disk_size_gb = var.docker_vm_additional_disk_size_gb

  # Configuration réseau
  vm_ipv4_address = var.vm_docker_rbx_ip
  vm_ipv4_netmask = var.vm_ipv4_netmask
  vm_ipv4_gateway = var.rbx_gateway_ip
  vm_dns_servers  = var.dns_servers
  vm_domain_name  = var.rbx_domain_name

  # SSH et utilisateurs
  admin_username        = var.admin_username
  admin_ssh_public_key  = var.admin_ssh_public_key

  # Docker
  docker_version         = var.docker_version
  docker_compose_version = var.docker_compose_version
  enable_docker_monitoring = var.enable_docker_monitoring

  # Sécurité
  enable_firewall           = var.enable_firewall
  allowed_ssh_cidrs         = var.allowed_ssh_cidrs
  enable_automatic_updates  = var.enable_automatic_updates

  # Tags
  environment  = var.environment
  project_name = var.project_name
  owner        = var.owner

  depends_on = [module.network_config]
}

# VM Docker Application B - SBG
module "docker_vm_sbg" {
  source = "../../modules/06-ovh-vm-docker"

  providers = {
    vsphere = vsphere.sbg
  }

  # Configuration vSphere
  vsphere_server     = var.vsphere_sbg_server
  vsphere_user       = var.vsphere_sbg_user
  vsphere_password   = var.vsphere_sbg_password
  vsphere_datacenter = var.vsphere_sbg_datacenter
  vsphere_cluster    = var.vsphere_sbg_cluster
  vsphere_datastore  = var.vsphere_sbg_datastore
  vsphere_network    = module.network_config.sbg_private_port_group_name

  # Configuration VM
  vm_name                 = "VM-DOCKER-APP-B-SBG"
  vm_template             = var.vm_template
  vm_num_cpus             = var.docker_vm_num_cpus
  vm_memory_mb            = var.docker_vm_memory_mb
  vm_disk_size_gb         = var.docker_vm_disk_size_gb
  vm_additional_disk_size_gb = var.docker_vm_additional_disk_size_gb

  # Configuration réseau
  vm_ipv4_address = var.vm_docker_sbg_ip
  vm_ipv4_netmask = var.vm_ipv4_netmask
  vm_ipv4_gateway = var.sbg_gateway_ip
  vm_dns_servers  = var.dns_servers
  vm_domain_name  = var.sbg_domain_name

  # SSH et utilisateurs
  admin_username        = var.admin_username
  admin_ssh_public_key  = var.admin_ssh_public_key

  # Docker
  docker_version         = var.docker_version
  docker_compose_version = var.docker_compose_version
  enable_docker_monitoring = var.enable_docker_monitoring

  # Sécurité
  enable_firewall           = var.enable_firewall
  allowed_ssh_cidrs         = var.allowed_ssh_cidrs
  enable_automatic_updates  = var.enable_automatic_updates

  # Tags
  environment  = var.environment
  project_name = var.project_name
  owner        = var.owner

  depends_on = [module.network_config]
}

# ==============================================================================
# MODULES - VMs MYSQL
# ==============================================================================

# VM MySQL Application A - RBX
module "mysql_vm_rbx" {
  source = "../../modules/07-ovh-vm-mysql"

  providers = {
    vsphere = vsphere.rbx
  }

  # Configuration vSphere
  vsphere_server     = var.vsphere_rbx_server
  vsphere_user       = var.vsphere_rbx_user
  vsphere_password   = var.vsphere_rbx_password
  vsphere_datacenter = var.vsphere_rbx_datacenter
  vsphere_cluster    = var.vsphere_rbx_cluster
  vsphere_datastore  = var.vsphere_rbx_datastore
  vsphere_network    = module.network_config.rbx_private_port_group_name

  # Configuration VM
  vm_name              = "VM-MYSQL-APP-A-RBX"
  vm_template          = var.vm_template
  vm_num_cpus          = var.mysql_vm_num_cpus
  vm_memory_mb         = var.mysql_vm_memory_mb
  vm_disk_size_gb      = var.mysql_vm_disk_size_gb
  vm_data_disk_size_gb = var.mysql_vm_data_disk_size_gb
  vm_log_disk_size_gb  = var.mysql_vm_log_disk_size_gb

  # Configuration réseau
  vm_ipv4_address = var.vm_mysql_rbx_ip
  vm_ipv4_netmask = var.vm_ipv4_netmask
  vm_ipv4_gateway = var.rbx_gateway_ip
  vm_dns_servers  = var.dns_servers
  vm_domain_name  = var.rbx_domain_name

  # SSH et utilisateurs
  admin_username       = var.admin_username
  admin_ssh_public_key = var.admin_ssh_public_key

  # MySQL
  mysql_version               = var.mysql_version
  mysql_root_password         = var.mysql_root_password
  mysql_database_name         = var.mysql_database_name_rbx
  mysql_app_user              = var.mysql_app_user
  mysql_app_password          = var.mysql_app_password
  mysql_allowed_hosts         = [var.vm_docker_rbx_ip, "localhost"]
  mysql_innodb_buffer_pool_size = var.mysql_innodb_buffer_pool_size
  mysql_max_connections       = var.mysql_max_connections

  # Backup
  enable_mysql_backup         = var.enable_mysql_backup
  mysql_backup_retention_days = var.mysql_backup_retention_days

  # Monitoring
  enable_mysql_monitoring = var.enable_mysql_monitoring

  # Sécurité
  enable_firewall          = var.enable_firewall
  allowed_mysql_cidrs      = [var.vrack_vlan_rbx_cidr]
  allowed_ssh_cidrs        = var.allowed_ssh_cidrs
  enable_automatic_updates = var.enable_automatic_updates

  # Tags
  environment  = var.environment
  project_name = var.project_name
  owner        = var.owner

  depends_on = [module.network_config]
}

# VM MySQL Application B - SBG
module "mysql_vm_sbg" {
  source = "../../modules/07-ovh-vm-mysql"

  providers = {
    vsphere = vsphere.sbg
  }

  # Configuration vSphere
  vsphere_server     = var.vsphere_sbg_server
  vsphere_user       = var.vsphere_sbg_user
  vsphere_password   = var.vsphere_sbg_password
  vsphere_datacenter = var.vsphere_sbg_datacenter
  vsphere_cluster    = var.vsphere_sbg_cluster
  vsphere_datastore  = var.vsphere_sbg_datastore
  vsphere_network    = module.network_config.sbg_private_port_group_name

  # Configuration VM
  vm_name              = "VM-MYSQL-APP-B-SBG"
  vm_template          = var.vm_template
  vm_num_cpus          = var.mysql_vm_num_cpus
  vm_memory_mb         = var.mysql_vm_memory_mb
  vm_disk_size_gb      = var.mysql_vm_disk_size_gb
  vm_data_disk_size_gb = var.mysql_vm_data_disk_size_gb
  vm_log_disk_size_gb  = var.mysql_vm_log_disk_size_gb

  # Configuration réseau
  vm_ipv4_address = var.vm_mysql_sbg_ip
  vm_ipv4_netmask = var.vm_ipv4_netmask
  vm_ipv4_gateway = var.sbg_gateway_ip
  vm_dns_servers  = var.dns_servers
  vm_domain_name  = var.sbg_domain_name

  # SSH et utilisateurs
  admin_username       = var.admin_username
  admin_ssh_public_key = var.admin_ssh_public_key

  # MySQL
  mysql_version               = var.mysql_version
  mysql_root_password         = var.mysql_root_password
  mysql_database_name         = var.mysql_database_name_sbg
  mysql_app_user              = var.mysql_app_user
  mysql_app_password          = var.mysql_app_password
  mysql_allowed_hosts         = [var.vm_docker_sbg_ip, "localhost"]
  mysql_innodb_buffer_pool_size = var.mysql_innodb_buffer_pool_size
  mysql_max_connections       = var.mysql_max_connections

  # Backup
  enable_mysql_backup         = var.enable_mysql_backup
  mysql_backup_retention_days = var.mysql_backup_retention_days

  # Monitoring
  enable_mysql_monitoring = var.enable_mysql_monitoring

  # Sécurité
  enable_firewall          = var.enable_firewall
  allowed_mysql_cidrs      = [var.vrack_vlan_sbg_cidr]
  allowed_ssh_cidrs        = var.allowed_ssh_cidrs
  enable_automatic_updates = var.enable_automatic_updates

  # Tags
  environment  = var.environment
  project_name = var.project_name
  owner        = var.owner

  depends_on = [module.network_config]
}

# ==============================================================================
# MODULES - FORTIGATE FIREWALL RULES
# ==============================================================================

module "fortigate_rules" {
  source = "../../modules/09-ovh-fortigate-rules"

  providers = {
    fortios.rbx = fortios.rbx
    fortios.sbg = fortios.sbg
  }

  # FortiGate RBX
  fortigate_rbx_hostname           = var.fortigate_rbx_hostname
  fortigate_rbx_token              = var.fortigate_rbx_token
  fortigate_rbx_internal_interface = var.fortigate_rbx_internal_interface
  fortigate_rbx_external_interface = var.fortigate_rbx_external_interface
  fortigate_rbx_public_ip          = var.fortigate_rbx_public_ip

  # FortiGate SBG
  fortigate_sbg_hostname           = var.fortigate_sbg_hostname
  fortigate_sbg_token              = var.fortigate_sbg_token
  fortigate_sbg_internal_interface = var.fortigate_sbg_internal_interface
  fortigate_sbg_external_interface = var.fortigate_sbg_external_interface
  fortigate_sbg_public_ip          = var.fortigate_sbg_public_ip

  # Adresses IP VMs
  vm_docker_rbx_ip = var.vm_docker_rbx_ip
  vm_mysql_rbx_ip  = var.vm_mysql_rbx_ip
  vm_docker_sbg_ip = var.vm_docker_sbg_ip
  vm_mysql_sbg_ip  = var.vm_mysql_sbg_ip

  # Réseaux
  rbx_network_cidr = var.vrack_vlan_rbx_cidr
  sbg_network_cidr = var.vrack_vlan_sbg_cidr

  # Options
  enable_nat_docker_rbx = var.enable_nat_docker_rbx
  enable_nat_docker_sbg = var.enable_nat_docker_sbg
  enable_logging        = var.enable_fortigate_logging

  environment  = var.environment
  project_name = var.project_name

  depends_on = [
    module.docker_vm_rbx,
    module.docker_vm_sbg,
    module.mysql_vm_rbx,
    module.mysql_vm_sbg
  ]
}
