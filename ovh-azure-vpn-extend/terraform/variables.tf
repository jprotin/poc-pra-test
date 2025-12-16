# variables.tf - Extension du VPN Gateway existant

variable "environment" {
  description = "Nom de l'environnement"
  type        = string
  default     = "prod"
}

###############################
# Infrastructure Azure Existante
###############################

variable "existing_resource_group_name" {
  description = "Nom du Resource Group contenant le VPN Gateway existant"
  type        = string
}

variable "existing_vpn_gateway_name" {
  description = "Nom du VPN Gateway existant"
  type        = string
}

variable "existing_vnet_name" {
  description = "Nom du VNet existant"
  type        = string
}

variable "existing_vnet_cidr" {
  description = "CIDR du VNet existant (ex: 192.168.0.0/16 ou 10.1.0.0/16)"
  type        = string
}

variable "existing_route_table_name" {
  description = "Nom de la route table existante (laisser vide si pas de route table)"
  type        = string
  default     = ""
}

###############################
# Configuration BGP - Azure (existant)
###############################

variable "azure_bgp_asn" {
  description = "ASN BGP du VPN Gateway Azure existant (vérifier avec: az network vnet-gateway show)"
  type        = number
  default     = 65515
}

variable "azure_bgp_apipa_primary" {
  description = "Adresse APIPA BGP primaire pour les nouveaux tunnels OVH"
  type        = string
  default     = "169.254.21.1"
}

variable "azure_bgp_apipa_secondary" {
  description = "Adresse APIPA BGP secondaire (pour Active-Active si applicable)"
  type        = string
  default     = "169.254.22.1"
}

variable "use_custom_bgp_addresses" {
  description = "Utiliser des adresses BGP personnalisées (APIPA)"
  type        = bool
  default     = true
}

###############################
# OVHcloud RBX Configuration (Primary)
###############################

variable "ovh_rbx_public_ip" {
  description = "Adresse IP publique du FortiGate RBX"
  type        = string
}

variable "ovh_rbx_network_cidr" {
  description = "CIDR du réseau OVHcloud RBX"
  type        = string
  default     = "192.168.10.0/24"
}

variable "rbx_bgp_asn" {
  description = "ASN BGP pour FortiGate RBX"
  type        = number
  default     = 65001
  
  validation {
    condition     = var.rbx_bgp_asn >= 64512 && var.rbx_bgp_asn <= 65534
    error_message = "L'ASN doit être un numéro privé entre 64512 et 65534."
  }
}

variable "rbx_bgp_peer_ip" {
  description = "Adresse IP BGP peer du FortiGate RBX (APIPA 169.254.21.x)"
  type        = string
  default     = "169.254.21.2"
}

variable "ipsec_psk_rbx" {
  description = "Pre-Shared Key IPsec pour tunnel RBX"
  type        = string
  sensitive   = true
}

###############################
# OVHcloud SBG Configuration (Backup)
###############################

variable "ovh_sbg_public_ip" {
  description = "Adresse IP publique du FortiGate SBG"
  type        = string
}

variable "ovh_sbg_network_cidr" {
  description = "CIDR du réseau OVHcloud SBG"
  type        = string
  default     = "192.168.20.0/24"
}

variable "sbg_bgp_asn" {
  description = "ASN BGP pour FortiGate SBG"
  type        = number
  default     = 65002
  
  validation {
    condition     = var.sbg_bgp_asn >= 64512 && var.sbg_bgp_asn <= 65534
    error_message = "L'ASN doit être un numéro privé entre 64512 et 65534."
  }
}

variable "sbg_bgp_peer_ip" {
  description = "Adresse IP BGP peer du FortiGate SBG (APIPA 169.254.22.x)"
  type        = string
  default     = "169.254.22.2"
}

variable "ipsec_psk_sbg" {
  description = "Pre-Shared Key IPsec pour tunnel SBG"
  type        = string
  sensitive   = true
}

###############################
# FortiGate Access Configuration
###############################

variable "fortigate_admin_username" {
  description = "Nom d'utilisateur admin FortiGate"
  type        = string
  default     = "admin"
}

variable "fortigate_admin_password" {
  description = "Mot de passe admin FortiGate"
  type        = string
  sensitive   = true
}

variable "fortigate_rbx_mgmt_ip" {
  description = "IP de management du FortiGate RBX"
  type        = string
}

variable "fortigate_sbg_mgmt_ip" {
  description = "IP de management du FortiGate SBG"
  type        = string
}

###############################
# BGP Route Priority Configuration
###############################

variable "rbx_local_preference" {
  description = "LOCAL_PREF pour les routes venant de RBX (plus élevé = préféré)"
  type        = number
  default     = 200
}

variable "sbg_local_preference" {
  description = "LOCAL_PREF pour les routes venant de SBG (plus bas = backup)"
  type        = number
  default     = 100
}

variable "rbx_as_path_prepend" {
  description = "Nombre de fois que l'ASN RBX est ajouté. 0 = route préférée"
  type        = number
  default     = 0
}

variable "sbg_as_path_prepend" {
  description = "Nombre de fois que l'ASN SBG est ajouté. Plus élevé = moins préféré"
  type        = number
  default     = 3
}

###############################
# Divers
###############################

variable "admin_username" {
  description = "Nom d'utilisateur pour SSH (si nécessaire)"
  type        = string
  default     = "azureuser"
}
