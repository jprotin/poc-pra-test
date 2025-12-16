# outputs.tf

output "strongswan_public_ip" {
  description = "Adresse IP publique de la VM StrongSwan"
  value       = azurerm_public_ip.strongswan.ip_address
}

output "strongswan_private_ip" {
  description = "Adresse IP privée de la VM StrongSwan"
  value       = azurerm_network_interface.strongswan.private_ip_address
}

output "azure_vpn_gateway_public_ip" {
  description = "Adresse IP publique du VPN Gateway Azure"
  value       = azurerm_public_ip.vpn_gateway.ip_address
}

output "ssh_command" {
  description = "Commande SSH pour se connecter à la VM StrongSwan"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.strongswan.ip_address}"
}

output "ansible_command" {
  description = "Commande pour exécuter le playbook Ansible"
  value       = "cd ansible && ansible-playbook -i inventory.ini playbook.yml"
}

output "vpn_connection_status_command" {
  description = "Commande Azure CLI pour vérifier le statut de la connexion VPN"
  value       = "az network vpn-connection show --name ${azurerm_virtual_network_gateway_connection.s2s.name} --resource-group ${azurerm_resource_group.azure.name} --query connectionStatus -o tsv"
}

output "resource_groups" {
  description = "Resource Groups créés"
  value = {
    onprem = azurerm_resource_group.onprem.name
    azure  = azurerm_resource_group.azure.name
  }
}

output "network_configuration" {
  description = "Configuration réseau"
  value = {
    onprem_vnet       = var.onprem_address_space
    azure_vnet        = var.azure_address_space
    connection_status = "Check with Azure CLI after a few minutes"
  }
}
