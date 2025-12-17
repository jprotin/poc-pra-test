###############################################################################
# MODULE ZERTO MONITORING - VARIABLES
###############################################################################

variable "environment" {
  description = "Environnement"
  type        = string
}

variable "project_id" {
  description = "ID du projet OVH"
  type        = string
}

variable "vpg_rbx_to_sbg_id" {
  description = "ID du VPG RBX vers SBG"
  type        = string
}

variable "vpg_sbg_to_rbx_id" {
  description = "ID du VPG SBG vers RBX"
  type        = string
}

variable "alert_thresholds" {
  description = "Seuils d'alerte"
  type = object({
    rpo_warning_seconds     = number
    rpo_critical_seconds    = number
    journal_usage_warning   = number
    journal_usage_critical  = number
    bandwidth_warning_mbps  = number
    bandwidth_critical_mbps = number
  })
}

variable "notification_emails" {
  description = "Emails pour notifications"
  type        = list(string)
  default     = []
}

variable "webhook_url" {
  description = "URL webhook pour alertes"
  type        = string
  default     = ""
}

variable "enable_custom_metrics" {
  description = "Activer métriques personnalisées"
  type        = bool
  default     = true
}

variable "metrics_retention_days" {
  description = "Rétention des métriques en jours"
  type        = number
  default     = 90
}
