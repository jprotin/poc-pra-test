# ==============================================================================
# Module Terraform : OVH VMware VM MySQL
# ==============================================================================
# Description : Provisioning d'une VM Ubuntu avec MySQL 8.0 optimisée
#               pour bases de données de production sur vSphere OVH
# Auteur      : DevOps Team
# Date        : 2025-12-30
# ==============================================================================

# ------------------------------------------------------------------------------
# Configuration vSphere / vCenter
# ------------------------------------------------------------------------------

variable "vsphere_server" {
  description = "Adresse du serveur vCenter OVH (ex: pcc-xxx-xxx.ovh.com)"
  type        = string
  sensitive   = true
}

variable "vsphere_user" {
  description = "Nom d'utilisateur vSphere avec privilèges administrateur"
  type        = string
  sensitive   = true
}

variable "vsphere_password" {
  description = "Mot de passe de l'utilisateur vSphere"
  type        = string
  sensitive   = true
}

variable "vsphere_datacenter" {
  description = "Nom du datacenter vSphere (ex: Datacenter-RBX)"
  type        = string
}

variable "vsphere_cluster" {
  description = "Nom du cluster vSphere où déployer la VM"
  type        = string
}

variable "vsphere_datastore" {
  description = "Nom du datastore pour stocker les disques de la VM"
  type        = string
}

variable "vsphere_network" {
  description = "Nom du port group réseau vSphere (ex: VLAN-100-RBX)"
  type        = string
}

# ------------------------------------------------------------------------------
# Configuration de la VM
# ------------------------------------------------------------------------------

variable "vm_name" {
  description = "Nom de la Virtual Machine (ex: VM-MYSQL-APP-A-RBX)"
  type        = string
  validation {
    condition     = can(regex("^VM-MYSQL-", var.vm_name))
    error_message = "Le nom de la VM doit commencer par 'VM-MYSQL-' pour respecter la convention de nommage."
  }
}

variable "vm_template" {
  description = "Nom du template vSphere Ubuntu à cloner (ex: ubuntu-22.04-template)"
  type        = string
  default     = "ubuntu-22.04-template"
}

variable "vm_num_cpus" {
  description = "Nombre de vCPUs alloués à la VM"
  type        = number
  default     = 4
  validation {
    condition     = var.vm_num_cpus >= 2 && var.vm_num_cpus <= 32
    error_message = "Le nombre de vCPUs doit être entre 2 et 32."
  }
}

variable "vm_memory_mb" {
  description = "Quantité de RAM en Mo (ex: 16384 pour 16 Go)"
  type        = number
  default     = 16384
  validation {
    condition     = var.vm_memory_mb >= 8192
    error_message = "Minimum 8 Go de RAM requis pour MySQL."
  }
}

variable "vm_disk_size_gb" {
  description = "Taille du disque principal (OS) en Go"
  type        = number
  default     = 50
  validation {
    condition     = var.vm_disk_size_gb >= 30
    error_message = "Minimum 30 Go requis pour OS."
  }
}

variable "vm_data_disk_size_gb" {
  description = "Taille du disque de données MySQL (/var/lib/mysql) en Go"
  type        = number
  default     = 200
  validation {
    condition     = var.vm_data_disk_size_gb >= 50
    error_message = "Minimum 50 Go requis pour les données MySQL."
  }
}

variable "vm_log_disk_size_gb" {
  description = "Taille du disque de logs MySQL (/var/log/mysql) en Go (0 = pas de disque séparé)"
  type        = number
  default     = 0
}

# ------------------------------------------------------------------------------
# Configuration réseau de la VM
# ------------------------------------------------------------------------------

variable "vm_ipv4_address" {
  description = "Adresse IPv4 statique de la VM (ex: 10.100.0.11)"
  type        = string
  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", var.vm_ipv4_address))
    error_message = "L'adresse IP doit être au format valide (ex: 10.100.0.11)."
  }
}

variable "vm_ipv4_netmask" {
  description = "Masque de sous-réseau (ex: 24 pour /24 ou 255.255.255.0)"
  type        = number
  default     = 24
  validation {
    condition     = var.vm_ipv4_netmask >= 16 && var.vm_ipv4_netmask <= 30
    error_message = "Le masque réseau doit être entre /16 et /30."
  }
}

variable "vm_ipv4_gateway" {
  description = "Passerelle par défaut (ex: 10.100.0.1)"
  type        = string
}

variable "vm_dns_servers" {
  description = "Liste des serveurs DNS (primaire et secondaire)"
  type        = list(string)
  default     = ["213.186.33.99", "8.8.8.8"] # OVH DNS + Google DNS
}

variable "vm_domain_name" {
  description = "Nom de domaine pour la VM (ex: rbx.prod.local)"
  type        = string
  default     = "prod.local"
}

# ------------------------------------------------------------------------------
# Configuration SSH et utilisateurs
# ------------------------------------------------------------------------------

variable "admin_username" {
  description = "Nom d'utilisateur administrateur de la VM"
  type        = string
  default     = "vmadmin"
}

variable "admin_ssh_public_key" {
  description = "Clé SSH publique pour l'accès administrateur"
  type        = string
  sensitive   = true
}

# ------------------------------------------------------------------------------
# Configuration MySQL
# ------------------------------------------------------------------------------

variable "mysql_version" {
  description = "Version de MySQL à installer (ex: 8.0, latest)"
  type        = string
  default     = "8.0"
}

variable "mysql_root_password" {
  description = "Mot de passe root MySQL (sera stocké dans /root/.my.cnf)"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.mysql_root_password) >= 16
    error_message = "Le mot de passe root MySQL doit contenir au moins 16 caractères."
  }
}

variable "mysql_database_name" {
  description = "Nom de la base de données applicative à créer"
  type        = string
  default     = ""
}

variable "mysql_app_user" {
  description = "Nom d'utilisateur MySQL pour l'application"
  type        = string
  default     = "appuser"
}

variable "mysql_app_password" {
  description = "Mot de passe de l'utilisateur MySQL applicatif"
  type        = string
  sensitive   = true
  default     = ""
}

variable "mysql_allowed_hosts" {
  description = "Liste des hosts/IPs autorisés à se connecter à MySQL (ex: ['10.100.0.10', '10.100.0.%'])"
  type        = list(string)
  default     = ["localhost"]
}

# ------------------------------------------------------------------------------
# Performance tuning MySQL
# ------------------------------------------------------------------------------

variable "mysql_innodb_buffer_pool_size" {
  description = "Taille du buffer pool InnoDB (ex: '12G' pour 12 Go) - Recommandé: 70-80% de la RAM"
  type        = string
  default     = "12G"
}

variable "mysql_max_connections" {
  description = "Nombre maximum de connexions simultanées"
  type        = number
  default     = 500
  validation {
    condition     = var.mysql_max_connections >= 50 && var.mysql_max_connections <= 10000
    error_message = "Le nombre de connexions doit être entre 50 et 10000."
  }
}

variable "mysql_query_cache_size" {
  description = "Taille du query cache (0 = désactivé, recommandé pour MySQL 8.0)"
  type        = number
  default     = 0
}

# ------------------------------------------------------------------------------
# Backup MySQL
# ------------------------------------------------------------------------------

variable "enable_mysql_backup" {
  description = "Activer les backups automatiques MySQL (mysqldump quotidien)"
  type        = bool
  default     = true
}

variable "mysql_backup_retention_days" {
  description = "Nombre de jours de rétention des backups locaux"
  type        = number
  default     = 7
}

variable "mysql_backup_s3_enabled" {
  description = "Activer l'envoi des backups vers S3 OVH Object Storage"
  type        = bool
  default     = false
}

# ------------------------------------------------------------------------------
# Tags et métadonnées
# ------------------------------------------------------------------------------

variable "environment" {
  description = "Environnement de déploiement (dev, test, staging, prod)"
  type        = string
  default     = "prod"
  validation {
    condition     = contains(["dev", "test", "staging", "prod"], var.environment)
    error_message = "L'environnement doit être : dev, test, staging ou prod."
  }
}

variable "project_name" {
  description = "Nom du projet (pour tagging et identification)"
  type        = string
  default     = "pra"
}

variable "owner" {
  description = "Propriétaire ou équipe responsable de la VM"
  type        = string
  default     = "devops-team"
}

variable "tags" {
  description = "Tags additionnels à appliquer à la VM (format clé-valeur)"
  type        = map(string)
  default     = {}
}

# ------------------------------------------------------------------------------
# Options de sécurité
# ------------------------------------------------------------------------------

variable "enable_firewall" {
  description = "Activer UFW (Uncomplicated Firewall) sur la VM"
  type        = bool
  default     = true
}

variable "allowed_mysql_cidrs" {
  description = "Liste de CIDRs autorisés pour MySQL (ex: ['10.100.0.0/24'])"
  type        = list(string)
  default     = []
}

variable "allowed_ssh_cidrs" {
  description = "Liste de CIDRs autorisés pour SSH (ex: ['10.0.0.0/8'])"
  type        = list(string)
  default     = ["0.0.0.0/0"] # À restreindre en production
}

variable "enable_automatic_updates" {
  description = "Activer les mises à jour automatiques de sécurité Ubuntu"
  type        = bool
  default     = true
}

variable "enable_mysql_monitoring" {
  description = "Activer l'installation de mysqld_exporter pour monitoring Prometheus"
  type        = bool
  default     = true
}
