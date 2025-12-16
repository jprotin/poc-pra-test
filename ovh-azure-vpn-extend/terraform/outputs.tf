# outputs.tf - Extension VPN Gateway

output "existing_vpn_gateway_info" {
  description = "Informations du VPN Gateway existant"
  value = {
    name                = data.azurerm_virtual_network_gateway.existing.name
    resource_group      = data.azurerm_resource_group.existing.name
    location            = data.azurerm_virtual_network_gateway.existing.location
    sku                 = data.azurerm_virtual_network_gateway.existing.sku
    bgp_enabled         = data.azurerm_virtual_network_gateway.existing.enable_bgp
    bgp_asn             = data.azurerm_virtual_network_gateway.existing.bgp_settings[0].asn
    public_ip           = data.azurerm_public_ip.vpn_gateway.ip_address
  }
}

output "bgp_status_check" {
  description = "⚠️ VÉRIFICATION CRITIQUE: BGP doit être activé"
  value = data.azurerm_virtual_network_gateway.existing.enable_bgp ? 
    "✓ BGP est activé - Déploiement OK" : 
    "✗ ERREUR: BGP n'est PAS activé sur le VPN Gateway. Il faut l'activer ou recréer le gateway."
}

output "new_ovh_connections" {
  description = "Nouvelles connexions VPN vers OVHcloud"
  value = {
    rbx = {
      name              = azurerm_virtual_network_gateway_connection.azure_to_rbx.name
      fortigate_ip      = var.ovh_rbx_public_ip
      network_cidr      = var.ovh_rbx_network_cidr
      priority          = "PRIMARY"
      bgp_asn           = var.rbx_bgp_asn
      bgp_peer_ip       = var.rbx_bgp_peer_ip
      local_preference  = var.rbx_local_preference
    }
    sbg = {
      name              = azurerm_virtual_network_gateway_connection.azure_to_sbg.name
      fortigate_ip      = var.ovh_sbg_public_ip
      network_cidr      = var.ovh_sbg_network_cidr
      priority          = "BACKUP"
      bgp_asn           = var.sbg_bgp_asn
      bgp_peer_ip       = var.sbg_bgp_peer_ip
      local_preference  = var.sbg_local_preference
    }
  }
}

output "vpn_connections_status_commands" {
  description = "Commandes pour vérifier le statut des nouvelles connexions"
  value = {
    rbx = "az network vpn-connection show --name ${azurerm_virtual_network_gateway_connection.azure_to_rbx.name} --resource-group ${data.azurerm_resource_group.existing.name} --query connectionStatus -o tsv"
    sbg = "az network vpn-connection show --name ${azurerm_virtual_network_gateway_connection.azure_to_sbg.name} --resource-group ${data.azurerm_resource_group.existing.name} --query connectionStatus -o tsv"
  }
}

output "bgp_verification_commands" {
  description = "Commandes pour vérifier BGP"
  value = {
    learned_routes = "az network vnet-gateway list-learned-routes --name ${data.azurerm_virtual_network_gateway.existing.name} --resource-group ${data.azurerm_resource_group.existing.name} -o table"
    advertised_to_rbx = "az network vnet-gateway list-advertised-routes --name ${data.azurerm_virtual_network_gateway.existing.name} --resource-group ${data.azurerm_resource_group.existing.name} --peer ${var.rbx_bgp_peer_ip} -o table"
    advertised_to_sbg = "az network vnet-gateway list-advertised-routes --name ${data.azurerm_virtual_network_gateway.existing.name} --resource-group ${data.azurerm_resource_group.existing.name} --peer ${var.sbg_bgp_peer_ip} -o table"
  }
}

output "fortigate_configuration" {
  description = "Prochaine étape: Configuration FortiGates"
  value = {
    ansible_playbook = "cd ansible && ansible-playbook -i inventory.ini playbook-fortigate.yml"
    rbx_access = "https://${var.fortigate_rbx_mgmt_ip}"
    sbg_access = "https://${var.fortigate_sbg_mgmt_ip}"
  }
}

output "failover_test_scripts" {
  description = "Scripts de test de failover"
  value = {
    simulate_rbx_failure = "../scripts/simulate-rbx-failure.sh"
    restore_rbx          = "../scripts/restore-rbx.sh"
  }
}

output "network_summary" {
  description = "Résumé de la configuration réseau"
  value = {
    azure_vnet         = var.existing_vnet_cidr
    azure_bgp_asn      = var.azure_bgp_asn
    ovh_rbx_network    = var.ovh_rbx_network_cidr
    ovh_rbx_bgp_asn    = var.rbx_bgp_asn
    ovh_sbg_network    = var.ovh_sbg_network_cidr
    ovh_sbg_bgp_asn    = var.sbg_bgp_asn
    routing_protocol   = "BGP (eBGP)"
    primary_path       = "Azure ↔ RBX (LOCAL_PREF 200)"
    backup_path        = "Azure ↔ SBG (LOCAL_PREF 100, AS-PATH prepend x3)"
  }
}

output "important_notes" {
  description = "Notes importantes"
  value = [
    "✓ VPN Gateway existant réutilisé (pas de recréation)",
    "✓ 2 nouveaux tunnels IPsec ajoutés : RBX (Primary) et SBG (Backup)",
    "⚠️ Vérifier que BGP est bien activé (voir output 'bgp_status_check')",
    "⚠️ Les tunnels StrongSwan existants restent actifs",
    "⚠️ Total tunnels IPsec : StrongSwan (1-2) + OVH RBX (1) + OVH SBG (1) = 3-4 tunnels",
    "→ Configurer les FortiGates avec Ansible",
    "→ Tester le failover avec simulate-rbx-failure.sh"
  ]
}

output "next_steps" {
  description = "Prochaines étapes détaillées"
  value = [
    "1. Vérifier BGP activé: terraform output bgp_status_check",
    "2. Attendre 5-10 minutes que les connexions s'établissent",
    "3. Vérifier les tunnels: az network vpn-connection show ...",
    "4. Configurer FortiGates: cd ansible && ansible-playbook -i inventory.ini playbook-fortigate.yml",
    "5. Vérifier BGP peering sur FortiGates: get router info bgp summary",
    "6. Vérifier routes apprises: az network vnet-gateway list-learned-routes ...",
    "7. Tester connectivité vers 192.168.10.x et 192.168.20.x",
    "8. Simuler panne RBX: ../scripts/simulate-rbx-failure.sh",
    "9. Restaurer RBX: ../scripts/restore-rbx.sh"
  ]
}
