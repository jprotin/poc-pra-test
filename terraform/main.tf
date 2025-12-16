# ==============================================================================
# Configuration Terraform Principale - POC PRA
# ==============================================================================
# Description : Infrastructure hybride Azure + OVHCloud avec VPN IPsec/BGP
#               - Hub Azure avec VPN Gateway
#               - VM StrongSwan (simulation on-premises)
#               - Tunnels IPsec vers OVHCloud RBX et SBG (FortiGate)
#               - Infrastructure VMware sur OVHCloud
# Auteur      : POC PRA
# Version     : 1.0
# ==============================================================================

# ------------------------------------------------------------------------------
# Configuration Terraform et Providers
# ------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Provider Azure
provider "azurerm" {
  features {
    # Comportement lors de la suppression de ressources
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# ------------------------------------------------------------------------------
# Variables locales communes
# ------------------------------------------------------------------------------

locals {
  # Tags communs à appliquer à toutes les ressources
  common_tags = {
    Environment = var.environment
    Project     = "POC-PRA"
    ManagedBy   = "Terraform"
    Repository  = "poc-pra-test"
    Owner       = var.owner
  }

  # Noms de ressources standardisés
  resource_prefix = "${var.environment}-${var.project_name}"
}

# ==============================================================================
# MODULE 1 : Azure VPN Gateway
# ==============================================================================
# Crée le hub Azure avec VPN Gateway pour les tunnels IPsec

module "azure_vpn_gateway" {
  source = "../modules/01-azure-vpn-gateway"

  # Configuration du Resource Group
  resource_group_name = "rg-${local.resource_prefix}-vpn"
  location            = var.azure_location

  # Configuration du Virtual Network
  vnet_name           = "vnet-${local.resource_prefix}-azure"
  vnet_address_space  = var.azure_vnet_cidr
  gateway_subnet_cidr = var.azure_gateway_subnet_cidr
  default_subnet_cidr = var.azure_default_subnet_cidr

  # Configuration du VPN Gateway
  vpn_gateway_name = "vpngw-${local.resource_prefix}"
  public_ip_name   = "pip-${local.resource_prefix}-vpngw"
  sku              = var.vpn_gateway_sku
  active_active    = var.vpn_gateway_active_active

  # Configuration BGP
  enable_bgp = var.enable_bgp
  bgp_asn    = var.azure_bgp_asn

  # Tags
  tags = merge(local.common_tags, {
    Component = "VPN-Gateway"
    Tier      = "Hub"
  })
}

# ==============================================================================
# MODULE 2 : VM StrongSwan (On-Premises Simulé)
# ==============================================================================
# Crée une VM avec StrongSwan pour simuler un site on-premises

module "strongswan_vm" {
  source = "../modules/02-strongswan-vm"

  # Ne déployer que si activé
  count = var.deploy_strongswan ? 1 : 0

  # Configuration du Resource Group
  resource_group_name = "rg-${local.resource_prefix}-onprem"
  location            = var.onprem_location

  # Configuration du Virtual Network
  vnet_name          = "vnet-${local.resource_prefix}-onprem"
  vnet_address_space = var.onprem_vnet_cidr
  subnet_cidr        = var.onprem_subnet_cidr

  # Configuration de la VM
  vm_name              = "vm-${local.resource_prefix}-strongswan"
  vm_size              = var.strongswan_vm_size
  admin_username       = var.admin_username
  ssh_public_key       = var.ssh_public_key
  ssh_public_key_path  = var.ssh_public_key_path

  # Configuration réseau
  nsg_name                     = "nsg-${local.resource_prefix}-strongswan"
  public_ip_name               = "pip-${local.resource_prefix}-strongswan"
  nic_name                     = "nic-${local.resource_prefix}-strongswan"
  ssh_source_address_prefix    = var.ssh_source_address_prefix

  # Options avancées
  enable_managed_identity = false

  # Tags
  tags = merge(local.common_tags, {
    Component = "StrongSwan"
    Tier      = "On-Premises"
  })
}

# ==============================================================================
# MODULE 3 : Tunnel IPsec Statique (Azure <-> StrongSwan)
# ==============================================================================
# Crée un tunnel IPsec statique entre Azure et la VM StrongSwan

module "tunnel_ipsec_static" {
  source = "../modules/03-tunnel-ipsec-static"

  # Ne déployer que si StrongSwan est activé
  count = var.deploy_strongswan ? 1 : 0

  # Dépend de la création du VPN Gateway et de la VM StrongSwan
  depends_on = [
    module.azure_vpn_gateway,
    module.strongswan_vm
  ]

  # Configuration générale
  resource_group_name = module.azure_vpn_gateway.resource_group_name
  location            = module.azure_vpn_gateway.location

  # Configuration du Local Network Gateway
  local_network_gateway_name = "lng-${local.resource_prefix}-onprem"
  strongswan_public_ip       = module.strongswan_vm[0].vm_public_ip
  onprem_address_space       = var.onprem_vnet_cidr

  # Configuration de la connexion VPN
  connection_name     = "conn-${local.resource_prefix}-s2s-onprem"
  vpn_gateway_id      = module.azure_vpn_gateway.vpn_gateway_id
  ipsec_psk           = var.ipsec_psk_strongswan
  connection_protocol = "IKEv2"
  connection_mode     = "Default"

  # BGP désactivé pour le tunnel statique
  enable_bgp = false

  # Politique IPsec (compatible StrongSwan)
  ipsec_policy = var.ipsec_policy_strongswan

  # Tags
  tags = merge(local.common_tags, {
    Component  = "Tunnel-Static"
    Connection = "Azure-StrongSwan"
  })
}

# ==============================================================================
# MODULE 4 : Tunnel IPsec BGP vers RBX (Azure <-> OVHCloud RBX)
# ==============================================================================
# Crée un tunnel IPsec avec BGP vers le datacenter OVHCloud RBX (Primary)

module "tunnel_ipsec_bgp_rbx" {
  source = "../modules/04-tunnel-ipsec-bgp-rbx"

  # Ne déployer que si activé
  count = var.deploy_ovh_rbx ? 1 : 0

  # Dépend de la création du VPN Gateway
  depends_on = [module.azure_vpn_gateway]

  # Configuration générale
  resource_group_name = module.azure_vpn_gateway.resource_group_name
  location            = module.azure_vpn_gateway.location

  # Configuration du Local Network Gateway
  local_network_gateway_name = "lng-${local.resource_prefix}-ovh-rbx"
  remote_gateway_ip          = var.ovh_rbx_public_ip

  # Configuration de la connexion VPN
  connection_name     = "conn-${local.resource_prefix}-azure-rbx"
  vpn_gateway_id      = module.azure_vpn_gateway.vpn_gateway_id
  ipsec_psk           = var.ipsec_psk_rbx
  connection_protocol = "IKEv2"

  # Configuration BGP
  enable_bgp          = true
  bgp_asn             = var.ovh_rbx_bgp_asn
  bgp_peering_address = var.ovh_rbx_bgp_peer_ip

  # Politique IPsec (compatible FortiGate)
  ipsec_policy = var.ipsec_policy_fortigate

  # Tags
  tags = merge(local.common_tags, {
    Component  = "Tunnel-BGP"
    Connection = "Azure-RBX"
    Priority   = "Primary"
  })
}

# ==============================================================================
# MODULE 5 : Tunnel IPsec BGP vers SBG (Azure <-> OVHCloud SBG)
# ==============================================================================
# Crée un tunnel IPsec avec BGP vers le datacenter OVHCloud SBG (Backup)

module "tunnel_ipsec_bgp_sbg" {
  source = "../modules/05-tunnel-ipsec-bgp-sbg"

  # Ne déployer que si activé
  count = var.deploy_ovh_sbg ? 1 : 0

  # Dépend de la création du VPN Gateway
  depends_on = [module.azure_vpn_gateway]

  # Configuration générale
  resource_group_name = module.azure_vpn_gateway.resource_group_name
  location            = module.azure_vpn_gateway.location

  # Configuration du Local Network Gateway
  local_network_gateway_name = "lng-${local.resource_prefix}-ovh-sbg"
  remote_gateway_ip          = var.ovh_sbg_public_ip

  # Configuration de la connexion VPN
  connection_name     = "conn-${local.resource_prefix}-azure-sbg"
  vpn_gateway_id      = module.azure_vpn_gateway.vpn_gateway_id
  ipsec_psk           = var.ipsec_psk_sbg
  connection_protocol = "IKEv2"

  # Configuration BGP
  enable_bgp          = true
  bgp_asn             = var.ovh_sbg_bgp_asn
  bgp_peering_address = var.ovh_sbg_bgp_peer_ip

  # Politique IPsec (compatible FortiGate)
  ipsec_policy = var.ipsec_policy_fortigate

  # Tags
  tags = merge(local.common_tags, {
    Component  = "Tunnel-BGP"
    Connection = "Azure-SBG"
    Priority   = "Backup"
  })
}

# ==============================================================================
# MODULE 6 : Infrastructure VMware OVHCloud (optionnel - géré manuellement)
# ==============================================================================
# Note : L'infrastructure VMware sur OVHCloud (FortiGate, VMs applicatives)
#        est généralement gérée manuellement ou via des outils spécifiques
#        Ce module est optionnel et peut être géré par Ansible uniquement

# module "ovh_vmware_infrastructure" {
#   source = "../modules/06-ovh-vmware-infrastructure"
#   count  = var.deploy_ovh_infrastructure ? 1 : 0
#
#   # Configuration à définir selon l'environnement OVHCloud
#   # ...
# }

# ==============================================================================
# Génération de fichiers pour Ansible
# ==============================================================================

# Inventaire Ansible pour StrongSwan
resource "local_file" "ansible_inventory_strongswan" {
  count = var.deploy_strongswan ? 1 : 0

  filename = "${path.module}/../ansible/inventories/${var.environment}/strongswan.ini"

  content = templatefile("${path.module}/templates/inventory-strongswan.tpl", {
    strongswan_public_ip  = module.strongswan_vm[0].vm_public_ip
    strongswan_private_ip = module.strongswan_vm[0].vm_private_ip
    admin_username        = var.admin_username
  })

  file_permission = "0644"
}

# Variables Ansible pour StrongSwan
resource "local_file" "ansible_vars_strongswan" {
  count = var.deploy_strongswan ? 1 : 0

  filename = "${path.module}/../ansible/group_vars/${var.environment}/strongswan.yml"

  content = templatefile("${path.module}/templates/ansible-vars-strongswan.tpl", {
    azure_vpn_public_ip  = module.azure_vpn_gateway.vpn_gateway_public_ip
    azure_vnet_cidr      = var.azure_vnet_cidr
    onprem_vnet_cidr     = var.onprem_vnet_cidr
    ipsec_psk            = var.ipsec_psk_strongswan
    ipsec_policy         = var.ipsec_policy_strongswan
  })

  file_permission = "0644"
}

# Inventaire Ansible pour FortiGates
resource "local_file" "ansible_inventory_fortigates" {
  count = (var.deploy_ovh_rbx || var.deploy_ovh_sbg) ? 1 : 0

  filename = "${path.module}/../ansible/inventories/${var.environment}/fortigates.ini"

  content = templatefile("${path.module}/templates/inventory-fortigates.tpl", {
    deploy_rbx         = var.deploy_ovh_rbx
    deploy_sbg         = var.deploy_ovh_sbg
    rbx_mgmt_ip        = var.ovh_rbx_mgmt_ip
    sbg_mgmt_ip        = var.ovh_sbg_mgmt_ip
    azure_vpn_ip       = module.azure_vpn_gateway.vpn_gateway_public_ip
    rbx_public_ip      = var.ovh_rbx_public_ip
    sbg_public_ip      = var.ovh_sbg_public_ip
  })

  file_permission = "0644"
}

# ==============================================================================
# Génération de scripts de test
# ==============================================================================

# Script de vérification du statut des connexions
resource "local_file" "check_vpn_status" {
  filename = "${path.module}/../scripts/test/check-vpn-status.sh"

  content = templatefile("${path.module}/templates/check-vpn-status.tpl", {
    resource_group          = module.azure_vpn_gateway.resource_group_name
    connection_strongswan   = var.deploy_strongswan ? module.tunnel_ipsec_static[0].connection_name : ""
    connection_rbx          = var.deploy_ovh_rbx ? module.tunnel_ipsec_bgp_rbx[0].connection_name : ""
    connection_sbg          = var.deploy_ovh_sbg ? module.tunnel_ipsec_bgp_sbg[0].connection_name : ""
    deploy_strongswan       = var.deploy_strongswan
    deploy_rbx              = var.deploy_ovh_rbx
    deploy_sbg              = var.deploy_ovh_sbg
  })

  file_permission = "0755"
}
