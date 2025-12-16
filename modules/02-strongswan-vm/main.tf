# ==============================================================================
# Module Terraform : VM StrongSwan
# ==============================================================================
# Description : Ce module crée une VM Ubuntu avec StrongSwan pour simuler
#               un site on-premises et établir un tunnel IPsec S2S
# Auteur      : POC PRA
# Version     : 1.0
# ==============================================================================

# ------------------------------------------------------------------------------
# Resource Group pour le site "On-Premises" simulé
# ------------------------------------------------------------------------------
resource "azurerm_resource_group" "onprem" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ------------------------------------------------------------------------------
# Virtual Network On-Premises simulé
# ------------------------------------------------------------------------------
# Ce VNet simule le réseau d'un site distant (on-premises)
resource "azurerm_virtual_network" "onprem" {
  name                = var.vnet_name
  address_space       = [var.vnet_address_space]
  location            = azurerm_resource_group.onprem.location
  resource_group_name = azurerm_resource_group.onprem.name
  tags                = var.tags
}

# ------------------------------------------------------------------------------
# Subnet pour la VM StrongSwan
# ------------------------------------------------------------------------------
resource "azurerm_subnet" "onprem" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.onprem.name
  virtual_network_name = azurerm_virtual_network.onprem.name
  address_prefixes     = [var.subnet_cidr]
}

# ------------------------------------------------------------------------------
# Network Security Group
# ------------------------------------------------------------------------------
# NSG pour autoriser les flux IPsec (IKE, NAT-T, ESP) et SSH
resource "azurerm_network_security_group" "strongswan" {
  name                = var.nsg_name
  location            = azurerm_resource_group.onprem.location
  resource_group_name = azurerm_resource_group.onprem.name
  tags                = var.tags

  # Règle 1 : IKE (Internet Key Exchange) - UDP 500
  security_rule {
    name                       = "Allow-IKE"
    description                = "Autoriser IKE pour négociation IPsec"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "500"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Règle 2 : IPsec NAT-T (NAT Traversal) - UDP 4500
  security_rule {
    name                       = "Allow-IPsec-NAT-T"
    description                = "Autoriser IPsec NAT Traversal"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "4500"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Règle 3 : ESP (Encapsulating Security Payload) - Protocol 50
  security_rule {
    name                       = "Allow-ESP"
    description                = "Autoriser ESP pour transport IPsec"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Esp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Règle 4 : SSH pour administration
  # ⚠️  SÉCURITÉ : En production, restreindre source_address_prefix à votre IP
  security_rule {
    name                       = "Allow-SSH"
    description                = "Autoriser SSH pour administration"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.ssh_source_address_prefix
    destination_address_prefix = "*"
  }
}

# ------------------------------------------------------------------------------
# IP Publique pour la VM StrongSwan
# ------------------------------------------------------------------------------
resource "azurerm_public_ip" "strongswan" {
  name                = var.public_ip_name
  location            = azurerm_resource_group.onprem.location
  resource_group_name = azurerm_resource_group.onprem.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# ------------------------------------------------------------------------------
# Network Interface
# ------------------------------------------------------------------------------
resource "azurerm_network_interface" "strongswan" {
  name                = var.nic_name
  location            = azurerm_resource_group.onprem.location
  resource_group_name = azurerm_resource_group.onprem.name
  tags                = var.tags

  # Configuration IP
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.onprem.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.strongswan.id
  }

  # Activer l'IP forwarding pour permettre le routage IPsec
  enable_ip_forwarding = true
}

# ------------------------------------------------------------------------------
# Association NSG avec Network Interface
# ------------------------------------------------------------------------------
resource "azurerm_network_interface_security_group_association" "strongswan" {
  network_interface_id      = azurerm_network_interface.strongswan.id
  network_security_group_id = azurerm_network_security_group.strongswan.id
}

# ------------------------------------------------------------------------------
# VM Linux avec Ubuntu 22.04 LTS
# ------------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "strongswan" {
  name                = var.vm_name
  location            = azurerm_resource_group.onprem.location
  resource_group_name = azurerm_resource_group.onprem.name
  size                = var.vm_size
  admin_username      = var.admin_username
  tags                = var.tags

  # Désactiver le mot de passe, utiliser uniquement SSH key
  disable_password_authentication = true

  # Interface réseau
  network_interface_ids = [
    azurerm_network_interface.strongswan.id,
  ]

  # Configuration de la clé SSH
  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key != "" ? var.ssh_public_key : file(var.ssh_public_key_path)
  }

  # Disque système
  os_disk {
    name                 = "${var.vm_name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  # Image Ubuntu 22.04 LTS
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Cloud-init de base (installation minimale)
  # Ansible effectuera la configuration complète de StrongSwan
  custom_data = base64encode(templatefile("${path.module}/templates/cloud-init-base.yaml", {
    hostname = var.vm_name
  }))

  # Identité managée pour accès aux ressources Azure (optionnel)
  dynamic "identity" {
    for_each = var.enable_managed_identity ? [1] : []
    content {
      type = "SystemAssigned"
    }
  }
}
