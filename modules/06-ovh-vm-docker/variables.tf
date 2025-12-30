# ==============================================================================
# Module Terraform : OVH VMware VM Docker
# ==============================================================================
# Description : Provisioning d'une VM Ubuntu avec Docker et Docker Compose
#               sur infrastructure OVH Private Cloud VMware vSphere
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
  description = "Nom de la Virtual Machine (ex: VM-DOCKER-APP-A-RBX)"
  type        = string
  validation {
    condition     = can(regex("^VM-DOCKER-", var.vm_name))
    error_message = "Le nom de la VM doit commencer par 'VM-DOCKER-' pour respecter la convention de nommage."
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
    condition     = var.vm_num_cpus >= 2 && var.vm_num_cpus <= 16
    error_message = "Le nombre de vCPUs doit être entre 2 et 16."
  }
}

variable "vm_memory_mb" {
  description = "Quantité de RAM en Mo (ex: 8192 pour 8 Go)"
  type        = number
  default     = 8192
  validation {
    condition     = var.vm_memory_mb >= 4096
    error_message = "Minimum 4 Go de RAM requis pour Docker."
  }
}

variable "vm_disk_size_gb" {
  description = "Taille du disque principal en Go"
  type        = number
  default     = 100
  validation {
    condition     = var.vm_disk_size_gb >= 50
    error_message = "Minimum 50 Go requis pour OS + Docker images."
  }
}

variable "vm_additional_disk_size_gb" {
  description = "Taille du disque additionnel pour volumes Docker (0 = pas de disque additionnel)"
  type        = number
  default     = 0
}

# ------------------------------------------------------------------------------
# Configuration réseau de la VM
# ------------------------------------------------------------------------------

variable "vm_ipv4_address" {
  description = "Adresse IPv4 statique de la VM (ex: 10.100.0.10)"
  type        = string
  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", var.vm_ipv4_address))
    error_message = "L'adresse IP doit être au format valide (ex: 10.100.0.10)."
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
# Configuration Docker (pour cloud-init)
# ------------------------------------------------------------------------------

variable "docker_version" {
  description = "Version de Docker Engine à installer (ex: 24.0, latest)"
  type        = string
  default     = "24.0"
}

variable "docker_compose_version" {
  description = "Version de Docker Compose à installer (ex: 2.23.0, latest)"
  type        = string
  default     = "2.23.0"
}

variable "enable_docker_monitoring" {
  description = "Activer l'installation de node_exporter et cAdvisor pour monitoring"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# Options de sécurité
# ------------------------------------------------------------------------------

variable "enable_firewall" {
  description = "Activer UFW (Uncomplicated Firewall) sur la VM"
  type        = bool
  default     = true
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
