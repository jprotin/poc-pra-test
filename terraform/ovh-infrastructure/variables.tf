# ==============================================================================
# Variables Terraform - OVH VMware Infrastructure
# ==============================================================================
# Description : Variables pour le déploiement de l'infrastructure applicative
#               OVH (Docker + MySQL) sur RBX et SBG avec vRack et FortiGate
# ==============================================================================

# ------------------------------------------------------------------------------
# Configuration générale
# ------------------------------------------------------------------------------

variable "environment" {
  description = "Environnement de déploiement (dev, test, staging, prod)"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Nom du projet"
  type        = string
  default     = "pra"
}

variable "owner" {
  description = "Propriétaire ou équipe responsable"
  type        = string
  default     = "devops-team"
}

# ------------------------------------------------------------------------------
# Configuration vSphere RBX
# ------------------------------------------------------------------------------

variable "vsphere_rbx_server" {
  description = "Adresse du serveur vCenter RBX"
  type        = string
  sensitive   = true
}

variable "vsphere_rbx_user" {
  description = "Nom d'utilisateur vCenter RBX"
  type        = string
  sensitive   = true
}

variable "vsphere_rbx_password" {
  description = "Mot de passe vCenter RBX"
  type        = string
  sensitive   = true
}

variable "vsphere_rbx_datacenter" {
  description = "Nom du datacenter vSphere RBX"
  type        = string
}

variable "vsphere_rbx_cluster" {
  description = "Nom du cluster vSphere RBX"
  type        = string
}

variable "vsphere_rbx_datastore" {
  description = "Nom du datastore RBX"
  type        = string
}

variable "vsphere_rbx_distributed_switch" {
  description = "Nom du Distributed Switch RBX"
  type        = string
  default     = "vRack-DSwitch-RBX"
}

# ------------------------------------------------------------------------------
# Configuration vSphere SBG
# ------------------------------------------------------------------------------

variable "vsphere_sbg_server" {
  description = "Adresse du serveur vCenter SBG"
  type        = string
  sensitive   = true
}

variable "vsphere_sbg_user" {
  description = "Nom d'utilisateur vCenter SBG"
  type        = string
  sensitive   = true
}

variable "vsphere_sbg_password" {
  description = "Mot de passe vCenter SBG"
  type        = string
  sensitive   = true
}

variable "vsphere_sbg_datacenter" {
  description = "Nom du datacenter vSphere SBG"
  type        = string
}

variable "vsphere_sbg_cluster" {
  description = "Nom du cluster vSphere SBG"
  type        = string
}

variable "vsphere_sbg_datastore" {
  description = "Nom du datastore SBG"
  type        = string
}

variable "vsphere_sbg_distributed_switch" {
  description = "Nom du Distributed Switch SBG"
  type        = string
  default     = "vRack-DSwitch-SBG"
}

# ------------------------------------------------------------------------------
# Configuration vRack (Réseaux privés)
# ------------------------------------------------------------------------------

variable "vrack_vlan_rbx_id" {
  description = "ID du VLAN privé RBX"
  type        = number
  default     = 100
}

variable "vrack_vlan_rbx_cidr" {
  description = "CIDR du réseau privé RBX"
  type        = string
  default     = "10.100.0.0/24"
}

variable "vrack_vlan_sbg_id" {
  description = "ID du VLAN privé SBG"
  type        = number
  default     = 200
}

variable "vrack_vlan_sbg_cidr" {
  description = "CIDR du réseau privé SBG"
  type        = string
  default     = "10.200.0.0/24"
}

variable "vrack_vlan_backbone_id" {
  description = "ID du VLAN backbone inter-DC"
  type        = number
  default     = 900
}

variable "vrack_vlan_backbone_cidr" {
  description = "CIDR du réseau backbone"
  type        = string
  default     = "10.255.0.0/30"
}

# ------------------------------------------------------------------------------
# Configuration VMs - Général
# ------------------------------------------------------------------------------

variable "vm_template" {
  description = "Nom du template vSphere Ubuntu"
  type        = string
  default     = "ubuntu-22.04-template"
}

variable "admin_username" {
  description = "Nom d'utilisateur admin des VMs"
  type        = string
  default     = "vmadmin"
}

variable "admin_ssh_public_key" {
  description = "Clé SSH publique pour accès admin"
  type        = string
  sensitive   = true
}

variable "vm_ipv4_netmask" {
  description = "Masque de sous-réseau (bits)"
  type        = number
  default     = 24
}

variable "dns_servers" {
  description = "Liste des serveurs DNS"
  type        = list(string)
  default     = ["213.186.33.99", "8.8.8.8"]
}

# ------------------------------------------------------------------------------
# Adresses IP VMs
# ------------------------------------------------------------------------------

variable "vm_docker_rbx_ip" {
  description = "Adresse IP VM Docker RBX"
  type        = string
  default     = "10.100.0.10"
}

variable "vm_mysql_rbx_ip" {
  description = "Adresse IP VM MySQL RBX"
  type        = string
  default     = "10.100.0.11"
}

variable "vm_docker_sbg_ip" {
  description = "Adresse IP VM Docker SBG"
  type        = string
  default     = "10.200.0.10"
}

variable "vm_mysql_sbg_ip" {
  description = "Adresse IP VM MySQL SBG"
  type        = string
  default     = "10.200.0.11"
}

variable "rbx_gateway_ip" {
  description = "Passerelle par défaut RBX"
  type        = string
  default     = "10.100.0.1"
}

variable "sbg_gateway_ip" {
  description = "Passerelle par défaut SBG"
  type        = string
  default     = "10.200.0.1"
}

variable "rbx_domain_name" {
  description = "Nom de domaine RBX"
  type        = string
  default     = "rbx.prod.local"
}

variable "sbg_domain_name" {
  description = "Nom de domaine SBG"
  type        = string
  default     = "sbg.prod.local"
}

# ------------------------------------------------------------------------------
# Configuration VMs Docker
# ------------------------------------------------------------------------------

variable "docker_vm_num_cpus" {
  description = "Nombre de vCPUs pour VMs Docker"
  type        = number
  default     = 4
}

variable "docker_vm_memory_mb" {
  description = "RAM en Mo pour VMs Docker"
  type        = number
  default     = 8192
}

variable "docker_vm_disk_size_gb" {
  description = "Taille disque principal VMs Docker"
  type        = number
  default     = 100
}

variable "docker_vm_additional_disk_size_gb" {
  description = "Taille disque additionnel pour volumes Docker (0 = désactivé)"
  type        = number
  default     = 0
}

variable "docker_version" {
  description = "Version de Docker Engine"
  type        = string
  default     = "24.0"
}

variable "docker_compose_version" {
  description = "Version de Docker Compose"
  type        = string
  default     = "2.23.0"
}

variable "enable_docker_monitoring" {
  description = "Activer monitoring Docker (node_exporter, cAdvisor)"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# Configuration VMs MySQL
# ------------------------------------------------------------------------------

variable "mysql_vm_num_cpus" {
  description = "Nombre de vCPUs pour VMs MySQL"
  type        = number
  default     = 4
}

variable "mysql_vm_memory_mb" {
  description = "RAM en Mo pour VMs MySQL"
  type        = number
  default     = 16384
}

variable "mysql_vm_disk_size_gb" {
  description = "Taille disque OS VMs MySQL"
  type        = number
  default     = 50
}

variable "mysql_vm_data_disk_size_gb" {
  description = "Taille disque données MySQL"
  type        = number
  default     = 200
}

variable "mysql_vm_log_disk_size_gb" {
  description = "Taille disque logs MySQL (0 = désactivé)"
  type        = number
  default     = 0
}

variable "mysql_version" {
  description = "Version de MySQL"
  type        = string
  default     = "8.0"
}

variable "mysql_root_password" {
  description = "Mot de passe root MySQL"
  type        = string
  sensitive   = true
}

variable "mysql_database_name_rbx" {
  description = "Nom de la base de données RBX"
  type        = string
  default     = "app_rbx_db"
}

variable "mysql_database_name_sbg" {
  description = "Nom de la base de données SBG"
  type        = string
  default     = "app_sbg_db"
}

variable "mysql_app_user" {
  description = "Nom d'utilisateur MySQL applicatif"
  type        = string
  default     = "appuser"
}

variable "mysql_app_password" {
  description = "Mot de passe utilisateur MySQL applicatif"
  type        = string
  sensitive   = true
}

variable "mysql_innodb_buffer_pool_size" {
  description = "Taille buffer pool InnoDB"
  type        = string
  default     = "12G"
}

variable "mysql_max_connections" {
  description = "Nombre max de connexions MySQL"
  type        = number
  default     = 500
}

variable "enable_mysql_backup" {
  description = "Activer backups automatiques MySQL"
  type        = bool
  default     = true
}

variable "mysql_backup_retention_days" {
  description = "Rétention backups MySQL (jours)"
  type        = number
  default     = 7
}

variable "enable_mysql_monitoring" {
  description = "Activer monitoring MySQL (mysqld_exporter)"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# Configuration FortiGate
# ------------------------------------------------------------------------------

variable "fortigate_rbx_hostname" {
  description = "Hostname/IP FortiGate RBX"
  type        = string
  sensitive   = true
}

variable "fortigate_rbx_token" {
  description = "API Token FortiGate RBX"
  type        = string
  sensitive   = true
}

variable "fortigate_rbx_public_ip" {
  description = "IP publique FortiGate RBX"
  type        = string
}

variable "fortigate_rbx_internal_interface" {
  description = "Interface interne FortiGate RBX"
  type        = string
  default     = "port1"
}

variable "fortigate_rbx_external_interface" {
  description = "Interface externe FortiGate RBX"
  type        = string
  default     = "port2"
}

variable "fortigate_sbg_hostname" {
  description = "Hostname/IP FortiGate SBG"
  type        = string
  sensitive   = true
}

variable "fortigate_sbg_token" {
  description = "API Token FortiGate SBG"
  type        = string
  sensitive   = true
}

variable "fortigate_sbg_public_ip" {
  description = "IP publique FortiGate SBG"
  type        = string
}

variable "fortigate_sbg_internal_interface" {
  description = "Interface interne FortiGate SBG"
  type        = string
  default     = "port1"
}

variable "fortigate_sbg_external_interface" {
  description = "Interface externe FortiGate SBG"
  type        = string
  default     = "port2"
}

variable "enable_nat_docker_rbx" {
  description = "Activer NAT pour Docker RBX"
  type        = bool
  default     = true
}

variable "enable_nat_docker_sbg" {
  description = "Activer NAT pour Docker SBG"
  type        = bool
  default     = true
}

variable "enable_fortigate_logging" {
  description = "Activer logging FortiGate"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# Sécurité
# ------------------------------------------------------------------------------

variable "enable_firewall" {
  description = "Activer UFW sur les VMs"
  type        = bool
  default     = true
}

variable "allowed_ssh_cidrs" {
  description = "CIDRs autorisés pour SSH"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "enable_automatic_updates" {
  description = "Activer mises à jour automatiques"
  type        = bool
  default     = true
}
