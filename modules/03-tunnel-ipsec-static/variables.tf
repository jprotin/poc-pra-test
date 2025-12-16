# ==============================================================================
# Variables du module : Tunnel IPsec Statique
# ==============================================================================

# ------------------------------------------------------------------------------
# Configuration générale
# ------------------------------------------------------------------------------

variable "resource_group_name" {
  description = "Nom du resource group où créer les ressources"
  type        = string
}

variable "location" {
  description = "Région Azure"
  type        = string
}

# ------------------------------------------------------------------------------
# Configuration du Local Network Gateway
# ------------------------------------------------------------------------------

variable "local_network_gateway_name" {
  description = "Nom du Local Network Gateway"
  type        = string
}

variable "strongswan_public_ip" {
  description = "IP publique de la VM StrongSwan (endpoint distant)"
  type        = string
}

variable "onprem_address_space" {
  description = "Espace d'adressage du réseau on-premises"
  type        = string
}

# ------------------------------------------------------------------------------
# Configuration de la connexion VPN
# ------------------------------------------------------------------------------

variable "connection_name" {
  description = "Nom de la connexion VPN S2S"
  type        = string
}

variable "vpn_gateway_id" {
  description = "ID du VPN Gateway Azure"
  type        = string
}

variable "ipsec_psk" {
  description = "Pre-Shared Key pour IPsec (minimum 32 caractères recommandé)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.ipsec_psk) >= 8
    error_message = "Le PSK doit contenir au moins 8 caractères."
  }
}

variable "connection_protocol" {
  description = "Protocole de connexion (IKEv2 ou IKEv1)"
  type        = string
  default     = "IKEv2"

  validation {
    condition     = contains(["IKEv1", "IKEv2"], var.connection_protocol)
    error_message = "Le protocole doit être IKEv1 ou IKEv2."
  }
}

variable "connection_mode" {
  description = "Mode de connexion (Default, InitiatorOnly, ResponderOnly)"
  type        = string
  default     = "Default"

  validation {
    condition     = contains(["Default", "InitiatorOnly", "ResponderOnly"], var.connection_mode)
    error_message = "Le mode de connexion doit être Default, InitiatorOnly ou ResponderOnly."
  }
}

# ------------------------------------------------------------------------------
# Configuration BGP (optionnel pour tunnel statique)
# ------------------------------------------------------------------------------

variable "enable_bgp" {
  description = "Activer le BGP sur cette connexion"
  type        = bool
  default     = false
}

variable "bgp_asn" {
  description = "ASN du site on-premises (si BGP activé)"
  type        = number
  default     = null
}

variable "bgp_peering_address" {
  description = "Adresse de peering BGP du site on-premises (si BGP activé)"
  type        = string
  default     = null
}

# ------------------------------------------------------------------------------
# Politique IPsec
# ------------------------------------------------------------------------------

variable "ipsec_policy" {
  description = "Paramètres de la politique IPsec"
  type = object({
    dh_group         = string # DHGroup1, DHGroup2, DHGroup14, DHGroup24, ECP256, ECP384
    ike_encryption   = string # DES, DES3, AES128, AES192, AES256, GCMAES128, GCMAES256
    ike_integrity    = string # MD5, SHA1, SHA256, SHA384, GCMAES128, GCMAES256
    ipsec_encryption = string # DES, DES3, AES128, AES192, AES256, GCMAES128, GCMAES192, GCMAES256, None
    ipsec_integrity  = string # MD5, SHA1, SHA256, GCMAES128, GCMAES192, GCMAES256
    pfs_group        = string # None, PFS1, PFS2, PFS2048, ECP256, ECP384, PFS24, PFS14, PFSMM
    sa_lifetime      = number # Durée de vie en secondes (300-172799)
    sa_datasize      = number # Durée de vie en Ko (1024-2147483647)
  })

  # Valeurs par défaut recommandées (compatibles StrongSwan + Azure)
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
# Configuration DPD (Dead Peer Detection)
# ------------------------------------------------------------------------------

variable "dpd_timeout_seconds" {
  description = "Timeout DPD en secondes (9-3600)"
  type        = number
  default     = 45

  validation {
    condition     = var.dpd_timeout_seconds >= 9 && var.dpd_timeout_seconds <= 3600
    error_message = "Le timeout DPD doit être entre 9 et 3600 secondes."
  }
}

# ------------------------------------------------------------------------------
# Traffic Selector Policy (optionnel)
# ------------------------------------------------------------------------------

variable "traffic_selector_policies" {
  description = "Politiques de sélection de trafic (pour contrôler les réseaux autorisés)"
  type = list(object({
    local_address_cidrs  = list(string)
    remote_address_cidrs = list(string)
  }))
  default = []
}

# ------------------------------------------------------------------------------
# Tags
# ------------------------------------------------------------------------------

variable "tags" {
  description = "Tags à appliquer aux ressources"
  type        = map(string)
  default = {
    Project   = "POC-PRA"
    Component = "IPsec-Static"
    ManagedBy = "Terraform"
  }
}
