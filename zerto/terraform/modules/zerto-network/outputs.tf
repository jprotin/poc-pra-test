###############################################################################
# MODULE ZERTO NETWORK - OUTPUTS
###############################################################################

output "rbx_fortigate_status" {
  description = "État de la configuration Fortigate RBX (VIPs et firewall pour Zerto)"
  value       = "configured"
}

output "sbg_fortigate_status" {
  description = "État de la configuration Fortigate SBG (VIPs et firewall pour Zerto)"
  value       = "configured"
}

output "zerto_ports" {
  description = "Ports Zerto configurés pour la réplication"
  value       = var.zerto_firewall_rules.zerto_ports
}
