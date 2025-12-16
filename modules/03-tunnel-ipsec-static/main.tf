# ==============================================================================
# Module Terraform : Tunnel IPsec Statique (Azure <-> StrongSwan)
# ==============================================================================
# Description : Ce module crée un tunnel IPsec Site-to-Site statique entre
#               Azure VPN Gateway et une VM StrongSwan (on-premises simulé)
# Auteur      : POC PRA
# Version     : 1.0
# ==============================================================================

# ------------------------------------------------------------------------------
# Local Network Gateway (représente le site on-premises avec StrongSwan)
# ------------------------------------------------------------------------------
# Ce Local Network Gateway indique à Azure comment atteindre le réseau on-prem
resource "azurerm_local_network_gateway" "onprem" {
  name                = var.local_network_gateway_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # IP publique de la VM StrongSwan (endpoint distant)
  gateway_address = var.strongswan_public_ip

  # Espace d'adressage du réseau on-premises
  address_space = [var.onprem_address_space]

  # Configuration BGP optionnelle (pour tunnel statique, généralement désactivée)
  dynamic "bgp_settings" {
    for_each = var.enable_bgp ? [1] : []
    content {
      asn                 = var.bgp_asn
      bgp_peering_address = var.bgp_peering_address
    }
  }
}

# ------------------------------------------------------------------------------
# VPN Connection Site-to-Site
# ------------------------------------------------------------------------------
# Crée la connexion IPsec entre le VPN Gateway Azure et le site on-premises
resource "azurerm_virtual_network_gateway_connection" "s2s" {
  name                = var.connection_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # Type de connexion : IPsec Site-to-Site
  type = "IPsec"

  # Références aux gateways
  virtual_network_gateway_id = var.vpn_gateway_id
  local_network_gateway_id   = azurerm_local_network_gateway.onprem.id

  # Pre-Shared Key (PSK) pour authentification IPsec
  # ⚠️  SÉCURITÉ : Utiliser un PSK fort et le stocker de manière sécurisée
  shared_key = var.ipsec_psk

  # Activer BGP si configuré
  enable_bgp = var.enable_bgp

  # Protocole de connexion
  connection_protocol = var.connection_protocol

  # Mode de connexion (InitiatorOnly, ResponderOnly, Default)
  connection_mode = var.connection_mode

  # Politique IPsec personnalisée
  # Compatible avec StrongSwan et Azure VPN Gateway
  ipsec_policy {
    # Phase 1 (IKE)
    dh_group         = var.ipsec_policy.dh_group         # Diffie-Hellman Group
    ike_encryption   = var.ipsec_policy.ike_encryption   # Algorithme de chiffrement IKE
    ike_integrity    = var.ipsec_policy.ike_integrity    # Intégrité IKE

    # Phase 2 (IPsec)
    ipsec_encryption = var.ipsec_policy.ipsec_encryption # Algorithme de chiffrement IPsec
    ipsec_integrity  = var.ipsec_policy.ipsec_integrity  # Intégrité IPsec
    pfs_group        = var.ipsec_policy.pfs_group        # Perfect Forward Secrecy

    # Paramètres de durée de vie
    sa_lifetime = var.ipsec_policy.sa_lifetime # Durée de vie SA en secondes
    sa_datasize = var.ipsec_policy.sa_datasize # Durée de vie SA en Ko
  }

  # Paramètres DPD (Dead Peer Detection) pour détecter les pannes
  dpd_timeout_seconds = var.dpd_timeout_seconds

  # Paramètres de Traffic Selector (pour contrôler les réseaux autorisés)
  dynamic "traffic_selector_policy" {
    for_each = var.traffic_selector_policies
    content {
      local_address_cidrs  = traffic_selector_policy.value.local_address_cidrs
      remote_address_cidrs = traffic_selector_policy.value.remote_address_cidrs
    }
  }
}
