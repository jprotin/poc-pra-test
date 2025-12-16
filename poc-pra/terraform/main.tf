# main.tf - Infrastructure IPsec S2S avec StrongSwan et Azure VPN Gateway

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

# Variables
locals {
  common_tags = {
    Environment = var.environment
    Project     = "IPsec-S2S-Demo"
    ManagedBy   = "Terraform"
  }
}

###############################
# On-Premises Simulated Site
###############################

resource "azurerm_resource_group" "onprem" {
  name     = "rg-${var.environment}-onprem"
  location = var.onprem_location
  tags     = local.common_tags
}

# VNet on-premises simulé
resource "azurerm_virtual_network" "onprem" {
  name                = "vnet-${var.environment}-onprem"
  address_space       = [var.onprem_address_space]
  location            = azurerm_resource_group.onprem.location
  resource_group_name = azurerm_resource_group.onprem.name
  tags                = local.common_tags
}

resource "azurerm_subnet" "onprem" {
  name                 = "subnet-vpn"
  resource_group_name  = azurerm_resource_group.onprem.name
  virtual_network_name = azurerm_virtual_network.onprem.name
  address_prefixes     = [var.onprem_subnet_cidr]
}

# NSG pour StrongSwan
resource "azurerm_network_security_group" "strongswan" {
  name                = "nsg-${var.environment}-strongswan"
  location            = azurerm_resource_group.onprem.location
  resource_group_name = azurerm_resource_group.onprem.name
  tags                = local.common_tags

  security_rule {
    name                       = "Allow-IKE"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "500"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-IPsec-NAT-T"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "4500"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-ESP"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Esp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Public IP pour StrongSwan
resource "azurerm_public_ip" "strongswan" {
  name                = "pip-${var.environment}-strongswan"
  location            = azurerm_resource_group.onprem.location
  resource_group_name = azurerm_resource_group.onprem.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

# Network Interface pour StrongSwan
resource "azurerm_network_interface" "strongswan" {
  name                = "nic-${var.environment}-strongswan"
  location            = azurerm_resource_group.onprem.location
  resource_group_name = azurerm_resource_group.onprem.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.onprem.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.strongswan.id
  }

  enable_ip_forwarding = true
}

# Association NSG
resource "azurerm_network_interface_security_group_association" "strongswan" {
  network_interface_id      = azurerm_network_interface.strongswan.id
  network_security_group_id = azurerm_network_security_group.strongswan.id
}

# VM StrongSwan
resource "azurerm_linux_virtual_machine" "strongswan" {
  name                = "vm-${var.environment}-strongswan"
  location            = azurerm_resource_group.onprem.location
  resource_group_name = azurerm_resource_group.onprem.name
  size                = var.vm_size
  admin_username      = var.admin_username
  tags                = local.common_tags

  network_interface_ids = [
    azurerm_network_interface.strongswan.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key != "" ? var.ssh_public_key : file(var.ssh_public_key_path)
  }

  os_disk {
    name                 = "osdisk-strongswan"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Désactiver la configuration ici, Ansible prendra le relais
  custom_data = base64encode(templatefile("${path.module}/templates/cloud-init-base.yaml", {}))
}

###############################
# Azure VPN Gateway Side
###############################

resource "azurerm_resource_group" "azure" {
  name     = "rg-${var.environment}-azure-vpn"
  location = var.azure_location
  tags     = local.common_tags
}

# VNet Azure
resource "azurerm_virtual_network" "azure" {
  name                = "vnet-${var.environment}-azure"
  address_space       = [var.azure_address_space]
  location            = azurerm_resource_group.azure.location
  resource_group_name = azurerm_resource_group.azure.name
  tags                = local.common_tags
}

# Gateway Subnet
resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.azure.name
  virtual_network_name = azurerm_virtual_network.azure.name
  address_prefixes     = [var.azure_gateway_subnet_cidr]
}

# Subnet pour VMs de test
resource "azurerm_subnet" "azure_default" {
  name                 = "subnet-default"
  resource_group_name  = azurerm_resource_group.azure.name
  virtual_network_name = azurerm_virtual_network.azure.name
  address_prefixes     = [var.azure_default_subnet_cidr]
}

# Public IP pour VPN Gateway
resource "azurerm_public_ip" "vpn_gateway" {
  name                = "pip-${var.environment}-vpngw"
  location            = azurerm_resource_group.azure.location
  resource_group_name = azurerm_resource_group.azure.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

# VPN Gateway (prend 30-45 minutes à créer)
resource "azurerm_virtual_network_gateway" "vpn" {
  name                = "vpngw-${var.environment}-azure"
  location            = azurerm_resource_group.azure.location
  resource_group_name = azurerm_resource_group.azure.name
  tags                = local.common_tags

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = false
  sku           = var.vpn_gateway_sku

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }
}

# Local Network Gateway (représente le site on-premises)
resource "azurerm_local_network_gateway" "onprem" {
  name                = "lng-${var.environment}-onprem"
  location            = azurerm_resource_group.azure.location
  resource_group_name = azurerm_resource_group.azure.name
  gateway_address     = azurerm_public_ip.strongswan.ip_address
  address_space       = [var.onprem_address_space]
  tags                = local.common_tags
}

# VPN Connection S2S
resource "azurerm_virtual_network_gateway_connection" "s2s" {
  name                = "conn-${var.environment}-s2s-onprem"
  location            = azurerm_resource_group.azure.location
  resource_group_name = azurerm_resource_group.azure.name
  tags                = local.common_tags

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn.id
  local_network_gateway_id   = azurerm_local_network_gateway.onprem.id

  shared_key = var.ipsec_psk

  ipsec_policy {
    dh_group         = "DHGroup14"
    ike_encryption   = "AES256"
    ike_integrity    = "SHA256"
    ipsec_encryption = "AES256"
    ipsec_integrity  = "SHA256"
    pfs_group        = "None"
    sa_lifetime      = 3600
    sa_datasize      = 102400000
  }
}

###############################
# Génération de l'inventaire Ansible
###############################

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tpl", {
    strongswan_public_ip  = azurerm_public_ip.strongswan.ip_address
    strongswan_private_ip = azurerm_network_interface.strongswan.private_ip_address
    admin_username        = var.admin_username
    azure_vpn_public_ip   = azurerm_public_ip.vpn_gateway.ip_address
    azure_address_space   = var.azure_address_space
    onprem_address_space  = var.onprem_address_space
    ipsec_psk            = var.ipsec_psk
  })
  filename = "${path.module}/ansible/inventory.ini"
}

resource "local_file" "ansible_vars" {
  content = templatefile("${path.module}/templates/ansible_vars.tpl", {
    azure_vpn_public_ip  = azurerm_public_ip.vpn_gateway.ip_address
    azure_address_space  = var.azure_address_space
    onprem_address_space = var.onprem_address_space
    ipsec_psk           = var.ipsec_psk
  })
  filename = "${path.module}/ansible/group_vars/strongswan.yml"
}
