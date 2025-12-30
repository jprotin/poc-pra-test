# ==============================================================================
# Module Terraform : OVH Network Configuration
# ==============================================================================
# Description : Configuration des port groups vSphere pour vRack OVH
# Note        : Le vRack OVH doit être pré-configuré manuellement via l'interface
#               OVH Manager. Ce module configure uniquement les port groups vSphere.
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.6"
    }
  }
}

# ------------------------------------------------------------------------------
# Data Sources - vSphere RBX
# ------------------------------------------------------------------------------

data "vsphere_datacenter" "rbx" {
  name = var.vsphere_rbx_datacenter
}

# Note: Les Distributed Switches doivent être créés manuellement dans vCenter
# ou via l'API OVH Private Cloud avant d'utiliser ce module
# Référence: https://docs.ovh.com/fr/private-cloud/

# ------------------------------------------------------------------------------
# Port Groups vSphere - RBX
# ------------------------------------------------------------------------------

# Port Group pour VLAN 100 (Réseau privé RBX)
resource "vsphere_distributed_port_group" "rbx_private" {
  provider = vsphere.rbx

  name                            = "VLAN-${var.vrack_vlan_rbx_id}-RBX-Private"
  distributed_virtual_switch_uuid = data.vsphere_distributed_virtual_switch.rbx.id

  vlan_id = var.vrack_vlan_rbx_id

  # Politique de sécurité (désactiver promiscuous mode pour sécurité)
  security_policy_override_allowed = true
  allow_promiscuous                = false
  allow_forged_transmits           = false
  allow_mac_changes                = false

  # Politique de shaping (limites de bande passante)
  traffic_shaping_policy {
    enabled          = false
    average_bandwidth = 0
    peak_bandwidth    = 0
    burst_size        = 0
  }

  # Teaming et failover (Active-Active pour agrégation)
  active_uplinks = ["uplink1", "uplink2"]

  description = "vRack VLAN ${var.vrack_vlan_rbx_id} - Réseau privé RBX (${var.vrack_vlan_rbx_cidr})"
}

# Port Group pour VLAN 900 (Backbone inter-DC)
resource "vsphere_distributed_port_group" "rbx_backbone" {
  provider = vsphere.rbx

  name                            = "VLAN-${var.vrack_vlan_backbone_id}-Backbone"
  distributed_virtual_switch_uuid = data.vsphere_distributed_virtual_switch.rbx.id

  vlan_id = var.vrack_vlan_backbone_id

  security_policy_override_allowed = true
  allow_promiscuous                = false
  allow_forged_transmits           = false
  allow_mac_changes                = false

  active_uplinks = ["uplink1", "uplink2"]

  description = "vRack VLAN ${var.vrack_vlan_backbone_id} - Backbone RBX-SBG (${var.vrack_vlan_backbone_cidr})"
}

# ------------------------------------------------------------------------------
# Data Sources - vSphere SBG
# ------------------------------------------------------------------------------

data "vsphere_datacenter" "sbg" {
  provider = vsphere.sbg
  name     = var.vsphere_sbg_datacenter
}

# ------------------------------------------------------------------------------
# Port Groups vSphere - SBG
# ------------------------------------------------------------------------------

# Port Group pour VLAN 200 (Réseau privé SBG)
resource "vsphere_distributed_port_group" "sbg_private" {
  provider = vsphere.sbg

  name                            = "VLAN-${var.vrack_vlan_sbg_id}-SBG-Private"
  distributed_virtual_switch_uuid = data.vsphere_distributed_virtual_switch.sbg.id

  vlan_id = var.vrack_vlan_sbg_id

  security_policy_override_allowed = true
  allow_promiscuous                = false
  allow_forged_transmits           = false
  allow_mac_changes                = false

  active_uplinks = ["uplink1", "uplink2"]

  description = "vRack VLAN ${var.vrack_vlan_sbg_id} - Réseau privé SBG (${var.vrack_vlan_sbg_cidr})"
}

# Port Group pour VLAN 900 (Backbone inter-DC)
resource "vsphere_distributed_port_group" "sbg_backbone" {
  provider = vsphere.sbg

  name                            = "VLAN-${var.vrack_vlan_backbone_id}-Backbone"
  distributed_virtual_switch_uuid = data.vsphere_distributed_virtual_switch.sbg.id

  vlan_id = var.vrack_vlan_backbone_id

  security_policy_override_allowed = true
  allow_promiscuous                = false
  allow_forged_transmits           = false
  allow_mac_changes                = false

  active_uplinks = ["uplink1", "uplink2"]

  description = "vRack VLAN ${var.vrack_vlan_backbone_id} - Backbone SBG-RBX (${var.vrack_vlan_backbone_cidr})"
}

# ------------------------------------------------------------------------------
# Récupération Distributed Virtual Switch (si déjà créé)
# ------------------------------------------------------------------------------

data "vsphere_distributed_virtual_switch" "rbx" {
  provider      = vsphere.rbx
  name          = var.vsphere_rbx_distributed_switch
  datacenter_id = data.vsphere_datacenter.rbx.id
}

data "vsphere_distributed_virtual_switch" "sbg" {
  provider      = vsphere.sbg
  name          = var.vsphere_sbg_distributed_switch
  datacenter_id = data.vsphere_datacenter.sbg.id
}
