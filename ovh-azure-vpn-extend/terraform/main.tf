# main.tf - Extension du VPN Gateway existant pour OVHcloud RBX/SBG avec BGP

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

provider "azurerm" {
  features {}
}

# Variables locales
locals {
  common_tags = {
    Environment = var.environment
    Project     = "Azure-OVH-VPN-BGP"
    ManagedBy   = "Terraform"
    Purpose     = "Multi-Region-HA"
  }
  
  # Configuration BGP
  azure_bgp_asn    = var.azure_bgp_asn
  rbx_bgp_asn      = var.rbx_bgp_asn
  sbg_bgp_asn      = var.sbg_bgp_asn
}

###############################
# Utilisation du VPN Gateway existant
###############################

# Data source pour récupérer le Resource Group existant
data "azurerm_resource_group" "existing" {
  name = var.existing_resource_group_name
}

# Data source pour récupérer le VPN Gateway existant
data "azurerm_virtual_network_gateway" "existing" {
  name                = var.existing_vpn_gateway_name
  resource_group_name = data.azurerm_resource_group.existing.name
}

# Data source pour récupérer le VNet existant
data "azurerm_virtual_network" "existing" {
  name                = var.existing_vnet_name
  resource_group_name = data.azurerm_resource_group.existing.name
}

###############################
# Mise à jour du VPN Gateway pour activer BGP (si pas déjà fait)
###############################

# Note: Si BGP n'est pas activé sur le gateway existant, il faut le recréer
# ou le modifier manuellement. Terraform ne peut pas modifier cette propriété
# sur un gateway existant sans le recréer.

# Vérification que BGP est activé (via output)
output "vpn_gateway_bgp_status" {
  value = data.azurerm_virtual_network_gateway.existing.enable_bgp
  description = "BGP doit être 'true'. Si 'false', il faut activer BGP manuellement ou recréer le gateway."
}

###############################
# Local Network Gateway - OVHcloud RBX (Primary)
###############################

resource "azurerm_local_network_gateway" "ovh_rbx" {
  name                = "lng-${var.environment}-ovh-rbx"
  location            = data.azurerm_resource_group.existing.location
  resource_group_name = data.azurerm_resource_group.existing.name
  gateway_address     = var.ovh_rbx_public_ip
  tags                = merge(local.common_tags, { Region = "RBX", Priority = "Primary" })

  # Configuration BGP pour RBX
  bgp_settings {
    asn                 = local.rbx_bgp_asn
    bgp_peering_address = var.rbx_bgp_peer_ip
  }
}

###############################
# Local Network Gateway - OVHcloud SBG (Secondary/Backup)
###############################

resource "azurerm_local_network_gateway" "ovh_sbg" {
  name                = "lng-${var.environment}-ovh-sbg"
  location            = data.azurerm_resource_group.existing.location
  resource_group_name = data.azurerm_resource_group.existing.name
  gateway_address     = var.ovh_sbg_public_ip
  tags                = merge(local.common_tags, { Region = "SBG", Priority = "Backup" })

  # Configuration BGP pour SBG
  bgp_settings {
    asn                 = local.sbg_bgp_asn
    bgp_peering_address = var.sbg_bgp_peer_ip
  }
}

###############################
# VPN Connection - Azure <-> OVH RBX (Primary)
###############################

resource "azurerm_virtual_network_gateway_connection" "azure_to_rbx" {
  name                = "conn-${var.environment}-azure-rbx-primary"
  location            = data.azurerm_resource_group.existing.location
  resource_group_name = data.azurerm_resource_group.existing.name
  tags                = merge(local.common_tags, { Path = "Azure-RBX", Priority = "Primary" })

  type                       = "IPsec"
  virtual_network_gateway_id = data.azurerm_virtual_network_gateway.existing.id
  local_network_gateway_id   = azurerm_local_network_gateway.ovh_rbx.id

  shared_key = var.ipsec_psk_rbx

  # BGP activé pour routage dynamique
  enable_bgp = true

  # Paramètres IPsec compatibles FortiGate
  ipsec_policy {
    dh_group         = "DHGroup14"
    ike_encryption   = "AES256"
    ike_integrity    = "SHA256"
    ipsec_encryption = "AES256"
    ipsec_integrity  = "SHA256"
    pfs_group        = "PFS2048"
    sa_lifetime      = 27000
    sa_datasize      = 102400000
  }

  connection_protocol = "IKEv2"
  
  # Custom BGP settings
  dynamic "custom_bgp_addresses" {
    for_each = var.use_custom_bgp_addresses ? [1] : []
    content {
      primary   = var.azure_bgp_apipa_primary
      secondary = var.azure_bgp_apipa_secondary
    }
  }
}

###############################
# VPN Connection - Azure <-> OVH SBG (Backup)
###############################

resource "azurerm_virtual_network_gateway_connection" "azure_to_sbg" {
  name                = "conn-${var.environment}-azure-sbg-backup"
  location            = data.azurerm_resource_group.existing.location
  resource_group_name = data.azurerm_resource_group.existing.name
  tags                = merge(local.common_tags, { Path = "Azure-SBG", Priority = "Backup" })

  type                       = "IPsec"
  virtual_network_gateway_id = data.azurerm_virtual_network_gateway.existing.id
  local_network_gateway_id   = azurerm_local_network_gateway.ovh_sbg.id

  shared_key = var.ipsec_psk_sbg

  # BGP activé pour routage dynamique
  enable_bgp = true

  # Paramètres IPsec identiques à RBX
  ipsec_policy {
    dh_group         = "DHGroup14"
    ike_encryption   = "AES256"
    ike_integrity    = "SHA256"
    ipsec_encryption = "AES256"
    ipsec_integrity  = "SHA256"
    pfs_group        = "PFS2048"
    sa_lifetime      = 27000
    sa_datasize      = 102400000
  }

  connection_protocol = "IKEv2"
  
  dynamic "custom_bgp_addresses" {
    for_each = var.use_custom_bgp_addresses ? [1] : []
    content {
      primary   = var.azure_bgp_apipa_primary
      secondary = var.azure_bgp_apipa_secondary
    }
  }
}

###############################
# Routes vers OVH (ajoutées à la route table existante si spécifiée)
###############################

# Data source pour la route table existante (optionnel)
data "azurerm_route_table" "existing" {
  count               = var.existing_route_table_name != "" ? 1 : 0
  name                = var.existing_route_table_name
  resource_group_name = data.azurerm_resource_group.existing.name
}

# Routes vers OVH RBX
resource "azurerm_route" "to_ovh_rbx" {
  count               = var.existing_route_table_name != "" ? 1 : 0
  name                = "route-to-ovh-rbx"
  resource_group_name = data.azurerm_resource_group.existing.name
  route_table_name    = var.existing_route_table_name
  address_prefix      = var.ovh_rbx_network_cidr
  next_hop_type       = "VirtualNetworkGateway"
}

# Routes vers OVH SBG
resource "azurerm_route" "to_ovh_sbg" {
  count               = var.existing_route_table_name != "" ? 1 : 0
  name                = "route-to-ovh-sbg"
  resource_group_name = data.azurerm_resource_group.existing.name
  route_table_name    = var.existing_route_table_name
  address_prefix      = var.ovh_sbg_network_cidr
  next_hop_type       = "VirtualNetworkGateway"
}

###############################
# Génération des fichiers Ansible
###############################

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tpl", {
    azure_vpn_gateway_ip     = data.azurerm_virtual_network_gateway.existing.ip_configuration[0].public_ip_address_id
    azure_bgp_asn            = var.azure_bgp_asn
    azure_bgp_peer_primary   = var.azure_bgp_apipa_primary
    rbx_fortigate_ip         = var.ovh_rbx_public_ip
    rbx_bgp_asn              = local.rbx_bgp_asn
    rbx_bgp_peer_ip          = var.rbx_bgp_peer_ip
    sbg_fortigate_ip         = var.ovh_sbg_public_ip
    sbg_bgp_asn              = local.sbg_bgp_asn
    sbg_bgp_peer_ip          = var.sbg_bgp_peer_ip
    admin_username           = var.admin_username
  })
  filename = "${path.module}/ansible/inventory.ini"
}

resource "local_file" "ansible_vars" {
  content = templatefile("${path.module}/templates/ansible_vars.tpl", {
    azure_vpn_gateway_ip     = data.azurerm_virtual_network_gateway.existing.ip_configuration[0].public_ip_address_id
    azure_vnet_cidr          = var.existing_vnet_cidr
    azure_bgp_asn            = var.azure_bgp_asn
    azure_bgp_peer_primary   = var.azure_bgp_apipa_primary
    rbx_fortigate_ip         = var.ovh_rbx_public_ip
    rbx_network_cidr         = var.ovh_rbx_network_cidr
    rbx_bgp_asn              = local.rbx_bgp_asn
    rbx_bgp_peer_ip          = var.rbx_bgp_peer_ip
    sbg_fortigate_ip         = var.ovh_sbg_public_ip
    sbg_network_cidr         = var.ovh_sbg_network_cidr
    sbg_bgp_asn              = local.sbg_bgp_asn
    sbg_bgp_peer_ip          = var.sbg_bgp_peer_ip
    ipsec_psk_rbx            = var.ipsec_psk_rbx
    ipsec_psk_sbg            = var.ipsec_psk_sbg
  })
  filename = "${path.module}/ansible/group_vars/all.yml"
}

###############################
# Récupération de l'IP publique du VPN Gateway
###############################

# Récupérer l'IP publique du VPN Gateway
data "azurerm_public_ip" "vpn_gateway" {
  name                = split("/", data.azurerm_virtual_network_gateway.existing.ip_configuration[0].public_ip_address_id)[8]
  resource_group_name = data.azurerm_resource_group.existing.name
}
