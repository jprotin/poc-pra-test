# ==============================================================================
# Outputs Globaux - POC PRA
# ==============================================================================

# ------------------------------------------------------------------------------
# Azure VPN Gateway
# ------------------------------------------------------------------------------

output "azure_vpn_gateway_public_ip" {
  description = "IP publique du VPN Gateway Azure"
  value       = module.azure_vpn_gateway.vpn_gateway_public_ip
}

output "azure_vpn_gateway_id" {
  description = "ID du VPN Gateway Azure"
  value       = module.azure_vpn_gateway.vpn_gateway_id
}

output "azure_vnet_id" {
  description = "ID du Virtual Network Azure"
  value       = module.azure_vpn_gateway.vnet_id
}

output "azure_bgp_asn" {
  description = "ASN BGP du VPN Gateway Azure"
  value       = module.azure_vpn_gateway.bgp_asn
}

output "azure_bgp_peering_address" {
  description = "Adresse de peering BGP du VPN Gateway"
  value       = module.azure_vpn_gateway.bgp_peering_address
}

# ------------------------------------------------------------------------------
# StrongSwan VM
# ------------------------------------------------------------------------------

output "strongswan_public_ip" {
  description = "IP publique de la VM StrongSwan"
  value       = var.deploy_strongswan ? module.strongswan_vm[0].vm_public_ip : null
}

output "strongswan_private_ip" {
  description = "IP privée de la VM StrongSwan"
  value       = var.deploy_strongswan ? module.strongswan_vm[0].vm_private_ip : null
}

output "strongswan_ssh_command" {
  description = "Commande SSH pour se connecter à StrongSwan"
  value       = var.deploy_strongswan ? module.strongswan_vm[0].ssh_connection_string : null
}

# ------------------------------------------------------------------------------
# Tunnels IPsec
# ------------------------------------------------------------------------------

output "tunnel_strongswan_id" {
  description = "ID du tunnel IPsec vers StrongSwan"
  value       = var.deploy_strongswan ? module.tunnel_ipsec_static[0].connection_id : null
}

output "tunnel_rbx_id" {
  description = "ID du tunnel IPsec vers RBX"
  value       = var.deploy_ovh_rbx ? module.tunnel_ipsec_bgp_rbx[0].connection_id : null
}

output "tunnel_sbg_id" {
  description = "ID du tunnel IPsec vers SBG"
  value       = var.deploy_ovh_sbg ? module.tunnel_ipsec_bgp_sbg[0].connection_id : null
}

# ------------------------------------------------------------------------------
# Commandes de vérification
# ------------------------------------------------------------------------------

output "check_vpn_status_commands" {
  description = "Commandes pour vérifier le statut des tunnels VPN"
  value = {
    strongswan = var.deploy_strongswan ? module.tunnel_ipsec_static[0].connection_status_command : "Non déployé"
    rbx        = var.deploy_ovh_rbx ? module.tunnel_ipsec_bgp_rbx[0].connection_status_command : "Non déployé"
    sbg        = var.deploy_ovh_sbg ? module.tunnel_ipsec_bgp_sbg[0].connection_status_command : "Non déployé"
  }
}

output "check_bgp_routes_command" {
  description = "Commande pour vérifier les routes BGP apprises"
  value       = "az network vnet-gateway list-learned-routes --name ${module.azure_vpn_gateway.vpn_gateway_name} --resource-group ${module.azure_vpn_gateway.resource_group_name} --output table"
}

# ------------------------------------------------------------------------------
# Résumé de la configuration
# ------------------------------------------------------------------------------

output "deployment_summary" {
  description = "Résumé du déploiement"
  value = {
    environment           = var.environment
    azure_region          = var.azure_location
    vpn_gateway_sku       = var.vpn_gateway_sku
    bgp_enabled           = var.enable_bgp
    strongswan_deployed   = var.deploy_strongswan
    ovh_rbx_deployed      = var.deploy_ovh_rbx
    ovh_sbg_deployed      = var.deploy_ovh_sbg
    total_tunnels         = (var.deploy_strongswan ? 1 : 0) + (var.deploy_ovh_rbx ? 1 : 0) + (var.deploy_ovh_sbg ? 1 : 0)
  }
}

# ------------------------------------------------------------------------------
# Prochaines étapes
# ------------------------------------------------------------------------------

output "next_steps" {
  description = "Prochaines étapes après le déploiement Terraform"
  value = <<-EOT

    ╔════════════════════════════════════════════════════════════════════════════╗
    ║                   DÉPLOIEMENT TERRAFORM TERMINÉ                            ║
    ╚════════════════════════════════════════════════════════════════════════════╝

    📋 PROCHAINES ÉTAPES :

    1️⃣  Attendre la création complète du VPN Gateway (~30-45 minutes)

    2️⃣  Configurer StrongSwan avec Ansible (si déployé) :
       cd ../ansible
       ansible-playbook -i inventories/${var.environment}/strongswan.ini playbooks/01-configure-strongswan.yml

    3️⃣  Configurer les FortiGates avec Ansible (si déployés) :
       ansible-playbook -i inventories/${var.environment}/fortigates.ini playbooks/02-configure-fortigates.yml

    4️⃣  Vérifier le statut des tunnels :
       ../scripts/test/check-vpn-status.sh

    5️⃣  Tester la connectivité :
       ../scripts/test/test-connectivity.sh

    📚 DOCUMENTATION :
       Consulter : ../Documentation/03-DEPLOIEMENT.md

    🔒 SÉCURITÉ :
       ⚠️  Modifier ssh_source_address_prefix dans terraform.tfvars
       ⚠️  Stocker les PSK dans Azure Key Vault en production

    ╔════════════════════════════════════════════════════════════════════════════╗
    ║  Azure VPN Gateway IP : ${module.azure_vpn_gateway.vpn_gateway_public_ip}
    ${var.deploy_strongswan ? "║  StrongSwan VM IP     : ${module.strongswan_vm[0].vm_public_ip}" : ""}
    ╚════════════════════════════════════════════════════════════════════════════╝

  EOT
}
