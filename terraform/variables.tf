# ==============================================================================
# Variables Globales - POC PRA
# ==============================================================================

# ------------------------------------------------------------------------------
# Configuration Générale
# ------------------------------------------------------------------------------

variable "environment" {
  description = "Nom de l'environnement (dev, test, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "staging", "prod"], var.environment)
    error_message = "L'environnement doit être dev, test, staging ou prod."
  }
}

variable "project_name" {
  description = "Nom du projet (utilisé dans les noms de ressources)"
  type        = string
  default     = "pra"
}

variable "owner" {
  description = "Propriétaire du projet (email ou nom)"
  type        = string
  default     = "poc-pra-team"
}

# ------------------------------------------------------------------------------
# Configuration Azure - Hub
# ------------------------------------------------------------------------------

variable "azure_location" {
  description = "Région Azure pour le VPN Gateway"
  type        = string
  default     = "francecentral"
}

variable "azure_vnet_cidr" {
  description = "CIDR du Virtual Network Azure"
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

variable "vpn_gateway_sku" {
  description = "SKU du VPN Gateway Azure"
  type        = string
  default     = "VpnGw1"
}

variable "vpn_gateway_active_active" {
  description = "Activer le mode Active-Active sur le VPN Gateway"
  type        = bool
  default     = false
}

variable "enable_bgp" {
  description = "Activer le BGP sur le VPN Gateway"
  type        = bool
  default     = true
}

variable "azure_bgp_asn" {
  description = "ASN BGP pour le VPN Gateway Azure"
  type        = number
  default     = 65515
}

# ------------------------------------------------------------------------------
# Configuration On-Premises (StrongSwan)
# ------------------------------------------------------------------------------

variable "deploy_strongswan" {
  description = "Déployer la VM StrongSwan et le tunnel statique"
  type        = bool
  default     = true
}

variable "onprem_location" {
  description = "Région Azure pour la VM on-premises simulée"
  type        = string
  default     = "francecentral"
}

variable "onprem_vnet_cidr" {
  description = "CIDR du réseau on-premises simulé"
  type        = string
  default     = "192.168.0.0/16"
}

variable "onprem_subnet_cidr" {
  description = "CIDR du subnet on-premises"
  type        = string
  default     = "192.168.1.0/24"
}

variable "strongswan_vm_size" {
  description = "Taille de la VM StrongSwan"
  type        = string
  default     = "Standard_B1s"
}

variable "ipsec_psk_strongswan" {
  description = "Pre-Shared Key pour le tunnel IPsec StrongSwan"
  type        = string
  sensitive   = true
}

variable "ipsec_policy_strongswan" {
  description = "Politique IPsec pour le tunnel StrongSwan"
  type = object({
    dh_group         = string
    ike_encryption   = string
    ike_integrity    = string
    ipsec_encryption = string
    ipsec_integrity  = string
    pfs_group        = string
    sa_lifetime      = number
    sa_datasize      = number
  })
  default = {
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

# ------------------------------------------------------------------------------
# Configuration OVHCloud RBX (Primary)
# ------------------------------------------------------------------------------

variable "deploy_ovh_rbx" {
  description = "Déployer le tunnel vers OVHCloud RBX"
  type        = bool
  default     = false
}

variable "ovh_rbx_public_ip" {
  description = "IP publique du FortiGate RBX"
  type        = string
  default     = ""
}

variable "ovh_rbx_mgmt_ip" {
  description = "IP de management du FortiGate RBX"
  type        = string
  default     = ""
}

variable "ovh_rbx_bgp_asn" {
  description = "ASN BGP pour OVHCloud RBX"
  type        = number
  default     = 65001
}

variable "ovh_rbx_bgp_peer_ip" {
  description = "Adresse IP de peering BGP pour RBX"
  type        = string
  default     = "169.254.30.2"
}

variable "ipsec_psk_rbx" {
  description = "Pre-Shared Key pour le tunnel IPsec RBX"
  type        = string
  sensitive   = true
  default     = ""
}

# ------------------------------------------------------------------------------
# Configuration OVHCloud SBG (Backup)
# ------------------------------------------------------------------------------

variable "deploy_ovh_sbg" {
  description = "Déployer le tunnel vers OVHCloud SBG"
  type        = bool
  default     = false
}

variable "ovh_sbg_public_ip" {
  description = "IP publique du FortiGate SBG"
  type        = string
  default     = ""
}

variable "ovh_sbg_mgmt_ip" {
  description = "IP de management du FortiGate SBG"
  type        = string
  default     = ""
}

variable "ovh_sbg_bgp_asn" {
  description = "ASN BGP pour OVHCloud SBG"
  type        = number
  default     = 65002
}

variable "ovh_sbg_bgp_peer_ip" {
  description = "Adresse IP de peering BGP pour SBG"
  type        = string
  default     = "169.254.31.2"
}

variable "ipsec_psk_sbg" {
  description = "Pre-Shared Key pour le tunnel IPsec SBG"
  type        = string
  sensitive   = true
  default     = ""
}

# ------------------------------------------------------------------------------
# Politique IPsec pour FortiGate (RBX et SBG)
# ------------------------------------------------------------------------------

variable "ipsec_policy_fortigate" {
  description = "Politique IPsec pour les tunnels FortiGate"
  type = object({
    dh_group         = string
    ike_encryption   = string
    ike_integrity    = string
    ipsec_encryption = string
    ipsec_integrity  = string
    pfs_group        = string
    sa_lifetime      = number
    sa_datasize      = number
  })
  default = {
    dh_group         = "DHGroup14"
    ike_encryption   = "AES256"
    ike_integrity    = "SHA256"
    ipsec_encryption = "AES256"
    ipsec_integrity  = "SHA256"
    pfs_group        = "PFS2048"
    sa_lifetime      = 27000
    sa_datasize      = 102400000
  }
}

# ------------------------------------------------------------------------------
# Configuration SSH
# ------------------------------------------------------------------------------

variable "admin_username" {
  description = "Nom d'utilisateur admin pour les VMs"
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

variable "ssh_source_address_prefix" {
  description = "Préfixe d'adresse source autorisée pour SSH"
  type        = string
  default     = "*"
  # ⚠️  SÉCURITÉ : En production, utiliser votre IP (ex: "1.2.3.4/32")
}

# ------------------------------------------------------------------------------
# Configuration Infrastructure OVHCloud VMware (optionnel)
# ------------------------------------------------------------------------------

variable "deploy_ovh_infrastructure" {
  description = "Déployer l'infrastructure VMware sur OVHCloud"
  type        = bool
  default     = false
}
