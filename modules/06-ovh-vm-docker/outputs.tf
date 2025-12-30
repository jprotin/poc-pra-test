# ==============================================================================
# Module Terraform : OVH VMware VM Docker - Outputs
# ==============================================================================

# ------------------------------------------------------------------------------
# Informations de la VM
# ------------------------------------------------------------------------------

output "vm_id" {
  description = "ID unique de la Virtual Machine dans vSphere"
  value       = vsphere_virtual_machine.docker_vm.id
}

output "vm_uuid" {
  description = "UUID vSphere de la VM (utilisé pour Zerto, backups, etc.)"
  value       = vsphere_virtual_machine.docker_vm.uuid
}

output "vm_name" {
  description = "Nom de la Virtual Machine"
  value       = vsphere_virtual_machine.docker_vm.name
}

output "vm_moid" {
  description = "Managed Object ID (MOID) vSphere de la VM"
  value       = vsphere_virtual_machine.docker_vm.moid
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
  value       = vsphere_virtual_machine.docker_vm.num_cpus
}

output "vm_memory_mb" {
  description = "Mémoire RAM en Mo"
  value       = vsphere_virtual_machine.docker_vm.memory
}

output "vm_disk_size_gb" {
  description = "Taille du disque principal en Go"
  value       = var.vm_disk_size_gb
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
# Statut Docker
# ------------------------------------------------------------------------------

output "docker_version" {
  description = "Version de Docker Engine installée"
  value       = var.docker_version
}

output "docker_compose_version" {
  description = "Version de Docker Compose installée"
  value       = var.docker_compose_version
}

output "monitoring_enabled" {
  description = "Indique si le monitoring (node_exporter) est activé"
  value       = var.enable_docker_monitoring
}

# ------------------------------------------------------------------------------
# Output groupé pour intégration Zerto
# ------------------------------------------------------------------------------

output "zerto_vm_info" {
  description = "Informations structurées de la VM pour intégration Zerto VPG"
  value = {
    vm_uuid       = vsphere_virtual_machine.docker_vm.uuid
    vm_name       = vsphere_virtual_machine.docker_vm.name
    vm_moid       = vsphere_virtual_machine.docker_vm.moid
    datacenter    = var.vsphere_datacenter
    ipv4_address  = var.vm_ipv4_address
    boot_priority = 2 # Boot après MySQL (priorité 1)
    boot_delay_seconds = 60 # Attendre 60s après MySQL
  }
}
