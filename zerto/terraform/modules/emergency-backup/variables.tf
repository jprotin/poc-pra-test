###############################################################################
# VARIABLES - MODULE EMERGENCY BACKUP
###############################################################################

###############################################################################
# VARIABLES GÉNÉRALES
###############################################################################

variable "app_name" {
  description = "Nom de l'application à protéger (Application-A ou Application-B)"
  type        = string

  validation {
    condition     = can(regex("^Application-[AB]$", var.app_name))
    error_message = "Le nom doit être 'Application-A' ou 'Application-B'."
  }
}

variable "environment" {
  description = "Environnement (production, staging, dev)"
  type        = string
  default     = "production"
}

variable "site" {
  description = "Site de déploiement (RBX ou SBG)"
  type        = string

  validation {
    condition     = contains(["RBX", "SBG"], var.site)
    error_message = "Le site doit être RBX ou SBG."
  }
}

variable "vms_to_protect" {
  description = "Liste des noms de VMs à inclure dans le backup d'urgence"
  type        = list(string)

  validation {
    condition     = length(var.vms_to_protect) > 0
    error_message = "Au moins une VM doit être spécifiée."
  }
}

variable "common_tags" {
  description = "Tags communs à appliquer aux ressources"
  type        = map(string)
  default     = {}
}

###############################################################################
# VARIABLES VEEAM
###############################################################################

variable "veeam_api_endpoint" {
  description = "URL de l'API REST Veeam (ex: https://veeam-server:9419)"
  type        = string
}

variable "veeam_api_token" {
  description = "Token d'authentification API Veeam"
  type        = string
  sensitive   = true
}

###############################################################################
# VARIABLES BACKUP LOCAL
###############################################################################

variable "enable_local_backup" {
  description = "Activer le backup local (Repository Veeam sur le site)"
  type        = bool
  default     = true
}

variable "veeam_repository_local" {
  description = "Nom du repository Veeam local pour les backups"
  type        = string
  default     = "Local-Repository"
}

variable "backup_schedule_local" {
  description = "Schedule cron pour les backups locaux"
  type        = string
  default     = "0 2,14 * * *"  # 02:00 et 14:00 tous les jours
}

variable "backup_times_local" {
  description = "Heures d'exécution des backups locaux (format 24h)"
  type        = list(string)
  default     = ["02:00", "14:00"]
}

variable "local_retention_days" {
  description = "Durée de rétention des backups locaux (jours)"
  type        = number
  default     = 7

  validation {
    condition     = var.local_retention_days >= 3 && var.local_retention_days <= 30
    error_message = "La rétention doit être entre 3 et 30 jours."
  }
}

###############################################################################
# VARIABLES S3 OBJECT STORAGE
###############################################################################

variable "enable_s3_backup" {
  description = "Activer le backup vers S3 Object Storage"
  type        = bool
  default     = true
}

variable "ovh_project_id" {
  description = "ID du projet OVHcloud Public Cloud"
  type        = string
}

variable "s3_region" {
  description = "Région S3 OVHcloud (GRA, SBG, BHS, etc.)"
  type        = string
  default     = "GRA"  # Gravelines - différent de RBX et SBG

  validation {
    condition     = contains(["GRA", "SBG", "BHS", "DE", "UK", "WAW"], var.s3_region)
    error_message = "Région S3 non valide. Choisir parmi: GRA, SBG, BHS, DE, UK, WAW."
  }
}

variable "s3_endpoint" {
  description = "Endpoint S3 OVHcloud"
  type        = string
  default     = "https://s3.gra.cloud.ovh.net"
}

variable "s3_immutable" {
  description = "Activer l'immutabilité S3 (Object Lock / WORM)"
  type        = bool
  default     = true
}

variable "s3_immutable_days" {
  description = "Durée d'immutabilité S3 en jours (mode WORM)"
  type        = number
  default     = 30

  validation {
    condition     = var.s3_immutable_days >= 7 && var.s3_immutable_days <= 90
    error_message = "La durée d'immutabilité doit être entre 7 et 90 jours."
  }
}

variable "s3_retention_days" {
  description = "Durée de rétention totale des backups S3 (jours)"
  type        = number
  default     = 30

  validation {
    condition     = var.s3_retention_days >= var.s3_immutable_days
    error_message = "La rétention S3 doit être >= à la durée d'immutabilité."
  }
}

variable "backup_schedule_s3" {
  description = "Schedule cron pour les backups S3"
  type        = string
  default     = "0 4,16 * * *"  # 04:00 et 16:00 tous les jours (après local)
}

variable "backup_times_s3" {
  description = "Heures d'exécution des backups S3 (format 24h)"
  type        = list(string)
  default     = ["04:00", "16:00"]
}

###############################################################################
# VARIABLES SÉCURITÉ
###############################################################################

variable "enable_encryption" {
  description = "Activer le chiffrement des backups"
  type        = bool
  default     = true
}

variable "encryption_algorithm" {
  description = "Algorithme de chiffrement (AES256, AES128)"
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "AES128"], var.encryption_algorithm)
    error_message = "Algorithme doit être AES256 ou AES128."
  }
}

###############################################################################
# VARIABLES MONITORING
###############################################################################

variable "enable_monitoring" {
  description = "Activer le monitoring des jobs de backup"
  type        = bool
  default     = true
}

variable "alert_webhook_url" {
  description = "URL webhook pour les alertes (Slack, Teams, etc.)"
  type        = string
  default     = ""
}

variable "alert_emails" {
  description = "Liste d'emails pour les alertes de backup"
  type        = list(string)
  default     = []
}

###############################################################################
# VARIABLES AVANCÉES
###############################################################################

variable "compression_level" {
  description = "Niveau de compression Veeam (None, Dedupe, Optimal, High, Extreme)"
  type        = string
  default     = "Optimal"

  validation {
    condition     = contains(["None", "Dedupe", "Optimal", "High", "Extreme"], var.compression_level)
    error_message = "Niveau de compression invalide."
  }
}

variable "parallel_tasks" {
  description = "Nombre de tâches parallèles pour les backups"
  type        = number
  default     = 4

  validation {
    condition     = var.parallel_tasks >= 1 && var.parallel_tasks <= 32
    error_message = "Le nombre de tâches doit être entre 1 et 32."
  }
}

variable "bandwidth_throttling_enabled" {
  description = "Activer la limitation de bande passante"
  type        = bool
  default     = false
}

variable "bandwidth_throttling_mbps" {
  description = "Limitation de bande passante en Mbps (si activé)"
  type        = number
  default     = 100

  validation {
    condition     = var.bandwidth_throttling_mbps >= 10 && var.bandwidth_throttling_mbps <= 10000
    error_message = "La bande passante doit être entre 10 et 10000 Mbps."
  }
}
