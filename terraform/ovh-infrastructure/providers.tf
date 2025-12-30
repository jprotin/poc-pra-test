# ==============================================================================
# Providers Configuration - OVH VMware Infrastructure
# ==============================================================================
# Description : Configuration des providers Terraform pour l'infrastructure
#               applicative OVH (vSphere RBX/SBG + FortiGate + Zerto)
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.6"
    }

    fortios = {
      source  = "fortinetdev/fortios"
      version = "~> 1.19"
    }

    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }

  # Backend S3 (optionnel - utiliser OVH Object Storage)
  # backend "s3" {
  #   bucket                      = "terraform-state-pra"
  #   key                         = "ovh-infrastructure/terraform.tfstate"
  #   region                      = "gra"
  #   endpoint                    = "https://s3.gra.cloud.ovh.net"
  #   skip_credentials_validation = true
  #   skip_region_validation      = true
  # }
}

# ------------------------------------------------------------------------------
# Provider vSphere RBX
# ------------------------------------------------------------------------------

provider "vsphere" {
  alias = "rbx"

  user                 = var.vsphere_rbx_user
  password             = var.vsphere_rbx_password
  vsphere_server       = var.vsphere_rbx_server
  allow_unverified_ssl = true # À désactiver en production avec certificats valides
}

# ------------------------------------------------------------------------------
# Provider vSphere SBG
# ------------------------------------------------------------------------------

provider "vsphere" {
  alias = "sbg"

  user                 = var.vsphere_sbg_user
  password             = var.vsphere_sbg_password
  vsphere_server       = var.vsphere_sbg_server
  allow_unverified_ssl = true
}

# ------------------------------------------------------------------------------
# Provider FortiGate RBX
# ------------------------------------------------------------------------------

provider "fortios" {
  alias = "rbx"

  hostname = var.fortigate_rbx_hostname
  token    = var.fortigate_rbx_token
  insecure = "true" # À désactiver en production
}

# ------------------------------------------------------------------------------
# Provider FortiGate SBG
# ------------------------------------------------------------------------------

provider "fortios" {
  alias = "sbg"

  hostname = var.fortigate_sbg_hostname
  token    = var.fortigate_sbg_token
  insecure = "true"
}
