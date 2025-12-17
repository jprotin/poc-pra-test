###############################################################################
# MODULE ZERTO NETWORK - CONFIGURATION RÉSEAU FORTIGATE
###############################################################################
# Description: Configuration réseau et Fortigate pour Zerto
# Gère: VIPs, routes BGP, firewall rules pour la réplication
###############################################################################

terraform {
  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}

###############################################################################
# LOCALS
###############################################################################

locals {
  # Configuration des règles firewall pour Zerto
  zerto_ports = var.zerto_firewall_rules.zerto_ports

  # Configuration BGP consolidée
  bgp_peers = {
    rbx_to_sbg = {
      local_router  = var.rbx_fortigate.ip_address
      peer_router   = var.sbg_fortigate.ip_address
      local_as      = var.bgp_config.as_number
      remote_as     = var.bgp_config.as_number
      networks      = var.bgp_config.rbx_networks
    }
    sbg_to_rbx = {
      local_router  = var.sbg_fortigate.ip_address
      peer_router   = var.rbx_fortigate.ip_address
      local_as      = var.bgp_config.as_number
      remote_as     = var.bgp_config.as_number
      networks      = var.bgp_config.sbg_networks
    }
  }
}

###############################################################################
# CONFIGURATION FORTIGATE RBX
###############################################################################

# Création des VIPs pour Zerto sur RBX
resource "null_resource" "rbx_fortigate_vips" {
  triggers = {
    fortigate_ip = var.rbx_fortigate.ip_address
    vip_range    = var.rbx_fortigate.vip_range
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/configure-fortigate-vips.sh"

    environment = {
      FORTIGATE_IP   = var.rbx_fortigate.ip_address
      FORTIGATE_PORT = var.rbx_fortigate.mgmt_port
      API_KEY        = var.rbx_fortigate.api_key
      VIP_RANGE      = var.rbx_fortigate.vip_range
      SITE           = "RBX"
    }
  }
}

# Configuration BGP sur Fortigate RBX
resource "null_resource" "rbx_fortigate_bgp" {
  triggers = {
    router_id   = var.bgp_config.rbx_router_id
    as_number   = var.bgp_config.as_number
    peer_ip     = var.sbg_fortigate.ip_address
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/configure-fortigate-bgp.sh"

    environment = {
      FORTIGATE_IP   = var.rbx_fortigate.ip_address
      FORTIGATE_PORT = var.rbx_fortigate.mgmt_port
      API_KEY        = var.rbx_fortigate.api_key
      ROUTER_ID      = var.bgp_config.rbx_router_id
      AS_NUMBER      = tostring(var.bgp_config.as_number)
      PEER_IP        = var.sbg_fortigate.ip_address
      NETWORKS_JSON  = jsonencode(var.bgp_config.rbx_networks)
      SITE           = "RBX"
    }
  }

  depends_on = [null_resource.rbx_fortigate_vips]
}

# Règles firewall pour Zerto sur RBX
resource "null_resource" "rbx_fortigate_firewall" {
  triggers = {
    zerto_ports = join(",", local.zerto_ports)
    source_ranges = join(",", var.zerto_firewall_rules.source_ranges_sbg)
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/configure-fortigate-firewall.sh"

    environment = {
      FORTIGATE_IP     = var.rbx_fortigate.ip_address
      FORTIGATE_PORT   = var.rbx_fortigate.mgmt_port
      API_KEY          = var.rbx_fortigate.api_key
      ZERTO_PORTS      = join(",", local.zerto_ports)
      SOURCE_RANGES    = join(",", var.zerto_firewall_rules.source_ranges_sbg)
      INTERNAL_IF      = var.rbx_fortigate.internal_interface
      EXTERNAL_IF      = var.rbx_fortigate.external_interface
      SITE             = "RBX"
    }
  }

  depends_on = [null_resource.rbx_fortigate_bgp]
}

###############################################################################
# CONFIGURATION FORTIGATE SBG
###############################################################################

# Création des VIPs pour Zerto sur SBG
resource "null_resource" "sbg_fortigate_vips" {
  triggers = {
    fortigate_ip = var.sbg_fortigate.ip_address
    vip_range    = var.sbg_fortigate.vip_range
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/configure-fortigate-vips.sh"

    environment = {
      FORTIGATE_IP   = var.sbg_fortigate.ip_address
      FORTIGATE_PORT = var.sbg_fortigate.mgmt_port
      API_KEY        = var.sbg_fortigate.api_key
      VIP_RANGE      = var.sbg_fortigate.vip_range
      SITE           = "SBG"
    }
  }
}

# Configuration BGP sur Fortigate SBG
resource "null_resource" "sbg_fortigate_bgp" {
  triggers = {
    router_id   = var.bgp_config.sbg_router_id
    as_number   = var.bgp_config.as_number
    peer_ip     = var.rbx_fortigate.ip_address
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/configure-fortigate-bgp.sh"

    environment = {
      FORTIGATE_IP   = var.sbg_fortigate.ip_address
      FORTIGATE_PORT = var.sbg_fortigate.mgmt_port
      API_KEY        = var.sbg_fortigate.api_key
      ROUTER_ID      = var.bgp_config.sbg_router_id
      AS_NUMBER      = tostring(var.bgp_config.as_number)
      PEER_IP        = var.rbx_fortigate.ip_address
      NETWORKS_JSON  = jsonencode(var.bgp_config.sbg_networks)
      SITE           = "SBG"
    }
  }

  depends_on = [null_resource.sbg_fortigate_vips]
}

# Règles firewall pour Zerto sur SBG
resource "null_resource" "sbg_fortigate_firewall" {
  triggers = {
    zerto_ports = join(",", local.zerto_ports)
    source_ranges = join(",", var.zerto_firewall_rules.source_ranges_rbx)
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/configure-fortigate-firewall.sh"

    environment = {
      FORTIGATE_IP     = var.sbg_fortigate.ip_address
      FORTIGATE_PORT   = var.sbg_fortigate.mgmt_port
      API_KEY          = var.sbg_fortigate.api_key
      ZERTO_PORTS      = join(",", local.zerto_ports)
      SOURCE_RANGES    = join(",", var.zerto_firewall_rules.source_ranges_rbx)
      INTERNAL_IF      = var.sbg_fortigate.internal_interface
      EXTERNAL_IF      = var.sbg_fortigate.external_interface
      SITE             = "SBG"
    }
  }

  depends_on = [null_resource.sbg_fortigate_bgp]
}

###############################################################################
# VÉRIFICATION DU PEERING BGP
###############################################################################

resource "null_resource" "verify_bgp_peering" {
  triggers = {
    rbx_config = null_resource.rbx_fortigate_bgp.id
    sbg_config = null_resource.sbg_fortigate_bgp.id
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/verify-bgp-peering.sh"

    environment = {
      RBX_FORTIGATE_IP = var.rbx_fortigate.ip_address
      RBX_API_KEY      = var.rbx_fortigate.api_key
      SBG_FORTIGATE_IP = var.sbg_fortigate.ip_address
      SBG_API_KEY      = var.sbg_fortigate.api_key
    }
  }

  depends_on = [
    null_resource.rbx_fortigate_firewall,
    null_resource.sbg_fortigate_firewall
  ]
}
