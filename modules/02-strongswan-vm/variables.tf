# ==============================================================================
# Variables du module : VM StrongSwan
# ==============================================================================

# ------------------------------------------------------------------------------
# Configuration du Resource Group
# ------------------------------------------------------------------------------

variable "resource_group_name" {
  description = "Nom du resource group pour le site on-premises simulé"
  type        = string
}

variable "location" {
  description = "Région Azure où déployer la VM (ex: francecentral, westeurope)"
  type        = string
  default     = "francecentral"
}

# ------------------------------------------------------------------------------
# Configuration du Virtual Network
# ------------------------------------------------------------------------------

variable "vnet_name" {
  description = "Nom du Virtual Network on-premises"
  type        = string
}

variable "vnet_address_space" {
  description = "Espace d'adressage CIDR du VNet on-premises (ex: 192.168.0.0/16)"
  type        = string
}

variable "subnet_name" {
  description = "Nom du subnet pour la VM StrongSwan"
  type        = string
  default     = "subnet-vpn"
}

variable "subnet_cidr" {
  description = "CIDR du subnet (doit être dans l'espace d'adressage du VNet)"
  type        = string
}

# ------------------------------------------------------------------------------
# Configuration du Network Security Group
# ------------------------------------------------------------------------------

variable "nsg_name" {
  description = "Nom du Network Security Group"
  type        = string
}

variable "ssh_source_address_prefix" {
  description = "Prefix d'adresse source autorisée pour SSH (utiliser votre IP pour plus de sécurité)"
  type        = string
  default     = "*"

  # ⚠️  AVERTISSEMENT : "*" autorise SSH depuis n'importe où
  # En production, utiliser une IP spécifique (ex: "1.2.3.4/32")
}

# ------------------------------------------------------------------------------
# Configuration de la VM
# ------------------------------------------------------------------------------

variable "vm_name" {
  description = "Nom de la VM StrongSwan"
  type        = string
}

variable "vm_size" {
  description = "Taille de la VM Azure (ex: Standard_B1s, Standard_B2s)"
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

# ------------------------------------------------------------------------------
# Configuration réseau
# ------------------------------------------------------------------------------

variable "public_ip_name" {
  description = "Nom de l'IP publique de la VM"
  type        = string
}

variable "nic_name" {
  description = "Nom de la Network Interface"
  type        = string
}

# ------------------------------------------------------------------------------
# Options avancées
# ------------------------------------------------------------------------------

variable "enable_managed_identity" {
  description = "Activer l'identité managée pour la VM"
  type        = bool
  default     = false
}

# ------------------------------------------------------------------------------
# Tags
# ------------------------------------------------------------------------------

variable "tags" {
  description = "Tags à appliquer aux ressources Azure"
  type        = map(string)
  default = {
    Project   = "POC-PRA"
    Component = "StrongSwan"
    ManagedBy = "Terraform"
  }
}
