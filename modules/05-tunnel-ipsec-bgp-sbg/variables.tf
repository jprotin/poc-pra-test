# ==============================================================================
# Variables du module : Tunnel IPsec BGP SBG
# ==============================================================================

variable "resource_group_name" {
  description = "Nom du resource group"
  type        = string
}

variable "location" {
  description = "Région Azure"
  type        = string
}

variable "local_network_gateway_name" {
  description = "Nom du Local Network Gateway pour SBG"
  type        = string
}

variable "remote_gateway_ip" {
  description = "IP publique du FortiGate SBG"
  type        = string
}

variable "connection_name" {
  description = "Nom de la connexion VPN vers SBG"
  type        = string
}

variable "vpn_gateway_id" {
  description = "ID du VPN Gateway Azure"
  type        = string
}

variable "ipsec_psk" {
  description = "Pre-Shared Key pour le tunnel SBG"
  type        = string
  sensitive   = true
}

variable "connection_protocol" {
  description = "Protocole de connexion"
  type        = string
  default     = "IKEv2"
}

variable "enable_bgp" {
  description = "Activer BGP"
  type        = bool
  default     = true
}

variable "bgp_asn" {
  description = "ASN BGP pour SBG"
  type        = number
}

variable "bgp_peering_address" {
  description = "Adresse de peering BGP SBG"
  type        = string
}

variable "ipsec_policy" {
  description = "Politique IPsec"
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
}

variable "dpd_timeout_seconds" {
  description = "Timeout DPD en secondes"
  type        = number
  default     = 45
}

variable "tags" {
  description = "Tags à appliquer"
  type        = map(string)
  default     = {}
}
