###############################################################################
# MODULE ZERTO NETWORK - CONFIGURATION RÉSEAU FORTIGATE
###############################################################################
# Description: Configuration réseau et Fortigate pour Zerto
# Gère: VIPs et firewall rules pour la réplication Zerto
# Note: Le BGP vers Azure est géré séparément (voir modules/04-tunnel-ipsec-bgp-*)
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

# Règles firewall pour Zerto sur RBX
resource "null_resource" "rbx_fortigate_firewall" {
  triggers = {
    zerto_ports   = join(",", local.zerto_ports)
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

  depends_on = [null_resource.rbx_fortigate_vips]
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

# Règles firewall pour Zerto sur SBG
resource "null_resource" "sbg_fortigate_firewall" {
  triggers = {
    zerto_ports   = join(",", local.zerto_ports)
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

  depends_on = [null_resource.sbg_fortigate_vips]
}

###############################################################################
# ROUTES STATIQUES POUR VMs FAILOVÉES (Désactivées par défaut)
###############################################################################
# Note: Ces routes sont activées dynamiquement par les scripts de failover
# Ne pas décommenter sans avoir effectué un failover !

# Routes sur SBG pour VMs failovées depuis RBX (activées au failover)
# resource "null_resource" "sbg_static_routes_rbx_vms" {
#   triggers = {
#     fortigate_ip = var.sbg_fortigate.ip_address
#   }
#
#   provisioner "local-exec" {
#     command = "${path.module}/scripts/configure-static-routes.sh"
#
#     environment = {
#       FORTIGATE_IP   = var.sbg_fortigate.ip_address
#       API_KEY        = var.sbg_fortigate.api_key
#       ROUTES_JSON    = jsonencode([
#         { dest = "10.1.1.10/32", gateway = "local", interface = "internal" },
#         { dest = "10.1.1.20/32", gateway = "local", interface = "internal" }
#       ])
#       SITE           = "SBG"
#       SOURCE_SITE    = "RBX"
#     }
#   }
# }

# Routes sur RBX pour VMs failovées depuis SBG (activées au failover)
# resource "null_resource" "rbx_static_routes_sbg_vms" {
#   triggers = {
#     fortigate_ip = var.rbx_fortigate.ip_address
#   }
#
#   provisioner "local-exec" {
#     command = "${path.module}/scripts/configure-static-routes.sh"
#
#     environment = {
#       FORTIGATE_IP   = var.rbx_fortigate.ip_address
#       API_KEY        = var.rbx_fortigate.api_key
#       ROUTES_JSON    = jsonencode([
#         { dest = "10.2.1.10/32", gateway = "local", interface = "internal" },
#         { dest = "10.2.1.20/32", gateway = "local", interface = "internal" }
#       ])
#       SITE           = "RBX"
#       SOURCE_SITE    = "SBG"
#     }
#   }
# }
