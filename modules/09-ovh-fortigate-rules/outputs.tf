# ==============================================================================
# Module Terraform : FortiGate Firewall Rules - Outputs
# ==============================================================================

# ------------------------------------------------------------------------------
# FortiGate RBX - Policies
# ------------------------------------------------------------------------------

output "rbx_policy_docker_to_mysql_id" {
  description = "ID de la politique Docker → MySQL RBX"
  value       = fortios_firewall_policy.rbx_docker_to_mysql.policyid
}

output "rbx_policy_nat_id" {
  description = "ID de la politique NAT Docker RBX"
  value       = var.enable_nat_docker_rbx ? fortios_firewall_policy.rbx_docker_nat[0].policyid : null
}

output "rbx_policy_zerto_id" {
  description = "ID de la politique Zerto RBX → SBG"
  value       = fortios_firewall_policy.rbx_zerto_to_sbg.policyid
}

# ------------------------------------------------------------------------------
# FortiGate SBG - Policies
# ------------------------------------------------------------------------------

output "sbg_policy_docker_to_mysql_id" {
  description = "ID de la politique Docker → MySQL SBG"
  value       = fortios_firewall_policy.sbg_docker_to_mysql.policyid
}

output "sbg_policy_nat_id" {
  description = "ID de la politique NAT Docker SBG"
  value       = var.enable_nat_docker_sbg ? fortios_firewall_policy.sbg_docker_nat[0].policyid : null
}

output "sbg_policy_zerto_id" {
  description = "ID de la politique Zerto SBG → RBX"
  value       = fortios_firewall_policy.sbg_zerto_to_rbx.policyid
}

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------

output "firewall_rules_summary" {
  description = "Résumé des règles firewall configurées"
  value = {
    rbx = {
      docker_to_mysql = fortios_firewall_policy.rbx_docker_to_mysql.policyid
      nat_enabled     = var.enable_nat_docker_rbx
      zerto_replication = fortios_firewall_policy.rbx_zerto_to_sbg.policyid
    }
    sbg = {
      docker_to_mysql = fortios_firewall_policy.sbg_docker_to_mysql.policyid
      nat_enabled     = var.enable_nat_docker_sbg
      zerto_replication = fortios_firewall_policy.sbg_zerto_to_rbx.policyid
    }
  }
}
