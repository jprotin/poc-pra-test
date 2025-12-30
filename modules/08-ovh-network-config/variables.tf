# ==============================================================================
# Module Terraform : OVH Network Configuration (vRack + vSphere Port Groups)
# ==============================================================================
# Description : Configuration des réseaux privés OVH (vRack) et des port groups
#               vSphere pour l'interconnexion RBX <-> SBG
# Auteur      : DevOps Team
# Date        : 2025-12-30
# ==============================================================================

# ------------------------------------------------------------------------------
# Configuration vSphere RBX
# ------------------------------------------------------------------------------

variable "vsphere_rbx_server" {
  description = "Adresse du serveur vCenter RBX"
  type        = string
  sensitive   = true
}

variable "vsphere_rbx_datacenter" {
  description = "Nom du datacenter vSphere RBX"
  type        = string
}

variable "vsphere_rbx_distributed_switch" {
  description = "Nom du vSphere Distributed Switch RBX pour vRack"
  type        = string
  default     = "vRack-DSwitch-RBX"
}

# ------------------------------------------------------------------------------
# Configuration vSphere SBG
# ------------------------------------------------------------------------------

variable "vsphere_sbg_server" {
  description = "Adresse du serveur vCenter SBG"
  type        = string
  sensitive   = true
}

variable "vsphere_sbg_datacenter" {
  description = "Nom du datacenter vSphere SBG"
  type        = string
}

variable "vsphere_sbg_distributed_switch" {
  description = "Nom du vSphere Distributed Switch SBG pour vRack"
  type        = string
  default     = "vRack-DSwitch-SBG"
}

# ------------------------------------------------------------------------------
# Configuration vRack (VLANs)
# ------------------------------------------------------------------------------

variable "vrack_vlan_rbx_id" {
  description = "ID du VLAN pour le réseau privé RBX (ex: 100)"
  type        = number
  default     = 100
  validation {
    condition     = var.vrack_vlan_rbx_id >= 2 && var.vrack_vlan_rbx_id <= 4094
    error_message = "Le VLAN ID doit être entre 2 et 4094."
  }
}

variable "vrack_vlan_rbx_cidr" {
  description = "CIDR du réseau privé RBX (ex: 10.100.0.0/24)"
  type        = string
  default     = "10.100.0.0/24"
}

variable "vrack_vlan_sbg_id" {
  description = "ID du VLAN pour le réseau privé SBG (ex: 200)"
  type        = number
  default     = 200
  validation {
    condition     = var.vrack_vlan_sbg_id >= 2 && var.vrack_vlan_sbg_id <= 4094
    error_message = "Le VLAN ID doit être entre 2 et 4094."
  }
}

variable "vrack_vlan_sbg_cidr" {
  description = "CIDR du réseau privé SBG (ex: 10.200.0.0/24)"
  type        = string
  default     = "10.200.0.0/24"
}

variable "vrack_vlan_backbone_id" {
  description = "ID du VLAN pour l'interconnexion RBX-SBG (ex: 900)"
  type        = number
  default     = 900
}

variable "vrack_vlan_backbone_cidr" {
  description = "CIDR du réseau backbone inter-DC (ex: 10.255.0.0/30)"
  type        = string
  default     = "10.255.0.0/30"
}

# ------------------------------------------------------------------------------
# Métadonnées
# ------------------------------------------------------------------------------

variable "environment" {
  description = "Environnement (dev, test, staging, prod)"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Nom du projet"
  type        = string
  default     = "pra"
}

variable "tags" {
  description = "Tags additionnels"
  type        = map(string)
  default     = {}
}
