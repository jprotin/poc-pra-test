# ==============================================================================
# Module Terraform : FortiGate Firewall Rules
# ==============================================================================
# Description : Configuration automatisée des règles firewall FortiGate
#               pour l'infrastructure applicative OVH
# Note        : Nécessite le provider FortiOS configuré avec API token
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    fortios = {
      source  = "fortinetdev/fortios"
      version = "~> 1.19"
    }
  }
}

# ==============================================================================
# CONFIGURATION FORTIGATE RBX
# ==============================================================================

# ------------------------------------------------------------------------------
# Address Objects RBX
# ------------------------------------------------------------------------------

# Objet pour VM Docker RBX
resource "fortios_firewall_address" "rbx_docker_vm" {
  provider = fortios.rbx

  name       = "VM-DOCKER-APP-A-RBX"
  type       = "ipmask"
  subnet     = "${var.vm_docker_rbx_ip}/32"
  comment    = "VM Docker Application A - RBX"
  visibility = "enable"
}

# Objet pour VM MySQL RBX
resource "fortios_firewall_address" "rbx_mysql_vm" {
  provider = fortios.rbx

  name       = "VM-MYSQL-APP-A-RBX"
  type       = "ipmask"
  subnet     = "${var.vm_mysql_rbx_ip}/32"
  comment    = "VM MySQL Application A - RBX"
  visibility = "enable"
}

# Objet pour réseau SBG (pour inter-DC)
resource "fortios_firewall_address" "rbx_sbg_network" {
  provider = fortios.rbx

  name       = "NET-SBG-PRIVATE"
  type       = "ipmask"
  subnet     = var.sbg_network_cidr
  comment    = "Réseau privé SBG"
  visibility = "enable"
}

# ------------------------------------------------------------------------------
# Service Objects RBX
# ------------------------------------------------------------------------------

# Service MySQL (port 3306)
resource "fortios_firewallservice_custom" "mysql" {
  provider = fortios.rbx

  name     = "MySQL-3306"
  protocol = "TCP"
  tcp_portrange = "3306"
  comment  = "MySQL Database Service"
}

# Service HTTP/HTTPS (pour applications Docker)
resource "fortios_firewallservice_custom" "http_https" {
  provider = fortios.rbx

  name     = "HTTP-HTTPS"
  protocol = "TCP"
  tcp_portrange = "80 443"
  comment  = "HTTP and HTTPS Services"
}

# Service Zerto Replication
resource "fortios_firewallservice_custom" "zerto_replication" {
  provider = fortios.rbx

  name     = "Zerto-Replication"
  protocol = "TCP"
  tcp_portrange = "4007-4008"
  comment  = "Zerto Virtual Replication Ports"
}

# ------------------------------------------------------------------------------
# Firewall Policies RBX
# ------------------------------------------------------------------------------

# Politique 100 : VM Docker RBX → MySQL RBX (port 3306)
resource "fortios_firewall_policy" "rbx_docker_to_mysql" {
  provider = fortios.rbx

  policyid = 100
  name     = "Allow_Docker_to_MySQL_RBX"

  srcintf {
    name = var.fortigate_rbx_internal_interface
  }

  dstintf {
    name = var.fortigate_rbx_internal_interface
  }

  srcaddr {
    name = fortios_firewall_address.rbx_docker_vm.name
  }

  dstaddr {
    name = fortios_firewall_address.rbx_mysql_vm.name
  }

  service {
    name = fortios_firewallservice_custom.mysql.name
  }

  action   = "accept"
  schedule = "always"
  logtraffic = var.enable_logging ? "all" : "disable"
  comments = "Autoriser connexion Docker vers MySQL sur RBX"
}

# Politique 101 : NAT/VIP pour VM Docker RBX vers Internet
resource "fortios_firewall_policy" "rbx_docker_nat" {
  count    = var.enable_nat_docker_rbx ? 1 : 0
  provider = fortios.rbx

  policyid = 101
  name     = "NAT_Docker_RBX_to_Internet"

  srcintf {
    name = var.fortigate_rbx_internal_interface
  }

  dstintf {
    name = var.fortigate_rbx_external_interface
  }

  srcaddr {
    name = fortios_firewall_address.rbx_docker_vm.name
  }

  dstaddr {
    name = "all"
  }

  service {
    name = "ALL"
  }

  action     = "accept"
  schedule   = "always"
  nat        = "enable"
  logtraffic = var.enable_logging ? "all" : "disable"
  comments   = "SNAT Docker RBX vers Internet"
}

# Politique 102 : Trafic Zerto RBX → SBG
resource "fortios_firewall_policy" "rbx_zerto_to_sbg" {
  provider = fortios.rbx

  policyid = 102
  name     = "Allow_Zerto_RBX_to_SBG"

  srcintf {
    name = var.fortigate_rbx_internal_interface
  }

  dstintf {
    name = var.fortigate_rbx_external_interface
  }

  srcaddr {
    name = "all" # Ou créer un objet spécifique pour les VMs RBX
  }

  dstaddr {
    name = fortios_firewall_address.rbx_sbg_network.name
  }

  service {
    name = fortios_firewallservice_custom.zerto_replication.name
  }

  action     = "accept"
  schedule   = "always"
  logtraffic = var.enable_logging ? "all" : "disable"
  comments   = "Autoriser réplication Zerto RBX vers SBG"
}

# ==============================================================================
# CONFIGURATION FORTIGATE SBG
# ==============================================================================

# ------------------------------------------------------------------------------
# Address Objects SBG
# ------------------------------------------------------------------------------

# Objet pour VM Docker SBG
resource "fortios_firewall_address" "sbg_docker_vm" {
  provider = fortios.sbg

  name       = "VM-DOCKER-APP-B-SBG"
  type       = "ipmask"
  subnet     = "${var.vm_docker_sbg_ip}/32"
  comment    = "VM Docker Application B - SBG"
  visibility = "enable"
}

# Objet pour VM MySQL SBG
resource "fortios_firewall_address" "sbg_mysql_vm" {
  provider = fortios.sbg

  name       = "VM-MYSQL-APP-B-SBG"
  type       = "ipmask"
  subnet     = "${var.vm_mysql_sbg_ip}/32"
  comment    = "VM MySQL Application B - SBG"
  visibility = "enable"
}

# Objet pour réseau RBX (pour inter-DC)
resource "fortios_firewall_address" "sbg_rbx_network" {
  provider = fortios.sbg

  name       = "NET-RBX-PRIVATE"
  type       = "ipmask"
  subnet     = var.rbx_network_cidr
  comment    = "Réseau privé RBX"
  visibility = "enable"
}

# ------------------------------------------------------------------------------
# Service Objects SBG (réutilisation des mêmes services)
# ------------------------------------------------------------------------------

resource "fortios_firewallservice_custom" "sbg_mysql" {
  provider = fortios.sbg

  name     = "MySQL-3306"
  protocol = "TCP"
  tcp_portrange = "3306"
  comment  = "MySQL Database Service"
}

resource "fortios_firewallservice_custom" "sbg_zerto_replication" {
  provider = fortios.sbg

  name     = "Zerto-Replication"
  protocol = "TCP"
  tcp_portrange = "4007-4008"
  comment  = "Zerto Virtual Replication Ports"
}

# ------------------------------------------------------------------------------
# Firewall Policies SBG
# ------------------------------------------------------------------------------

# Politique 200 : VM Docker SBG → MySQL SBG (port 3306)
resource "fortios_firewall_policy" "sbg_docker_to_mysql" {
  provider = fortios.sbg

  policyid = 200
  name     = "Allow_Docker_to_MySQL_SBG"

  srcintf {
    name = var.fortigate_sbg_internal_interface
  }

  dstintf {
    name = var.fortigate_sbg_internal_interface
  }

  srcaddr {
    name = fortios_firewall_address.sbg_docker_vm.name
  }

  dstaddr {
    name = fortios_firewall_address.sbg_mysql_vm.name
  }

  service {
    name = fortios_firewallservice_custom.sbg_mysql.name
  }

  action     = "accept"
  schedule   = "always"
  logtraffic = var.enable_logging ? "all" : "disable"
  comments   = "Autoriser connexion Docker vers MySQL sur SBG"
}

# Politique 201 : NAT/VIP pour VM Docker SBG vers Internet
resource "fortios_firewall_policy" "sbg_docker_nat" {
  count    = var.enable_nat_docker_sbg ? 1 : 0
  provider = fortios.sbg

  policyid = 201
  name     = "NAT_Docker_SBG_to_Internet"

  srcintf {
    name = var.fortigate_sbg_internal_interface
  }

  dstintf {
    name = var.fortigate_sbg_external_interface
  }

  srcaddr {
    name = fortios_firewall_address.sbg_docker_vm.name
  }

  dstaddr {
    name = "all"
  }

  service {
    name = "ALL"
  }

  action     = "accept"
  schedule   = "always"
  nat        = "enable"
  logtraffic = var.enable_logging ? "all" : "disable"
  comments   = "SNAT Docker SBG vers Internet"
}

# Politique 202 : Trafic Zerto SBG → RBX
resource "fortios_firewall_policy" "sbg_zerto_to_rbx" {
  provider = fortios.sbg

  policyid = 202
  name     = "Allow_Zerto_SBG_to_RBX"

  srcintf {
    name = var.fortigate_sbg_internal_interface
  }

  dstintf {
    name = var.fortigate_sbg_external_interface
  }

  srcaddr {
    name = "all"
  }

  dstaddr {
    name = fortios_firewall_address.sbg_rbx_network.name
  }

  service {
    name = fortios_firewallservice_custom.sbg_zerto_replication.name
  }

  action     = "accept"
  schedule   = "always"
  logtraffic = var.enable_logging ? "all" : "disable"
  comments   = "Autoriser réplication Zerto SBG vers RBX"
}
