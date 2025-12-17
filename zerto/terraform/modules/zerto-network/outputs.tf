###############################################################################
# MODULE ZERTO NETWORK - OUTPUTS
###############################################################################

output "rbx_fortigate_status" {
  description = "État de la configuration Fortigate RBX"
  value       = "configured"
}

output "sbg_fortigate_status" {
  description = "État de la configuration Fortigate SBG"
  value       = "configured"
}

output "rbx_bgp_status" {
  description = "État du BGP sur Fortigate RBX"
  value = {
    router_id = var.bgp_config.rbx_router_id
    as_number = var.bgp_config.as_number
    peer_ip   = var.sbg_fortigate.ip_address
  }
}

output "sbg_bgp_status" {
  description = "État du BGP sur Fortigate SBG"
  value = {
    router_id = var.bgp_config.sbg_router_id
    as_number = var.bgp_config.as_number
    peer_ip   = var.rbx_fortigate.ip_address
  }
}

output "bgp_peering_established" {
  description = "Indique si le peering BGP est établi"
  value       = true
  depends_on  = [null_resource.verify_bgp_peering]
}

output "rbx_routes_count" {
  description = "Nombre de routes annoncées par RBX"
  value       = length(var.bgp_config.rbx_networks)
}

output "sbg_routes_count" {
  description = "Nombre de routes annoncées par SBG"
  value       = length(var.bgp_config.sbg_networks)
}
