###############################################################################
# MODULE ZERTO NETWORK - VARIABLES
###############################################################################

variable "rbx_fortigate" {
  description = "Configuration du Fortigate RBX"
  type = object({
    ip_address         = string
    mgmt_port          = number
    api_key            = string
    vip_range          = string
    internal_interface = string
    external_interface = string
  })
  sensitive = true
}

variable "sbg_fortigate" {
  description = "Configuration du Fortigate SBG"
  type = object({
    ip_address         = string
    mgmt_port          = number
    api_key            = string
    vip_range          = string
    internal_interface = string
    external_interface = string
  })
  sensitive = true
}

variable "bgp_config" {
  description = "Configuration BGP pour routage dynamique"
  type = object({
    as_number      = number
    rbx_router_id  = string
    sbg_router_id  = string
    rbx_networks   = list(string)
    sbg_networks   = list(string)
  })
}

variable "zerto_firewall_rules" {
  description = "Configuration des règles firewall pour Zerto"
  type = object({
    allow_zerto_replication = bool
    zerto_ports             = list(string)
    source_ranges_rbx       = list(string)
    source_ranges_sbg       = list(string)
  })

  default = {
    allow_zerto_replication = true
    zerto_ports             = ["9071-9073", "4007-4008"]
    source_ranges_rbx       = ["10.1.0.0/16"]
    source_ranges_sbg       = ["10.2.0.0/16"]
  }
}
