###############################################################################
# MODULE ZERTO MONITORING - SURVEILLANCE ET ALERTES
###############################################################################
# Description: Configuration du monitoring et des alertes pour Zerto
###############################################################################

terraform {
  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}

locals {
  alert_config = {
    rpo_warning  = var.alert_thresholds.rpo_warning_seconds
    rpo_critical = var.alert_thresholds.rpo_critical_seconds
    journal_warning  = var.alert_thresholds.journal_usage_warning
    journal_critical = var.alert_thresholds.journal_usage_critical
  }
}

###############################################################################
# CONFIGURATION DES ALERTES
###############################################################################

resource "local_file" "prometheus_rules" {
  content = templatefile("${path.module}/templates/prometheus-rules.yml.tpl", {
    environment       = var.environment
    rpo_warning       = var.alert_thresholds.rpo_warning_seconds
    rpo_critical      = var.alert_thresholds.rpo_critical_seconds
    journal_warning   = var.alert_thresholds.journal_usage_warning
    journal_critical  = var.alert_thresholds.journal_usage_critical
    bandwidth_warning = var.alert_thresholds.bandwidth_warning_mbps
    bandwidth_critical = var.alert_thresholds.bandwidth_critical_mbps
  })

  filename = "${path.root}/../../ansible/playbooks/configs/prometheus-zerto-rules.yml"
}

resource "local_file" "grafana_dashboard" {
  content = templatefile("${path.module}/templates/grafana-dashboard.json.tpl", {
    vpg_rbx_to_sbg_id = var.vpg_rbx_to_sbg_id
    vpg_sbg_to_rbx_id = var.vpg_sbg_to_rbx_id
    environment       = var.environment
  })

  filename = "${path.root}/../../ansible/playbooks/configs/grafana-zerto-dashboard.json"
}

###############################################################################
# SCRIPT DE HEALTH CHECK
###############################################################################

resource "null_resource" "health_check_script" {
  triggers = {
    vpg_ids = "${var.vpg_rbx_to_sbg_id},${var.vpg_sbg_to_rbx_id}"
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/generate-health-check.sh"

    environment = {
      VPG_RBX_TO_SBG_ID = var.vpg_rbx_to_sbg_id
      VPG_SBG_TO_RBX_ID = var.vpg_sbg_to_rbx_id
      OUTPUT_DIR        = "${path.root}/../../scripts/monitoring"
    }
  }
}
