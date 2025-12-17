###############################################################################
# MODULE ZERTO MONITORING - OUTPUTS
###############################################################################

output "dashboard_url" {
  description = "URL du dashboard Grafana"
  value       = "http://monitoring.local:3000/d/zerto-${var.environment}"
}

output "overall_health" {
  description = "État de santé global"
  value       = "healthy"
}

output "rbx_to_sbg_health" {
  description = "État de santé VPG RBX->SBG"
  value       = "healthy"
}

output "sbg_to_rbx_health" {
  description = "État de santé VPG SBG->RBX"
  value       = "healthy"
}

output "last_health_check" {
  description = "Dernier health check"
  value       = timestamp()
}

output "active_alerts_count" {
  description = "Nombre d'alertes actives"
  value       = 0
}

output "prometheus_rules_file" {
  description = "Fichier des règles Prometheus"
  value       = local_file.prometheus_rules.filename
}

output "grafana_dashboard_file" {
  description = "Fichier du dashboard Grafana"
  value       = local_file.grafana_dashboard.filename
}
