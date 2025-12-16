# variables.tf

variable "environment" {
  description = "Nom de l'environnement (dev, test, prod)"
  type        = string
  default     = "dev"
}

variable "onprem_location" {
  description = "Localisation Azure pour le site on-premises simulé"
  type        = string
  default     = "francecentral"
}

variable "azure_location" {
  description = "Localisation Azure pour le VPN Gateway"
  type        = string
  default     = "francecentral"
}

variable "onprem_address_space" {
  description = "Espace d'adressage pour le VNet on-premises simulé"
  type        = string
  default     = "192.168.0.0/16"
}

variable "onprem_subnet_cidr" {
  description = "CIDR du subnet on-premises"
  type        = string
  default     = "192.168.1.0/24"
}

variable "azure_address_space" {
  description = "Espace d'adressage pour le VNet Azure"
  type        = string
  default     = "10.1.0.0/16"
}

variable "azure_gateway_subnet_cidr" {
  description = "CIDR du GatewaySubnet Azure"
  type        = string
  default     = "10.1.255.0/24"
}

variable "azure_default_subnet_cidr" {
  description = "CIDR du subnet par défaut Azure"
  type        = string
  default     = "10.1.1.0/24"
}

variable "vm_size" {
  description = "Taille de la VM StrongSwan"
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Nom d'utilisateur admin pour la VM"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "Clé SSH publique (contenu direct)"
  type        = string
  default     = ""
}

variable "ssh_public_key_path" {
  description = "Chemin vers la clé SSH publique"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ipsec_psk" {
  description = "Pre-Shared Key pour IPsec (doit être complexe et sécurisé)"
  type        = string
  sensitive   = true
}

variable "vpn_gateway_sku" {
  description = "SKU du VPN Gateway (VpnGw1, VpnGw2, VpnGw3)"
  type        = string
  default     = "VpnGw1"
  
  validation {
    condition     = contains(["VpnGw1", "VpnGw2", "VpnGw3", "VpnGw4", "VpnGw5"], var.vpn_gateway_sku)
    error_message = "Le SKU doit être VpnGw1, VpnGw2, VpnGw3, VpnGw4 ou VpnGw5."
  }
}
