# ==============================================================================
# Module Terraform : Azure VPN Gateway
# ==============================================================================
# Description : Ce module crée un VPN Gateway Azure avec support BGP
#               pour les tunnels IPsec Site-to-Site
# Auteur      : POC PRA
# Version     : 1.0
# ==============================================================================

# ------------------------------------------------------------------------------
# Resource Group Azure
# ------------------------------------------------------------------------------
# Création du groupe de ressources qui contiendra le VPN Gateway
resource "azurerm_resource_group" "vpn" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ------------------------------------------------------------------------------
# Virtual Network Azure
# ------------------------------------------------------------------------------
# Création du réseau virtuel Azure qui hébergera le VPN Gateway
resource "azurerm_virtual_network" "vpn" {
  name                = var.vnet_name
  address_space       = [var.vnet_address_space]
  location            = azurerm_resource_group.vpn.location
  resource_group_name = azurerm_resource_group.vpn.name
  tags                = var.tags
}

# ------------------------------------------------------------------------------
# Gateway Subnet
# ------------------------------------------------------------------------------
# Subnet dédié au VPN Gateway (nom "GatewaySubnet" obligatoire)
resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.vpn.name
  virtual_network_name = azurerm_virtual_network.vpn.name
  address_prefixes     = [var.gateway_subnet_cidr]
}

# ------------------------------------------------------------------------------
# Subnet par défaut
# ------------------------------------------------------------------------------
# Subnet pour les VMs de test et autres ressources
resource "azurerm_subnet" "default" {
  name                 = var.default_subnet_name
  resource_group_name  = azurerm_resource_group.vpn.name
  virtual_network_name = azurerm_virtual_network.vpn.name
  address_prefixes     = [var.default_subnet_cidr]
}

# ------------------------------------------------------------------------------
# IP Publique du VPN Gateway
# ------------------------------------------------------------------------------
# IP publique statique pour le VPN Gateway (SKU Standard requis)
resource "azurerm_public_ip" "vpn_gateway" {
  name                = var.public_ip_name
  location            = azurerm_resource_group.vpn.location
  resource_group_name = azurerm_resource_group.vpn.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# ------------------------------------------------------------------------------
# VPN Gateway
# ------------------------------------------------------------------------------
# Création du VPN Gateway Azure avec support BGP pour le routage dynamique
# ⚠️  IMPORTANT : La création prend environ 30-45 minutes
resource "azurerm_virtual_network_gateway" "vpn" {
  name                = var.vpn_gateway_name
  location            = azurerm_resource_group.vpn.location
  resource_group_name = azurerm_resource_group.vpn.name
  tags                = var.tags

  # Type de gateway : VPN (pas ExpressRoute)
  type     = "Vpn"
  vpn_type = "RouteBased"

  # Configuration Active-Active (false par défaut pour réduire les coûts)
  active_active = var.active_active

  # Activation du BGP pour le routage dynamique
  enable_bgp = var.enable_bgp
  sku        = var.sku

  # Configuration IP du VPN Gateway
  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }

  # Configuration BGP (si activé)
  dynamic "bgp_settings" {
    for_each = var.enable_bgp ? [1] : []
    content {
      asn = var.bgp_asn

      # Configuration APIPA personnalisée pour le peering BGP (optionnel)
      dynamic "peering_addresses" {
        for_each = var.bgp_peering_addresses != null ? [var.bgp_peering_addresses] : []
        content {
          ip_configuration_name = "vnetGatewayConfig"
          apipa_addresses       = peering_addresses.value.apipa_addresses
        }
      }
    }
  }
}
