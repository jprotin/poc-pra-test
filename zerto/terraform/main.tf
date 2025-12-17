###############################################################################
# ZERTO DISASTER RECOVERY - CONFIGURATION PRINCIPALE VMware
###############################################################################
# Description: Configuration Terraform pour Zerto entre RBX et SBG
# Plateforme: OVHcloud Hosted Private Cloud (VMware vSphere)
# Architecture: Bi-directionnelle avec failover automatique
# Auteur: Infrastructure Team
# Date: 2025-12-17
###############################################################################

terraform {
  required_version = ">= 1.0"

  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.5"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}

###############################################################################
# PROVIDER CONFIGURATION - VMware vSphere
###############################################################################

# Provider vSphere pour RBX (Roubaix)
provider "vsphere" {
  alias = "rbx"

  user                 = var.vcenter_rbx_user
  password             = var.vcenter_rbx_password
  vsphere_server       = var.vcenter_rbx_server
  allow_unverified_ssl = true

  # Retry configuration pour connexions instables
  api_timeout          = 10
  vim_keep_alive       = 10
}

# Provider vSphere pour SBG (Strasbourg)
provider "vsphere" {
  alias = "sbg"

  user                 = var.vcenter_sbg_user
  password             = var.vcenter_sbg_password
  vsphere_server       = var.vcenter_sbg_server
  allow_unverified_ssl = true

  # Retry configuration pour connexions instables
  api_timeout          = 10
  vim_keep_alive       = 10
}

###############################################################################
# DATA SOURCES - RÉCUPÉRATION DES INFORMATIONS VMWARE
###############################################################################

# Datacenter RBX
data "vsphere_datacenter" "rbx" {
  provider = vsphere.rbx
  name     = var.vcenter_rbx_datacenter
}

# Datacenter SBG
data "vsphere_datacenter" "sbg" {
  provider = vsphere.sbg
  name     = var.vcenter_sbg_datacenter
}

# Cluster RBX
data "vsphere_compute_cluster" "rbx" {
  provider      = vsphere.rbx
  name          = var.vcenter_rbx_cluster
  datacenter_id = data.vsphere_datacenter.rbx.id
}

# Cluster SBG
data "vsphere_compute_cluster" "sbg" {
  provider      = vsphere.sbg
  name          = var.vcenter_sbg_cluster
  datacenter_id = data.vsphere_datacenter.sbg.id
}

# Récupération des VMs protégées dans RBX
data "vsphere_virtual_machine" "rbx_vms" {
  provider      = vsphere.rbx
  for_each      = { for vm in var.rbx_protected_vms : vm.name => vm }

  name          = each.value.vm_name_vcenter
  datacenter_id = data.vsphere_datacenter.rbx.id
}

# Récupération des VMs protégées dans SBG
data "vsphere_virtual_machine" "sbg_vms" {
  provider      = vsphere.sbg
  for_each      = { for vm in var.sbg_protected_vms : vm.name => vm }

  name          = each.value.vm_name_vcenter
  datacenter_id = data.vsphere_datacenter.sbg.id
}

# Réseau cible RBX
data "vsphere_network" "rbx_target" {
  provider      = vsphere.rbx
  name          = var.rbx_target_network_name
  datacenter_id = data.vsphere_datacenter.rbx.id
}

# Réseau cible SBG
data "vsphere_network" "sbg_target" {
  provider      = vsphere.sbg
  name          = var.sbg_target_network_name
  datacenter_id = data.vsphere_datacenter.sbg.id
}

# Datastore pour le journal Zerto RBX
data "vsphere_datastore" "rbx_journal" {
  provider      = vsphere.rbx
  name          = var.rbx_journal_datastore
  datacenter_id = data.vsphere_datacenter.rbx.id
}

# Datastore pour le journal Zerto SBG
data "vsphere_datastore" "sbg_journal" {
  provider      = vsphere.sbg
  name          = var.sbg_journal_datastore
  datacenter_id = data.vsphere_datacenter.sbg.id
}

###############################################################################
# MODULE ZERTO - PROTECTION RBX -> SBG
###############################################################################

module "zerto_rbx_to_sbg" {
  source = "./modules/zerto-vpg-vmware"

  # Identification
  vpg_name        = "VPG-RBX-to-SBG-${var.environment}"
  description     = "Protection des VMs RBX vers SBG - Application et Base de données"
  environment     = var.environment

  # Configuration source (RBX)
  source_site_name   = "RBX"
  source_site_id     = var.zerto_site_id_rbx
  source_vcenter     = var.vcenter_rbx_server
  source_datacenter  = var.vcenter_rbx_datacenter
  source_cluster     = var.vcenter_rbx_cluster

  # Configuration cible (SBG)
  target_site_name   = "SBG"
  target_site_id     = var.zerto_site_id_sbg
  target_vcenter     = var.vcenter_sbg_server
  target_datacenter  = var.vcenter_sbg_datacenter
  target_cluster     = var.vcenter_sbg_cluster

  # VMs à protéger (avec données vSphere)
  protected_vms = [
    for vm in var.rbx_protected_vms : {
      name           = vm.name
      vm_name_vcenter = vm.vm_name_vcenter
      vm_uuid        = data.vsphere_virtual_machine.rbx_vms[vm.name].id
      boot_order     = vm.boot_order
      failover_ip    = vm.failover_ip
      failover_subnet = vm.failover_subnet
      description    = vm.description
    }
  ]

  # Configuration RPO et retention
  rpo_seconds            = var.zerto_rpo_seconds
  journal_history_hours  = var.zerto_journal_hours
  test_interval_hours    = var.zerto_test_interval

  # Configuration réseau vSphere
  target_network_name      = var.sbg_target_network_name
  target_network_id        = data.vsphere_network.sbg_target.id
  target_datastore_name    = var.sbg_journal_datastore
  target_datastore_id      = data.vsphere_datastore.sbg_journal.id
  target_resource_pool_id  = data.vsphere_compute_cluster.sbg.resource_pool_id
  failover_network_config  = var.sbg_failover_network_config

  # Configuration Fortigate pour routage
  fortigate_config = {
    sbg_fortigate_ip        = var.sbg_fortigate_ip
    sbg_fortigate_vip_range = var.sbg_fortigate_vip_range
    bgp_peer_ip             = var.sbg_bgp_peer_ip
    bgp_as_number           = var.bgp_as_number
  }

  # Zerto API
  zerto_api_endpoint = var.zerto_api_endpoint
  zerto_api_token    = var.zerto_api_token

  # Tags et metadata
  tags = merge(
    var.common_tags,
    {
      "Direction"  = "RBX-to-SBG"
      "VPG"        = "rbx-to-sbg"
      "DR-Site"    = "SBG"
      "Primary"    = "RBX"
      "Platform"   = "VMware-vSphere"
    }
  )

  # Options avancées
  priority              = var.zerto_priority_high
  enable_compression    = var.zerto_enable_compression
  enable_encryption     = var.zerto_enable_encryption
  wan_acceleration      = var.zerto_wan_acceleration
}

###############################################################################
# MODULE ZERTO - PROTECTION SBG -> RBX
###############################################################################

module "zerto_sbg_to_rbx" {
  source = "./modules/zerto-vpg-vmware"

  # Identification
  vpg_name        = "VPG-SBG-to-RBX-${var.environment}"
  description     = "Protection des VMs SBG vers RBX - Application et Base de données"
  environment     = var.environment

  # Configuration source (SBG)
  source_site_name   = "SBG"
  source_site_id     = var.zerto_site_id_sbg
  source_vcenter     = var.vcenter_sbg_server
  source_datacenter  = var.vcenter_sbg_datacenter
  source_cluster     = var.vcenter_sbg_cluster

  # Configuration cible (RBX)
  target_site_name   = "RBX"
  target_site_id     = var.zerto_site_id_rbx
  target_vcenter     = var.vcenter_rbx_server
  target_datacenter  = var.vcenter_rbx_datacenter
  target_cluster     = var.vcenter_rbx_cluster

  # VMs à protéger (avec données vSphere)
  protected_vms = [
    for vm in var.sbg_protected_vms : {
      name           = vm.name
      vm_name_vcenter = vm.vm_name_vcenter
      vm_uuid        = data.vsphere_virtual_machine.sbg_vms[vm.name].id
      boot_order     = vm.boot_order
      failover_ip    = vm.failover_ip
      failover_subnet = vm.failover_subnet
      description    = vm.description
    }
  ]

  # Configuration RPO et retention
  rpo_seconds            = var.zerto_rpo_seconds
  journal_history_hours  = var.zerto_journal_hours
  test_interval_hours    = var.zerto_test_interval

  # Configuration réseau vSphere
  target_network_name      = var.rbx_target_network_name
  target_network_id        = data.vsphere_network.rbx_target.id
  target_datastore_name    = var.rbx_journal_datastore
  target_datastore_id      = data.vsphere_datastore.rbx_journal.id
  target_resource_pool_id  = data.vsphere_compute_cluster.rbx.resource_pool_id
  failover_network_config  = var.rbx_failover_network_config

  # Configuration Fortigate pour routage
  fortigate_config = {
    rbx_fortigate_ip        = var.rbx_fortigate_ip
    rbx_fortigate_vip_range = var.rbx_fortigate_vip_range
    bgp_peer_ip             = var.rbx_bgp_peer_ip
    bgp_as_number           = var.bgp_as_number
  }

  # Zerto API
  zerto_api_endpoint = var.zerto_api_endpoint
  zerto_api_token    = var.zerto_api_token

  # Tags et metadata
  tags = merge(
    var.common_tags,
    {
      "Direction"  = "SBG-to-RBX"
      "VPG"        = "sbg-to-rbx"
      "DR-Site"    = "RBX"
      "Primary"    = "SBG"
      "Platform"   = "VMware-vSphere"
    }
  )

  # Options avancées
  priority              = var.zerto_priority_high
  enable_compression    = var.zerto_enable_compression
  enable_encryption     = var.zerto_enable_encryption
  wan_acceleration      = var.zerto_wan_acceleration
}

###############################################################################
# MODULE ZERTO - CONFIGURATION RÉSEAU FORTIGATE
###############################################################################

module "zerto_fortigate_config" {
  source = "./modules/zerto-network"

  # Configuration RBX Fortigate
  rbx_fortigate = {
    ip_address          = var.rbx_fortigate_ip
    mgmt_port           = var.fortigate_mgmt_port
    api_key             = var.rbx_fortigate_api_key
    vip_range           = var.rbx_fortigate_vip_range
    internal_interface  = var.rbx_fortigate_internal_if
    external_interface  = var.rbx_fortigate_external_if
  }

  # Configuration SBG Fortigate
  sbg_fortigate = {
    ip_address          = var.sbg_fortigate_ip
    mgmt_port           = var.fortigate_mgmt_port
    api_key             = var.sbg_fortigate_api_key
    vip_range           = var.sbg_fortigate_vip_range
    internal_interface  = var.sbg_fortigate_internal_if
    external_interface  = var.sbg_fortigate_external_if
  }

  # Configuration BGP pour routage dynamique
  bgp_config = {
    as_number        = var.bgp_as_number
    rbx_router_id    = var.rbx_bgp_router_id
    sbg_router_id    = var.sbg_bgp_router_id
    rbx_networks     = var.rbx_bgp_networks
    sbg_networks     = var.sbg_bgp_networks
  }

  # Configuration des règles de firewall pour Zerto
  zerto_firewall_rules = {
    allow_zerto_replication = true
    zerto_ports            = ["9071-9073", "4007-4008"]
    source_ranges_rbx      = var.rbx_network_ranges
    source_ranges_sbg      = var.sbg_network_ranges
  }

  # Dépendances - Attendre que les VPGs soient créés
  depends_on = [
    module.zerto_rbx_to_sbg,
    module.zerto_sbg_to_rbx
  ]
}

###############################################################################
# MODULE ZERTO - MONITORING ET ALERTES
###############################################################################

module "zerto_monitoring" {
  source = "./modules/zerto-monitoring"

  # Configuration générale
  environment      = var.environment
  project_id       = "${var.vcenter_rbx_datacenter}-${var.vcenter_sbg_datacenter}"

  # VPGs à monitorer
  vpg_rbx_to_sbg_id = module.zerto_rbx_to_sbg.vpg_id
  vpg_sbg_to_rbx_id = module.zerto_sbg_to_rbx.vpg_id

  # Seuils d'alerte
  alert_thresholds = {
    rpo_warning_seconds  = var.zerto_rpo_seconds * 1.5
    rpo_critical_seconds = var.zerto_rpo_seconds * 2
    journal_usage_warning  = 70
    journal_usage_critical = 85
    bandwidth_warning_mbps = 800
    bandwidth_critical_mbps = 950
  }

  # Notifications
  notification_emails = var.alert_emails
  webhook_url        = var.alert_webhook_url

  # Métriques personnalisées
  enable_custom_metrics = true
  metrics_retention_days = 90
}
