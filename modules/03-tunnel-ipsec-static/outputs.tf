# ==============================================================================
# Outputs du module : Tunnel IPsec Statique
# ==============================================================================

# ------------------------------------------------------------------------------
# Local Network Gateway
# ------------------------------------------------------------------------------

output "local_network_gateway_id" {
  description = "ID du Local Network Gateway"
  value       = azurerm_local_network_gateway.onprem.id
}

output "local_network_gateway_name" {
  description = "Nom du Local Network Gateway"
  value       = azurerm_local_network_gateway.onprem.name
}

# ------------------------------------------------------------------------------
# VPN Connection
# ------------------------------------------------------------------------------

output "connection_id" {
  description = "ID de la connexion VPN S2S"
  value       = azurerm_virtual_network_gateway_connection.s2s.id
}

output "connection_name" {
  description = "Nom de la connexion VPN S2S"
  value       = azurerm_virtual_network_gateway_connection.s2s.name
}

# ------------------------------------------------------------------------------
# Informations de configuration
# ------------------------------------------------------------------------------

output "connection_status_command" {
  description = "Commande Azure CLI pour vérifier le statut de la connexion"
  value       = "az network vpn-connection show --name ${azurerm_virtual_network_gateway_connection.s2s.name} --resource-group ${var.resource_group_name} --query connectionStatus -o tsv"
}

output "connection_details" {
  description = "Détails de la connexion IPsec"
  value = {
    name            = azurerm_virtual_network_gateway_connection.s2s.name
    type            = azurerm_virtual_network_gateway_connection.s2s.type
    protocol        = var.connection_protocol
    bgp_enabled     = var.enable_bgp
    remote_endpoint = var.strongswan_public_ip
    remote_network  = var.onprem_address_space
  }
}

# ------------------------------------------------------------------------------
# Configuration IPsec
# ------------------------------------------------------------------------------

output "ipsec_policy" {
  description = "Politique IPsec configurée"
  value = {
    dh_group         = var.ipsec_policy.dh_group
    ike_encryption   = var.ipsec_policy.ike_encryption
    ike_integrity    = var.ipsec_policy.ike_integrity
    ipsec_encryption = var.ipsec_policy.ipsec_encryption
    ipsec_integrity  = var.ipsec_policy.ipsec_integrity
    pfs_group        = var.ipsec_policy.pfs_group
    sa_lifetime      = var.ipsec_policy.sa_lifetime
    sa_datasize      = var.ipsec_policy.sa_datasize
  }
}
