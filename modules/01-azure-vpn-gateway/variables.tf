# ==============================================================================
# Variables du module : Azure VPN Gateway
# ==============================================================================

# ------------------------------------------------------------------------------
# Configuration du Resource Group
# ------------------------------------------------------------------------------

variable "resource_group_name" {
  description = "Nom du resource group Azure qui contiendra le VPN Gateway"
  type        = string
}

variable "location" {
  description = "Région Azure où déployer les ressources (ex: francecentral, westeurope)"
  type        = string
  default     = "francecentral"
}

# ------------------------------------------------------------------------------
# Configuration du Virtual Network
# ------------------------------------------------------------------------------

variable "vnet_name" {
  description = "Nom du Virtual Network Azure"
  type        = string
}

variable "vnet_address_space" {
  description = "Espace d'adressage CIDR du Virtual Network (ex: 10.1.0.0/16)"
  type        = string
}

variable "gateway_subnet_cidr" {
  description = "CIDR du GatewaySubnet (doit être dans l'espace d'adressage du VNet)"
  type        = string
}

variable "default_subnet_name" {
  description = "Nom du subnet par défaut pour les VMs"
  type        = string
  default     = "subnet-default"
}

variable "default_subnet_cidr" {
  description = "CIDR du subnet par défaut"
  type        = string
}

# ------------------------------------------------------------------------------
# Configuration du VPN Gateway
# ------------------------------------------------------------------------------

variable "vpn_gateway_name" {
  description = "Nom du VPN Gateway"
  type        = string
}

variable "public_ip_name" {
  description = "Nom de l'IP publique du VPN Gateway"
  type        = string
}

variable "sku" {
  description = "SKU du VPN Gateway (VpnGw1, VpnGw2, VpnGw3, VpnGw4, VpnGw5)"
  type        = string
  default     = "VpnGw1"

  validation {
    condition     = contains(["VpnGw1", "VpnGw2", "VpnGw3", "VpnGw4", "VpnGw5"], var.sku)
    error_message = "Le SKU doit être VpnGw1, VpnGw2, VpnGw3, VpnGw4 ou VpnGw5."
  }
}

variable "active_active" {
  description = "Activer le mode Active-Active (nécessite 2 IPs publiques)"
  type        = bool
  default     = false
}

# ------------------------------------------------------------------------------
# Configuration BGP
# ------------------------------------------------------------------------------

variable "enable_bgp" {
  description = "Activer le BGP pour le routage dynamique"
  type        = bool
  default     = true
}

variable "bgp_asn" {
  description = "ASN (Autonomous System Number) pour le VPN Gateway Azure"
  type        = number
  default     = 65515

  validation {
    condition     = var.bgp_asn >= 64512 && var.bgp_asn <= 65534
    error_message = "L'ASN doit être dans la plage privée (64512-65534)."
  }
}

variable "bgp_peering_addresses" {
  description = "Configuration APIPA personnalisée pour le peering BGP"
  type = object({
    apipa_addresses = list(string)
  })
  default = null
}

# ------------------------------------------------------------------------------
# Tags
# ------------------------------------------------------------------------------

variable "tags" {
  description = "Tags à appliquer aux ressources Azure"
  type        = map(string)
  default = {
    Project   = "POC-PRA"
    ManagedBy = "Terraform"
  }
}
