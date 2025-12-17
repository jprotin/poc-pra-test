###############################################################################
# MODULE ZERTO VPG VMware - VARIABLES
###############################################################################

###############################################################################
# VARIABLES IDENTIFICATION
###############################################################################

variable "vpg_name" {
  description = "Nom du Virtual Protection Group"
  type        = string

  validation {
    condition     = length(var.vpg_name) > 0 && length(var.vpg_name) <= 80
    error_message = "Le nom du VPG doit contenir entre 1 et 80 caractères."
  }
}

variable "description" {
  description = "Description du VPG"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environnement (dev, staging, production)"
  type        = string
}

###############################################################################
# VARIABLES SITES SOURCE ET CIBLE (ZERTO)
###############################################################################

variable "source_site_name" {
  description = "Nom du site source (RBX ou SBG)"
  type        = string
}

variable "source_site_id" {
  description = "ID du site Zerto source"
  type        = string
}

variable "target_site_name" {
  description = "Nom du site cible (RBX ou SBG)"
  type        = string
}

variable "target_site_id" {
  description = "ID du site Zerto cible"
  type        = string
}

###############################################################################
# VARIABLES VCENTER SOURCE
###############################################################################

variable "source_vcenter" {
  description = "Serveur vCenter source (ex: pcc-xxx-xxx.ovh.com)"
  type        = string
}

variable "source_datacenter" {
  description = "Nom du datacenter vCenter source"
  type        = string
}

variable "source_cluster" {
  description = "Nom du cluster vCenter source"
  type        = string
}

###############################################################################
# VARIABLES VCENTER CIBLE
###############################################################################

variable "target_vcenter" {
  description = "Serveur vCenter cible (ex: pcc-yyy-yyy.ovh.com)"
  type        = string
}

variable "target_datacenter" {
  description = "Nom du datacenter vCenter cible"
  type        = string
}

variable "target_cluster" {
  description = "Nom du cluster vCenter cible"
  type        = string
}

###############################################################################
# VARIABLES VMs PROTÉGÉES
###############################################################################

variable "protected_vms" {
  description = "Liste des VMs à protéger dans ce VPG (avec UUID vSphere)"
  type = list(object({
    name            = string
    vm_name_vcenter = string
    vm_uuid         = string
    boot_order      = number
    failover_ip     = string
    failover_subnet = string
    description     = string
  }))

  validation {
    condition     = length(var.protected_vms) > 0
    error_message = "Au moins une VM doit être protégée dans le VPG."
  }
}

###############################################################################
# VARIABLES RPO ET JOURNAL
###############################################################################

variable "rpo_seconds" {
  description = "RPO en secondes (Recovery Point Objective)"
  type        = number
  default     = 300

  validation {
    condition     = var.rpo_seconds >= 60 && var.rpo_seconds <= 3600
    error_message = "Le RPO doit être entre 60 et 3600 secondes."
  }
}

variable "journal_history_hours" {
  description = "Durée de rétention du journal en heures"
  type        = number
  default     = 24

  validation {
    condition     = var.journal_history_hours >= 1 && var.journal_history_hours <= 720
    error_message = "La rétention doit être entre 1 et 720 heures."
  }
}

variable "test_interval_hours" {
  description = "Intervalle entre les tests de failover en heures"
  type        = number
  default     = 168
}

###############################################################################
# VARIABLES RÉSEAU VMWARE
###############################################################################

variable "target_network_name" {
  description = "Nom du réseau vSphere cible pour le failover"
  type        = string
}

variable "target_network_id" {
  description = "ID du réseau vSphere cible"
  type        = string
}

variable "target_datastore_name" {
  description = "Nom du datastore pour le journal Zerto"
  type        = string
}

variable "target_datastore_id" {
  description = "ID du datastore pour le journal Zerto"
  type        = string
}

variable "target_resource_pool_id" {
  description = "ID du resource pool cible"
  type        = string
}

variable "failover_network_config" {
  description = "Configuration réseau pour le failover"
  type = object({
    gateway       = string
    dns_primary   = string
    dns_secondary = string
    domain_name   = string
  })
}

###############################################################################
# VARIABLES FORTIGATE
###############################################################################

variable "fortigate_config" {
  description = "Configuration Fortigate pour le routage"
  type = object({
    sbg_fortigate_ip        = optional(string)
    sbg_fortigate_vip_range = optional(string)
    rbx_fortigate_ip        = optional(string)
    rbx_fortigate_vip_range = optional(string)
    bgp_peer_ip             = string
    bgp_as_number           = number
  })
}

###############################################################################
# VARIABLES OPTIONS AVANCÉES
###############################################################################

variable "priority" {
  description = "Priorité de réplication (Low, Medium, High)"
  type        = string
  default     = "High"

  validation {
    condition     = contains(["Low", "Medium", "High"], var.priority)
    error_message = "La priorité doit être Low, Medium ou High."
  }
}

variable "enable_compression" {
  description = "Activer la compression des données"
  type        = bool
  default     = true
}

variable "enable_encryption" {
  description = "Activer le chiffrement des données"
  type        = bool
  default     = true
}

variable "wan_acceleration" {
  description = "Activer l'accélération WAN"
  type        = bool
  default     = true
}

###############################################################################
# VARIABLES API ZERTO
###############################################################################

variable "zerto_api_endpoint" {
  description = "Endpoint de l'API Zerto"
  type        = string
  default     = "https://zerto-api.ovh.net"
}

variable "zerto_api_token" {
  description = "Token d'authentification API Zerto"
  type        = string
  sensitive   = true
}

###############################################################################
# VARIABLES TAGS
###############################################################################

variable "tags" {
  description = "Tags à appliquer aux ressources"
  type        = map(string)
  default     = {}
}
