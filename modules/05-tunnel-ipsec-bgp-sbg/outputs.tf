# ==============================================================================
# Outputs du module : Tunnel IPsec BGP SBG
# ==============================================================================

output "local_network_gateway_id" {
  description = "ID du Local Network Gateway SBG"
  value       = azurerm_local_network_gateway.sbg.id
}

output "connection_id" {
  description = "ID de la connexion VPN SBG"
  value       = azurerm_virtual_network_gateway_connection.sbg.id
}

output "connection_name" {
  description = "Nom de la connexion VPN SBG"
  value       = azurerm_virtual_network_gateway_connection.sbg.name
}

output "connection_status_command" {
  description = "Commande pour vérifier le statut"
  value       = "az network vpn-connection show --name ${azurerm_virtual_network_gateway_connection.sbg.name} --resource-group ${var.resource_group_name} --query connectionStatus -o tsv"
}
