# ==============================================================================
# Outputs du module : VM StrongSwan
# ==============================================================================

# ------------------------------------------------------------------------------
# Resource Group
# ------------------------------------------------------------------------------

output "resource_group_name" {
  description = "Nom du resource group créé"
  value       = azurerm_resource_group.onprem.name
}

output "resource_group_id" {
  description = "ID du resource group créé"
  value       = azurerm_resource_group.onprem.id
}

# ------------------------------------------------------------------------------
# Virtual Network
# ------------------------------------------------------------------------------

output "vnet_name" {
  description = "Nom du Virtual Network on-premises"
  value       = azurerm_virtual_network.onprem.name
}

output "vnet_id" {
  description = "ID du Virtual Network on-premises"
  value       = azurerm_virtual_network.onprem.id
}

output "vnet_address_space" {
  description = "Espace d'adressage du Virtual Network"
  value       = azurerm_virtual_network.onprem.address_space
}

output "subnet_id" {
  description = "ID du subnet"
  value       = azurerm_subnet.onprem.id
}

# ------------------------------------------------------------------------------
# VM StrongSwan
# ------------------------------------------------------------------------------

output "vm_id" {
  description = "ID de la VM StrongSwan"
  value       = azurerm_linux_virtual_machine.strongswan.id
}

output "vm_name" {
  description = "Nom de la VM StrongSwan"
  value       = azurerm_linux_virtual_machine.strongswan.name
}

output "vm_private_ip" {
  description = "IP privée de la VM StrongSwan"
  value       = azurerm_network_interface.strongswan.private_ip_address
}

output "vm_public_ip" {
  description = "IP publique de la VM StrongSwan"
  value       = azurerm_public_ip.strongswan.ip_address
}

output "vm_public_ip_id" {
  description = "ID de l'IP publique de la VM"
  value       = azurerm_public_ip.strongswan.id
}

# ------------------------------------------------------------------------------
# Network Interface
# ------------------------------------------------------------------------------

output "nic_id" {
  description = "ID de la Network Interface"
  value       = azurerm_network_interface.strongswan.id
}

# ------------------------------------------------------------------------------
# Informations de connexion
# ------------------------------------------------------------------------------

output "ssh_connection_string" {
  description = "Commande SSH pour se connecter à la VM"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.strongswan.ip_address}"
}

output "admin_username" {
  description = "Nom d'utilisateur admin de la VM"
  value       = var.admin_username
}

# ------------------------------------------------------------------------------
# Identité managée
# ------------------------------------------------------------------------------

output "managed_identity_principal_id" {
  description = "Principal ID de l'identité managée (si activée)"
  value       = var.enable_managed_identity ? azurerm_linux_virtual_machine.strongswan.identity[0].principal_id : null
}

output "managed_identity_tenant_id" {
  description = "Tenant ID de l'identité managée (si activée)"
  value       = var.enable_managed_identity ? azurerm_linux_virtual_machine.strongswan.identity[0].tenant_id : null
}
