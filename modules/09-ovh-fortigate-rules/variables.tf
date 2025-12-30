# ==============================================================================
# Module Terraform : FortiGate Firewall Rules Configuration
# ==============================================================================
# Description : Configuration des règles firewall FortiGate pour
#               l'infrastructure applicative OVH (RBX + SBG)
# Auteur      : DevOps Team
# Date        : 2025-12-30
# ==============================================================================

# ------------------------------------------------------------------------------
# Configuration FortiGate RBX
# ------------------------------------------------------------------------------

variable "fortigate_rbx_hostname" {
  description = "Adresse IP ou hostname du FortiGate RBX"
  type        = string
  sensitive   = true
}

variable "fortigate_rbx_token" {
  description = "API Token pour le FortiGate RBX (ou clé d'accès)"
  type        = string
  sensitive   = true
}

variable "fortigate_rbx_internal_interface" {
  description = "Nom de l'interface interne FortiGate RBX (ex: port1)"
  type        = string
  default     = "port1"
}

variable "fortigate_rbx_external_interface" {
  description = "Nom de l'interface externe FortiGate RBX (ex: port2)"
  type        = string
  default     = "port2"
}

variable "fortigate_rbx_public_ip" {
  description = "Adresse IP publique du FortiGate RBX"
  type        = string
}

# ------------------------------------------------------------------------------
# Configuration FortiGate SBG
# ------------------------------------------------------------------------------

variable "fortigate_sbg_hostname" {
  description = "Adresse IP ou hostname du FortiGate SBG"
  type        = string
  sensitive   = true
}

variable "fortigate_sbg_token" {
  description = "API Token pour le FortiGate SBG (ou clé d'accès)"
  type        = string
  sensitive   = true
}

variable "fortigate_sbg_internal_interface" {
  description = "Nom de l'interface interne FortiGate SBG (ex: port1)"
  type        = string
  default     = "port1"
}

variable "fortigate_sbg_external_interface" {
  description = "Nom de l'interface externe FortiGate SBG (ex: port2)"
  type        = string
  default     = "port2"
}

variable "fortigate_sbg_public_ip" {
  description = "Adresse IP publique du FortiGate SBG"
  type        = string
}

# ------------------------------------------------------------------------------
# Adresses IP des VMs
# ------------------------------------------------------------------------------

variable "vm_docker_rbx_ip" {
  description = "Adresse IP privée de la VM Docker RBX (ex: 10.100.0.10)"
  type        = string
}

variable "vm_mysql_rbx_ip" {
  description = "Adresse IP privée de la VM MySQL RBX (ex: 10.100.0.11)"
  type        = string
}

variable "vm_docker_sbg_ip" {
  description = "Adresse IP privée de la VM Docker SBG (ex: 10.200.0.10)"
  type        = string
}

variable "vm_mysql_sbg_ip" {
  description = "Adresse IP privée de la VM MySQL SBG (ex: 10.200.0.11)"
  type        = string
}

# ------------------------------------------------------------------------------
# Configuration réseau
# ------------------------------------------------------------------------------

variable "rbx_network_cidr" {
  description = "CIDR du réseau privé RBX (ex: 10.100.0.0/24)"
  type        = string
}

variable "sbg_network_cidr" {
  description = "CIDR du réseau privé SBG (ex: 10.200.0.0/24)"
  type        = string
}

# ------------------------------------------------------------------------------
# Ports Zerto (pour réplication)
# ------------------------------------------------------------------------------

variable "zerto_replication_ports" {
  description = "Liste des ports Zerto pour réplication (défaut: 4007-4008)"
  type        = list(string)
  default     = ["4007", "4008"]
}

# ------------------------------------------------------------------------------
# Options de configuration
# ------------------------------------------------------------------------------

variable "enable_nat_docker_rbx" {
  description = "Activer le NAT/VIP pour la VM Docker RBX vers Internet"
  type        = bool
  default     = true
}

variable "enable_nat_docker_sbg" {
  description = "Activer le NAT/VIP pour la VM Docker SBG vers Internet"
  type        = bool
  default     = true
}

variable "enable_logging" {
  description = "Activer le logging des règles firewall"
  type        = bool
  default     = true
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
