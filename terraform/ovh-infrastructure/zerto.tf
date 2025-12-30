# ==============================================================================
# Zerto Virtual Protection Groups (VPG) - Configuration
# ==============================================================================
# Description : Intégration des VMs dans les VPG Zerto pour la réplication
#               et le Plan de Reprise d'Activité (PRA)
# ==============================================================================

# ==============================================================================
# VPG RBX → SBG (Protection Application A)
# ==============================================================================

module "zerto_vpg_rbx_to_sbg" {
  source = "../../zerto/terraform/modules/zerto-vpg-vmware"

  # Identifiant du VPG
  vpg_name = "VPG-RBX-to-SBG-${var.environment}"

  # Sites Zerto
  source_site_id = var.zerto_site_id_rbx
  target_site_id = var.zerto_site_id_sbg

  # VMs à protéger (MySQL doit démarrer en premier)
  protected_vms = [
    {
      vm_name        = module.mysql_vm_rbx.vm_name
      vm_uuid        = module.mysql_vm_rbx.vm_uuid
      boot_priority  = 1
      boot_delay_seconds = 0
    },
    {
      vm_name        = module.docker_vm_rbx.vm_name
      vm_uuid        = module.docker_vm_rbx.vm_uuid
      boot_priority  = 2
      boot_delay_seconds = 60  # Attendre 60s après MySQL
    }
  ]

  # Configuration réseau cible (SBG)
  target_network_name = module.network_config.sbg_private_port_group_name
  failover_network = {
    gateway     = var.sbg_gateway_ip
    dns_primary = var.dns_servers[0]
    dns_secondary = var.dns_servers[1]
    domain_name = var.sbg_domain_name
  }

  # Remapping IP après failover
  vm_ip_mappings = {
    "${module.mysql_vm_rbx.vm_name}"  = var.vm_mysql_sbg_ip
    "${module.docker_vm_rbx.vm_name}" = var.vm_docker_sbg_ip
  }

  # Datastore cible
  target_datastore_name = var.vsphere_sbg_datastore
  journal_datastore_name = var.vsphere_sbg_datastore

  # Paramètres de réplication
  rpo_seconds       = var.zerto_rpo_seconds
  journal_hours     = var.zerto_journal_hours
  test_interval_hours = var.zerto_test_interval_hours
  priority          = var.zerto_priority

  # Options avancées
  enable_compression    = var.zerto_enable_compression
  enable_encryption     = var.zerto_enable_encryption
  wan_acceleration      = var.zerto_wan_acceleration

  # Métadonnées
  tags = {
    Environment = var.environment
    Project     = var.project_name
    Direction   = "RBX-to-SBG"
    Application = "App-A"
  }

  depends_on = [
    module.docker_vm_rbx,
    module.mysql_vm_rbx
  ]
}

# ==============================================================================
# VPG SBG → RBX (Protection Application B)
# ==============================================================================

module "zerto_vpg_sbg_to_rbx" {
  source = "../../zerto/terraform/modules/zerto-vpg-vmware"

  # Identifiant du VPG
  vpg_name = "VPG-SBG-to-RBX-${var.environment}"

  # Sites Zerto
  source_site_id = var.zerto_site_id_sbg
  target_site_id = var.zerto_site_id_rbx

  # VMs à protéger (MySQL doit démarrer en premier)
  protected_vms = [
    {
      vm_name        = module.mysql_vm_sbg.vm_name
      vm_uuid        = module.mysql_vm_sbg.vm_uuid
      boot_priority  = 1
      boot_delay_seconds = 0
    },
    {
      vm_name        = module.docker_vm_sbg.vm_name
      vm_uuid        = module.docker_vm_sbg.vm_uuid
      boot_priority  = 2
      boot_delay_seconds = 60
    }
  ]

  # Configuration réseau cible (RBX)
  target_network_name = module.network_config.rbx_private_port_group_name
  failover_network = {
    gateway     = var.rbx_gateway_ip
    dns_primary = var.dns_servers[0]
    dns_secondary = var.dns_servers[1]
    domain_name = var.rbx_domain_name
  }

  # Remapping IP après failover
  vm_ip_mappings = {
    "${module.mysql_vm_sbg.vm_name}"  = var.vm_mysql_rbx_ip
    "${module.docker_vm_sbg.vm_name}" = var.vm_docker_rbx_ip
  }

  # Datastore cible
  target_datastore_name = var.vsphere_rbx_datastore
  journal_datastore_name = var.vsphere_rbx_datastore

  # Paramètres de réplication
  rpo_seconds       = var.zerto_rpo_seconds
  journal_hours     = var.zerto_journal_hours
  test_interval_hours = var.zerto_test_interval_hours
  priority          = var.zerto_priority

  # Options avancées
  enable_compression    = var.zerto_enable_compression
  enable_encryption     = var.zerto_enable_encryption
  wan_acceleration      = var.zerto_wan_acceleration

  # Métadonnées
  tags = {
    Environment = var.environment
    Project     = var.project_name
    Direction   = "SBG-to-RBX"
    Application = "App-B"
  }

  depends_on = [
    module.docker_vm_sbg,
    module.mysql_vm_sbg
  ]
}

# ==============================================================================
# Variables Zerto
# ==============================================================================

variable "zerto_site_id_rbx" {
  description = "Identifiant du site Zerto RBX"
  type        = string
  default     = "rbx-site-12345"
}

variable "zerto_site_id_sbg" {
  description = "Identifiant du site Zerto SBG"
  type        = string
  default     = "sbg-site-67890"
}

variable "zerto_rpo_seconds" {
  description = "RPO en secondes (défaut: 300s = 5 minutes)"
  type        = number
  default     = 300
}

variable "zerto_journal_hours" {
  description = "Rétention du journal Zerto en heures"
  type        = number
  default     = 24
}

variable "zerto_test_interval_hours" {
  description = "Intervalle entre tests de failover (heures)"
  type        = number
  default     = 168  # 7 jours
}

variable "zerto_priority" {
  description = "Priorité de réplication (Low, Medium, High)"
  type        = string
  default     = "High"
}

variable "zerto_enable_compression" {
  description = "Activer compression des données répliquées"
  type        = bool
  default     = true
}

variable "zerto_enable_encryption" {
  description = "Activer chiffrement des données répliquées"
  type        = bool
  default     = true
}

variable "zerto_wan_acceleration" {
  description = "Activer accélération WAN"
  type        = bool
  default     = true
}

# ==============================================================================
# Outputs Zerto
# ==============================================================================

output "zerto_vpg_rbx_to_sbg" {
  description = "Informations VPG RBX → SBG"
  value = {
    vpg_name = module.zerto_vpg_rbx_to_sbg.vpg_name
    status   = module.zerto_vpg_rbx_to_sbg.vpg_status
    vms      = module.zerto_vpg_rbx_to_sbg.protected_vms_count
  }
}

output "zerto_vpg_sbg_to_rbx" {
  description = "Informations VPG SBG → RBX"
  value = {
    vpg_name = module.zerto_vpg_sbg_to_rbx.vpg_name
    status   = module.zerto_vpg_sbg_to_rbx.vpg_status
    vms      = module.zerto_vpg_sbg_to_rbx.protected_vms_count
  }
}
