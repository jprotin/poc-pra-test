# ==============================================================================
# Outputs du module : Tunnel IPsec BGP RBX
# ==============================================================================

output "local_network_gateway_id" {
  description = "ID du Local Network Gateway RBX"
  value       = azurerm_local_network_gateway.rbx.id
}

output "connection_id" {
  description = "ID de la connexion VPN RBX"
  value       = azurerm_virtual_network_gateway_connection.rbx.id
}

output "connection_name" {
  description = "Nom de la connexion VPN RBX"
  value       = azurerm_virtual_network_gateway_connection.rbx.name
}

output "connection_status_command" {
  description = "Commande pour vérifier le statut"
  value       = "az network vpn-connection show --name ${azurerm_virtual_network_gateway_connection.rbx.name} --resource-group ${var.resource_group_name} --query connectionStatus -o tsv"
}
