# ==============================================================================
# Module Terraform : OVH VMware VM MySQL - Outputs
# ==============================================================================

# ------------------------------------------------------------------------------
# Informations de la VM
# ------------------------------------------------------------------------------

output "vm_id" {
  description = "ID unique de la Virtual Machine dans vSphere"
  value       = vsphere_virtual_machine.mysql_vm.id
}

output "vm_uuid" {
  description = "UUID vSphere de la VM (utilisé pour Zerto, backups, etc.)"
  value       = vsphere_virtual_machine.mysql_vm.uuid
}

output "vm_name" {
  description = "Nom de la Virtual Machine"
  value       = vsphere_virtual_machine.mysql_vm.name
}

output "vm_moid" {
  description = "Managed Object ID (MOID) vSphere de la VM"
  value       = vsphere_virtual_machine.mysql_vm.moid
}

# ------------------------------------------------------------------------------
# Configuration réseau
# ------------------------------------------------------------------------------

output "vm_ipv4_address" {
  description = "Adresse IPv4 de la VM"
  value       = var.vm_ipv4_address
}

output "vm_default_gateway" {
  description = "Passerelle par défaut de la VM"
  value       = var.vm_ipv4_gateway
}

output "vm_dns_servers" {
  description = "Serveurs DNS configurés sur la VM"
  value       = var.vm_dns_servers
}

output "vm_fqdn" {
  description = "Fully Qualified Domain Name de la VM"
  value       = "${var.vm_name}.${var.vm_domain_name}"
}

# ------------------------------------------------------------------------------
# Configuration matérielle
# ------------------------------------------------------------------------------

output "vm_num_cpus" {
  description = "Nombre de vCPUs alloués"
  value       = vsphere_virtual_machine.mysql_vm.num_cpus
}

output "vm_memory_mb" {
  description = "Mémoire RAM en Mo"
  value       = vsphere_virtual_machine.mysql_vm.memory
}

output "vm_disk_os_size_gb" {
  description = "Taille du disque OS en Go"
  value       = var.vm_disk_size_gb
}

output "vm_disk_data_size_gb" {
  description = "Taille du disque de données MySQL en Go"
  value       = var.vm_data_disk_size_gb
}

# ------------------------------------------------------------------------------
# Connexion MySQL
# ------------------------------------------------------------------------------

output "mysql_connection_string" {
  description = "Chaîne de connexion MySQL (sans mot de passe)"
  value       = "mysql -h ${var.vm_ipv4_address} -u ${var.mysql_app_user} -p"
}

output "mysql_host" {
  description = "Adresse IP du serveur MySQL"
  value       = var.vm_ipv4_address
  sensitive   = false
}

output "mysql_port" {
  description = "Port MySQL (défaut 3306)"
  value       = 3306
}

output "mysql_database_name" {
  description = "Nom de la base de données applicative"
  value       = var.mysql_database_name
}

output "mysql_app_user" {
  description = "Nom d'utilisateur MySQL applicatif"
  value       = var.mysql_app_user
}

# ------------------------------------------------------------------------------
# Accès SSH
# ------------------------------------------------------------------------------

output "ssh_connection_string" {
  description = "Commande SSH pour se connecter à la VM"
  value       = "ssh ${var.admin_username}@${var.vm_ipv4_address}"
}

output "admin_username" {
  description = "Nom d'utilisateur administrateur"
  value       = var.admin_username
}

# ------------------------------------------------------------------------------
# Informations de déploiement
# ------------------------------------------------------------------------------

output "environment" {
  description = "Environnement de déploiement"
  value       = var.environment
}

output "project_name" {
  description = "Nom du projet"
  value       = var.project_name
}

output "vsphere_datacenter" {
  description = "Datacenter vSphere où la VM est déployée"
  value       = var.vsphere_datacenter
}

output "vsphere_cluster" {
  description = "Cluster vSphere hébergeant la VM"
  value       = var.vsphere_cluster
}

# ------------------------------------------------------------------------------
# Statut MySQL
# ------------------------------------------------------------------------------

output "mysql_version" {
  description = "Version de MySQL installée"
  value       = var.mysql_version
}

output "mysql_innodb_buffer_pool_size" {
  description = "Taille du buffer pool InnoDB configuré"
  value       = var.mysql_innodb_buffer_pool_size
}

output "mysql_max_connections" {
  description = "Nombre maximum de connexions simultanées"
  value       = var.mysql_max_connections
}

output "mysql_backup_enabled" {
  description = "Indique si les backups automatiques sont activés"
  value       = var.enable_mysql_backup
}

output "monitoring_enabled" {
  description = "Indique si le monitoring (mysqld_exporter) est activé"
  value       = var.enable_mysql_monitoring
}

# ------------------------------------------------------------------------------
# Output groupé pour intégration Zerto
# ------------------------------------------------------------------------------

output "zerto_vm_info" {
  description = "Informations structurées de la VM pour intégration Zerto VPG"
  value = {
    vm_uuid            = vsphere_virtual_machine.mysql_vm.uuid
    vm_name            = vsphere_virtual_machine.mysql_vm.name
    vm_moid            = vsphere_virtual_machine.mysql_vm.moid
    datacenter         = var.vsphere_datacenter
    ipv4_address       = var.vm_ipv4_address
    boot_priority      = 1 # MySQL doit démarrer en premier
    boot_delay_seconds = 0 # Pas de délai pour MySQL
  }
}

# ------------------------------------------------------------------------------
# Output pour configuration Docker App
# ------------------------------------------------------------------------------

output "docker_env_vars" {
  description = "Variables d'environnement à utiliser dans docker-compose.yml pour connexion MySQL"
  value = {
    DB_HOST     = var.vm_ipv4_address
    DB_PORT     = "3306"
    DB_NAME     = var.mysql_database_name
    DB_USER     = var.mysql_app_user
    # DB_PASSWORD doit être géré via secrets management
  }
}
