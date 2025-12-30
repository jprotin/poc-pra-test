# ==============================================================================
# Module Terraform : OVH Network Configuration - Outputs
# ==============================================================================

# ------------------------------------------------------------------------------
# Port Groups RBX
# ------------------------------------------------------------------------------

output "rbx_private_port_group_name" {
  description = "Nom du port group privé RBX"
  value       = vsphere_distributed_port_group.rbx_private.name
}

output "rbx_private_port_group_id" {
  description = "ID du port group privé RBX"
  value       = vsphere_distributed_port_group.rbx_private.id
}

output "rbx_backbone_port_group_name" {
  description = "Nom du port group backbone RBX"
  value       = vsphere_distributed_port_group.rbx_backbone.name
}

output "rbx_vlan_id" {
  description = "ID du VLAN privé RBX"
  value       = var.vrack_vlan_rbx_id
}

output "rbx_network_cidr" {
  description = "CIDR du réseau privé RBX"
  value       = var.vrack_vlan_rbx_cidr
}

# ------------------------------------------------------------------------------
# Port Groups SBG
# ------------------------------------------------------------------------------

output "sbg_private_port_group_name" {
  description = "Nom du port group privé SBG"
  value       = vsphere_distributed_port_group.sbg_private.name
}

output "sbg_private_port_group_id" {
  description = "ID du port group privé SBG"
  value       = vsphere_distributed_port_group.sbg_private.id
}

output "sbg_backbone_port_group_name" {
  description = "Nom du port group backbone SBG"
  value       = vsphere_distributed_port_group.sbg_backbone.name
}

output "sbg_vlan_id" {
  description = "ID du VLAN privé SBG"
  value       = var.vrack_vlan_sbg_id
}

output "sbg_network_cidr" {
  description = "CIDR du réseau privé SBG"
  value       = var.vrack_vlan_sbg_cidr
}

# ------------------------------------------------------------------------------
# Backbone inter-DC
# ------------------------------------------------------------------------------

output "backbone_vlan_id" {
  description = "ID du VLAN backbone inter-DC"
  value       = var.vrack_vlan_backbone_id
}

output "backbone_network_cidr" {
  description = "CIDR du réseau backbone"
  value       = var.vrack_vlan_backbone_cidr
}

# ------------------------------------------------------------------------------
# Informations réseau consolidées
# ------------------------------------------------------------------------------

output "network_summary" {
  description = "Résumé de la configuration réseau vRack"
  value = {
    rbx = {
      vlan_id     = var.vrack_vlan_rbx_id
      cidr        = var.vrack_vlan_rbx_cidr
      port_group  = vsphere_distributed_port_group.rbx_private.name
    }
    sbg = {
      vlan_id     = var.vrack_vlan_sbg_id
      cidr        = var.vrack_vlan_sbg_cidr
      port_group  = vsphere_distributed_port_group.sbg_private.name
    }
    backbone = {
      vlan_id = var.vrack_vlan_backbone_id
      cidr    = var.vrack_vlan_backbone_cidr
    }
  }
}
