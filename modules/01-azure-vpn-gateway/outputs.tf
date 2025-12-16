# ==============================================================================
# Outputs du module : Azure VPN Gateway
# ==============================================================================

# ------------------------------------------------------------------------------
# Resource Group
# ------------------------------------------------------------------------------

output "resource_group_name" {
  description = "Nom du resource group créé"
  value       = azurerm_resource_group.vpn.name
}

output "resource_group_id" {
  description = "ID du resource group créé"
  value       = azurerm_resource_group.vpn.id
}

output "location" {
  description = "Région Azure où sont déployées les ressources"
  value       = azurerm_resource_group.vpn.location
}

# ------------------------------------------------------------------------------
# Virtual Network
# ------------------------------------------------------------------------------

output "vnet_name" {
  description = "Nom du Virtual Network créé"
  value       = azurerm_virtual_network.vpn.name
}

output "vnet_id" {
  description = "ID du Virtual Network créé"
  value       = azurerm_virtual_network.vpn.id
}

output "vnet_address_space" {
  description = "Espace d'adressage du Virtual Network"
  value       = azurerm_virtual_network.vpn.address_space
}

output "gateway_subnet_id" {
  description = "ID du GatewaySubnet"
  value       = azurerm_subnet.gateway.id
}

output "default_subnet_id" {
  description = "ID du subnet par défaut"
  value       = azurerm_subnet.default.id
}

# ------------------------------------------------------------------------------
# VPN Gateway
# ------------------------------------------------------------------------------

output "vpn_gateway_id" {
  description = "ID du VPN Gateway"
  value       = azurerm_virtual_network_gateway.vpn.id
}

output "vpn_gateway_name" {
  description = "Nom du VPN Gateway"
  value       = azurerm_virtual_network_gateway.vpn.name
}

output "vpn_gateway_public_ip" {
  description = "IP publique du VPN Gateway"
  value       = azurerm_public_ip.vpn_gateway.ip_address
}

output "vpn_gateway_public_ip_id" {
  description = "ID de l'IP publique du VPN Gateway"
  value       = azurerm_public_ip.vpn_gateway.id
}

# ------------------------------------------------------------------------------
# Configuration BGP
# ------------------------------------------------------------------------------

output "bgp_enabled" {
  description = "Indique si le BGP est activé sur le VPN Gateway"
  value       = var.enable_bgp
}

output "bgp_asn" {
  description = "ASN du VPN Gateway (si BGP activé)"
  value       = var.enable_bgp ? var.bgp_asn : null
}

output "bgp_peering_address" {
  description = "Adresse de peering BGP du VPN Gateway (si BGP activé)"
  value       = var.enable_bgp ? azurerm_virtual_network_gateway.vpn.bgp_settings[0].peering_addresses[0].default_addresses[0] : null
}

output "bgp_peering_addresses_all" {
  description = "Toutes les adresses de peering BGP du VPN Gateway"
  value       = var.enable_bgp ? azurerm_virtual_network_gateway.vpn.bgp_settings[0].peering_addresses : []
}
