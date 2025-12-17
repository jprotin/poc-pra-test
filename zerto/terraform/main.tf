###############################################################################
# ZERTO DISASTER RECOVERY - CONFIGURATION PRINCIPALE
###############################################################################
# Description: Configuration Terraform pour Zerto entre les régions RBX et SBG
# Architecture: Bi-directionnelle avec failover automatique
# Auteur: Infrastructure Team
# Date: 2025-12-17
###############################################################################

terraform {
  required_version = ">= 1.0"

  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = "~> 0.35"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}

###############################################################################
# PROVIDER CONFIGURATION
###############################################################################

# Provider OVHcloud principal
provider "ovh" {
  endpoint           = var.ovh_endpoint
  application_key    = var.ovh_application_key
  application_secret = var.ovh_application_secret
  consumer_key       = var.ovh_consumer_key
}

###############################################################################
# DATA SOURCES - RÉCUPÉRATION DES INFORMATIONS EXISTANTES
###############################################################################

# Récupération des informations du projet OVHcloud
data "ovh_cloud_project" "project" {
  service_name = var.ovh_project_id
}

# Liste des VMs existantes dans RBX pour protection
data "ovh_cloud_project_instances" "rbx_instances" {
  service_name = var.ovh_project_id
  region       = var.region_rbx
}

# Liste des VMs existantes dans SBG pour protection
data "ovh_cloud_project_instances" "sbg_instances" {
  service_name = var.ovh_project_id
  region       = var.region_sbg
}

###############################################################################
# MODULE ZERTO - PROTECTION RBX -> SBG
###############################################################################

module "zerto_rbx_to_sbg" {
  source = "./modules/zerto-vpg"

  # Identification
  vpg_name        = "VPG-RBX-to-SBG-${var.environment}"
  description     = "Protection des VMs RBX vers SBG - Application et Base de données"
  environment     = var.environment

  # Configuration source (RBX)
  source_region   = var.region_rbx
  source_site_id  = var.zerto_site_id_rbx

  # Configuration cible (SBG)
  target_region   = var.region_sbg
  target_site_id  = var.zerto_site_id_sbg

  # VMs à protéger
  protected_vms   = var.rbx_protected_vms

  # Configuration RPO et retention
  rpo_seconds     = var.zerto_rpo_seconds
  journal_history_hours = var.zerto_journal_hours
  test_interval_hours   = var.zerto_test_interval

  # Configuration réseau
  target_network_id     = var.sbg_target_network_id
  target_subnet_id      = var.sbg_target_subnet_id
  failover_network_config = var.sbg_failover_network_config

  # Configuration Fortigate pour routage
  fortigate_config = {
    sbg_fortigate_ip        = var.sbg_fortigate_ip
    sbg_fortigate_vip_range = var.sbg_fortigate_vip_range
    bgp_peer_ip             = var.sbg_bgp_peer_ip
    bgp_as_number           = var.bgp_as_number
  }

  # Tags et metadata
  tags = merge(
    var.common_tags,
    {
      "Direction"  = "RBX-to-SBG"
      "VPG"        = "rbx-to-sbg"
      "DR-Site"    = "SBG"
      "Primary"    = "RBX"
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
  source = "./modules/zerto-vpg"

  # Identification
  vpg_name        = "VPG-SBG-to-RBX-${var.environment}"
  description     = "Protection des VMs SBG vers RBX - Application et Base de données"
  environment     = var.environment

  # Configuration source (SBG)
  source_region   = var.region_sbg
  source_site_id  = var.zerto_site_id_sbg

  # Configuration cible (RBX)
  target_region   = var.region_rbx
  target_site_id  = var.zerto_site_id_rbx

  # VMs à protéger
  protected_vms   = var.sbg_protected_vms

  # Configuration RPO et retention
  rpo_seconds     = var.zerto_rpo_seconds
  journal_history_hours = var.zerto_journal_hours
  test_interval_hours   = var.zerto_test_interval

  # Configuration réseau
  target_network_id     = var.rbx_target_network_id
  target_subnet_id      = var.rbx_target_subnet_id
  failover_network_config = var.rbx_failover_network_config

  # Configuration Fortigate pour routage
  fortigate_config = {
    rbx_fortigate_ip        = var.rbx_fortigate_ip
    rbx_fortigate_vip_range = var.rbx_fortigate_vip_range
    bgp_peer_ip             = var.rbx_bgp_peer_ip
    bgp_as_number           = var.bgp_as_number
  }

  # Tags et metadata
  tags = merge(
    var.common_tags,
    {
      "Direction"  = "SBG-to-RBX"
      "VPG"        = "sbg-to-rbx"
      "DR-Site"    = "RBX"
      "Primary"    = "SBG"
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
  project_id       = var.ovh_project_id

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
