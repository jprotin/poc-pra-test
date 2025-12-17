###############################################################################
# VARIABLES - CONFIGURATION ZERTO DISASTER RECOVERY
###############################################################################
# Description: Variables pour la configuration Zerto entre RBX et SBG
# Usage: Définir les valeurs dans terraform.tfvars ou via variables d'environnement
###############################################################################

###############################################################################
# VARIABLES OVH CLOUD - AUTHENTIFICATION
###############################################################################

variable "ovh_endpoint" {
  description = "Endpoint OVH API (ex: ovh-eu, ovh-ca)"
  type        = string
  default     = "ovh-eu"
}

variable "ovh_application_key" {
  description = "Clé d'application OVH API"
  type        = string
  sensitive   = true
}

variable "ovh_application_secret" {
  description = "Secret de l'application OVH API"
  type        = string
  sensitive   = true
}

variable "ovh_consumer_key" {
  description = "Clé consommateur OVH API"
  type        = string
  sensitive   = true
}

variable "ovh_project_id" {
  description = "ID du projet OVHcloud Public Cloud"
  type        = string
}

###############################################################################
# VARIABLES ENVIRONNEMENT
###############################################################################

variable "environment" {
  description = "Environnement de déploiement (dev, staging, production)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "L'environnement doit être dev, staging ou production."
  }
}

variable "common_tags" {
  description = "Tags communs à appliquer à toutes les ressources"
  type        = map(string)
  default = {
    "Project"     = "POC-PRA"
    "ManagedBy"   = "Terraform"
    "Solution"    = "Zerto"
    "CostCenter"  = "IT-Infrastructure"
  }
}

###############################################################################
# VARIABLES RÉGIONS OVH
###############################################################################

variable "region_rbx" {
  description = "Région OVH Roubaix (site primaire/DR)"
  type        = string
  default     = "GRA7"  # Ou RBX selon la disponibilité
}

variable "region_sbg" {
  description = "Région OVH Strasbourg (site primaire/DR)"
  type        = string
  default     = "SBG5"
}

###############################################################################
# VARIABLES ZERTO - CONFIGURATION GÉNÉRALE
###############################################################################

variable "zerto_site_id_rbx" {
  description = "ID du site Zerto pour la région RBX"
  type        = string
}

variable "zerto_site_id_sbg" {
  description = "ID du site Zerto pour la région SBG"
  type        = string
}

variable "zerto_rpo_seconds" {
  description = "RPO (Recovery Point Objective) en secondes - Objectif de perte de données maximale"
  type        = number
  default     = 300  # 5 minutes

  validation {
    condition     = var.zerto_rpo_seconds >= 60 && var.zerto_rpo_seconds <= 3600
    error_message = "Le RPO doit être entre 60 secondes (1 min) et 3600 secondes (1 heure)."
  }
}

variable "zerto_journal_hours" {
  description = "Durée de rétention du journal Zerto en heures"
  type        = number
  default     = 24

  validation {
    condition     = var.zerto_journal_hours >= 1 && var.zerto_journal_hours <= 720
    error_message = "La rétention du journal doit être entre 1 heure et 720 heures (30 jours)."
  }
}

variable "zerto_test_interval" {
  description = "Intervalle entre les tests de failover automatiques en heures"
  type        = number
  default     = 168  # 1 semaine

  validation {
    condition     = var.zerto_test_interval >= 24
    error_message = "L'intervalle de test doit être d'au moins 24 heures."
  }
}

variable "zerto_priority_high" {
  description = "Priorité de réplication (Low, Medium, High)"
  type        = string
  default     = "High"

  validation {
    condition     = contains(["Low", "Medium", "High"], var.zerto_priority_high)
    error_message = "La priorité doit être Low, Medium ou High."
  }
}

variable "zerto_enable_compression" {
  description = "Activer la compression des données répliquées"
  type        = bool
  default     = true
}

variable "zerto_enable_encryption" {
  description = "Activer le chiffrement des données répliquées"
  type        = bool
  default     = true
}

variable "zerto_wan_acceleration" {
  description = "Activer l'accélération WAN pour optimiser le trafic"
  type        = bool
  default     = true
}

###############################################################################
# VARIABLES VMs PROTÉGÉES - RBX
###############################################################################

variable "rbx_protected_vms" {
  description = "Liste des VMs à protéger dans la région RBX"
  type = list(object({
    name           = string
    instance_id    = string
    boot_order     = number
    failover_ip    = string
    failover_subnet = string
    description    = string
  }))

  default = [
    {
      name           = "rbx-app-prod-01"
      instance_id    = ""  # À remplir
      boot_order     = 2
      failover_ip    = "10.1.1.10"
      failover_subnet = "10.1.1.0/24"
      description    = "Serveur d'application production RBX"
    },
    {
      name           = "rbx-db-prod-01"
      instance_id    = ""  # À remplir
      boot_order     = 1
      failover_ip    = "10.1.1.20"
      failover_subnet = "10.1.1.0/24"
      description    = "Serveur de base de données production RBX"
    }
  ]
}

###############################################################################
# VARIABLES VMs PROTÉGÉES - SBG
###############################################################################

variable "sbg_protected_vms" {
  description = "Liste des VMs à protéger dans la région SBG"
  type = list(object({
    name           = string
    instance_id    = string
    boot_order     = number
    failover_ip    = string
    failover_subnet = string
    description    = string
  }))

  default = [
    {
      name           = "sbg-app-prod-01"
      instance_id    = ""  # À remplir
      boot_order     = 2
      failover_ip    = "10.2.1.10"
      failover_subnet = "10.2.1.0/24"
      description    = "Serveur d'application production SBG"
    },
    {
      name           = "sbg-db-prod-01"
      instance_id    = ""  # À remplir
      boot_order     = 1
      failover_ip    = "10.2.1.20"
      failover_subnet = "10.2.1.0/24"
      description    = "Serveur de base de données production SBG"
    }
  ]
}

###############################################################################
# VARIABLES RÉSEAU - RBX
###############################################################################

variable "rbx_target_network_id" {
  description = "ID du réseau cible dans RBX pour le failover"
  type        = string
}

variable "rbx_target_subnet_id" {
  description = "ID du sous-réseau cible dans RBX"
  type        = string
}

variable "rbx_failover_network_config" {
  description = "Configuration réseau pour failover vers RBX"
  type = object({
    gateway       = string
    dns_primary   = string
    dns_secondary = string
    domain_name   = string
  })

  default = {
    gateway       = "10.1.1.1"
    dns_primary   = "213.186.33.99"   # DNS OVH
    dns_secondary = "8.8.8.8"
    domain_name   = "rbx.local"
  }
}

variable "rbx_network_ranges" {
  description = "Plages réseau utilisées dans RBX"
  type        = list(string)
  default     = ["10.1.0.0/16", "10.1.1.0/24"]
}

###############################################################################
# VARIABLES RÉSEAU - SBG
###############################################################################

variable "sbg_target_network_id" {
  description = "ID du réseau cible dans SBG pour le failover"
  type        = string
}

variable "sbg_target_subnet_id" {
  description = "ID du sous-réseau cible dans SBG"
  type        = string
}

variable "sbg_failover_network_config" {
  description = "Configuration réseau pour failover vers SBG"
  type = object({
    gateway       = string
    dns_primary   = string
    dns_secondary = string
    domain_name   = string
  })

  default = {
    gateway       = "10.2.1.1"
    dns_primary   = "213.186.33.99"   # DNS OVH
    dns_secondary = "8.8.8.8"
    domain_name   = "sbg.local"
  }
}

variable "sbg_network_ranges" {
  description = "Plages réseau utilisées dans SBG"
  type        = list(string)
  default     = ["10.2.0.0/16", "10.2.1.0/24"]
}

###############################################################################
# VARIABLES FORTIGATE - RBX
###############################################################################

variable "rbx_fortigate_ip" {
  description = "Adresse IP du Fortigate RBX"
  type        = string
}

variable "rbx_fortigate_api_key" {
  description = "Clé API pour le Fortigate RBX"
  type        = string
  sensitive   = true
}

variable "rbx_fortigate_vip_range" {
  description = "Plage d'IPs virtuelles pour le Fortigate RBX"
  type        = string
  default     = "10.1.100.0/24"
}

variable "rbx_fortigate_internal_if" {
  description = "Interface interne du Fortigate RBX"
  type        = string
  default     = "port1"
}

variable "rbx_fortigate_external_if" {
  description = "Interface externe du Fortigate RBX"
  type        = string
  default     = "port2"
}

variable "rbx_bgp_peer_ip" {
  description = "IP du peer BGP pour RBX"
  type        = string
}

variable "rbx_bgp_router_id" {
  description = "Router ID BGP pour RBX"
  type        = string
}

variable "rbx_bgp_networks" {
  description = "Réseaux annoncés via BGP depuis RBX"
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

###############################################################################
# VARIABLES FORTIGATE - SBG
###############################################################################

variable "sbg_fortigate_ip" {
  description = "Adresse IP du Fortigate SBG"
  type        = string
}

variable "sbg_fortigate_api_key" {
  description = "Clé API pour le Fortigate SBG"
  type        = string
  sensitive   = true
}

variable "sbg_fortigate_vip_range" {
  description = "Plage d'IPs virtuelles pour le Fortigate SBG"
  type        = string
  default     = "10.2.100.0/24"
}

variable "sbg_fortigate_internal_if" {
  description = "Interface interne du Fortigate SBG"
  type        = string
  default     = "port1"
}

variable "sbg_fortigate_external_if" {
  description = "Interface externe du Fortigate SBG"
  type        = string
  default     = "port2"
}

variable "sbg_bgp_peer_ip" {
  description = "IP du peer BGP pour SBG"
  type        = string
}

variable "sbg_bgp_router_id" {
  description = "Router ID BGP pour SBG"
  type        = string
}

variable "sbg_bgp_networks" {
  description = "Réseaux annoncés via BGP depuis SBG"
  type        = list(string)
  default     = ["10.2.0.0/16"]
}

###############################################################################
# VARIABLES BGP - CONFIGURATION GLOBALE
###############################################################################

variable "bgp_as_number" {
  description = "Numéro AS BGP pour le routage dynamique"
  type        = number
  default     = 65001

  validation {
    condition     = var.bgp_as_number >= 64512 && var.bgp_as_number <= 65535
    error_message = "Le numéro AS doit être un AS privé entre 64512 et 65535."
  }
}

variable "fortigate_mgmt_port" {
  description = "Port de management des Fortigates"
  type        = number
  default     = 443
}

###############################################################################
# VARIABLES MONITORING ET ALERTES
###############################################################################

variable "alert_emails" {
  description = "Liste des emails pour les alertes Zerto"
  type        = list(string)
  default     = []
}

variable "alert_webhook_url" {
  description = "URL webhook pour les notifications (Slack, Teams, etc.)"
  type        = string
  default     = ""
}
