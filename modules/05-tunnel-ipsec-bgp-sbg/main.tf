# ==============================================================================
# Module Terraform : Tunnel IPsec BGP vers SBG
# ==============================================================================
# Description : Ce module crée un tunnel IPsec avec BGP vers OVHCloud SBG
#               (datacenter backup avec priorité BGP plus faible)
# Auteur      : POC PRA
# Version     : 1.0
# ==============================================================================

# ------------------------------------------------------------------------------
# Local Network Gateway pour OVHCloud SBG
# ------------------------------------------------------------------------------
resource "azurerm_local_network_gateway" "sbg" {
  name                = var.local_network_gateway_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # IP publique du FortiGate SBG
  gateway_address = var.remote_gateway_ip

  # Configuration BGP pour SBG
  bgp_settings {
    asn                 = var.bgp_asn
    bgp_peering_address = var.bgp_peering_address
  }
}

# ------------------------------------------------------------------------------
# VPN Connection vers SBG avec BGP
# ------------------------------------------------------------------------------
resource "azurerm_virtual_network_gateway_connection" "sbg" {
  name                = var.connection_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  type                       = "IPsec"
  virtual_network_gateway_id = var.vpn_gateway_id
  local_network_gateway_id   = azurerm_local_network_gateway.sbg.id

  # Pre-Shared Key pour authentification
  shared_key = var.ipsec_psk

  # BGP activé pour routage dynamique et failover
  enable_bgp = var.enable_bgp

  # Protocole IKEv2
  connection_protocol = var.connection_protocol

  # Politique IPsec compatible FortiGate (identique à RBX)
  ipsec_policy {
    dh_group         = var.ipsec_policy.dh_group
    ike_encryption   = var.ipsec_policy.ike_encryption
    ike_integrity    = var.ipsec_policy.ike_integrity
    ipsec_encryption = var.ipsec_policy.ipsec_encryption
    ipsec_integrity  = var.ipsec_policy.ipsec_integrity
    pfs_group        = var.ipsec_policy.pfs_group
    sa_lifetime      = var.ipsec_policy.sa_lifetime
    sa_datasize      = var.ipsec_policy.sa_datasize
  }

  # Timeout DPD pour détection rapide des pannes
  dpd_timeout_seconds = var.dpd_timeout_seconds
}
