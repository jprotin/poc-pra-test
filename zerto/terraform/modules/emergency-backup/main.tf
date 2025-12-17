###############################################################################
# MODULE EMERGENCY BACKUP - PROTECTION COMPENSATOIRE
###############################################################################
# Description: Backup d'urgence activé automatiquement quand un VPG tombe
# Usage: Protège le site survivant en mode Active/Active quand l'autre est KO
###############################################################################

terraform {
  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = "~> 0.35"
    }
  }
}

###############################################################################
# S3 OBJECT STORAGE POUR BACKUP IMMUABLE
###############################################################################

# Création du bucket S3 pour les backups immuables
resource "ovh_cloud_project_database_s3_bucket" "emergency_backup" {
  count = var.enable_s3_backup ? 1 : 0

  service_name  = var.ovh_project_id
  region        = var.s3_region
  name          = "${var.app_name}-emergency-backup-${var.environment}"

  versioning_enabled = true

  lifecycle_rule {
    id      = "backup-retention"
    enabled = true

    expiration {
      days = var.s3_retention_days
    }

    noncurrent_version_expiration {
      days = 7
    }
  }

  tags = merge(
    var.common_tags,
    {
      "Purpose"     = "Emergency-Backup"
      "Application" = var.app_name
      "Immutable"   = "true"
    }
  )
}

# Configuration de l'immutabilité (Object Lock)
resource "ovh_cloud_project_database_s3_bucket_object_lock" "emergency_backup_lock" {
  count = var.enable_s3_backup && var.s3_immutable ? 1 : 0

  service_name = var.ovh_project_id
  bucket_name  = ovh_cloud_project_database_s3_bucket.emergency_backup[0].name

  mode = "COMPLIANCE"  # Mode WORM strict
  days = var.s3_immutable_days

  depends_on = [ovh_cloud_project_database_s3_bucket.emergency_backup]
}

# Utilisateur S3 dédié pour Veeam
resource "ovh_cloud_project_user_s3_credential" "veeam_s3_user" {
  count = var.enable_s3_backup ? 1 : 0

  service_name = var.ovh_project_id

  depends_on = [ovh_cloud_project_database_s3_bucket.emergency_backup]
}

# Politique d'accès au bucket (Veeam uniquement)
resource "ovh_cloud_project_database_s3_bucket_policy" "veeam_access" {
  count = var.enable_s3_backup ? 1 : 0

  service_name = var.ovh_project_id
  bucket_name  = ovh_cloud_project_database_s3_bucket.emergency_backup[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "VeeamBackupAccess"
        Effect = "Allow"
        Principal = {
          AWS = ovh_cloud_project_user_s3_credential.veeam_s3_user[0].access_key_id
        }
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${ovh_cloud_project_database_s3_bucket.emergency_backup[0].name}",
          "arn:aws:s3:::${ovh_cloud_project_database_s3_bucket.emergency_backup[0].name}/*"
        ]
      }
    ]
  })
}

###############################################################################
# CONFIGURATION VEEAM (via API REST)
###############################################################################

# Job Veeam Backup Local (Repository local sur le site survivant)
resource "null_resource" "veeam_local_job" {
  count = var.enable_local_backup ? 1 : 0

  triggers = {
    vms         = join(",", var.vms_to_protect)
    app_name    = var.app_name
    schedule    = var.backup_schedule_local
    always_run  = timestamp()  # Force update pour vérifier
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -X POST "${var.veeam_api_endpoint}/api/v1/jobs" \
        -H "Authorization: Bearer ${var.veeam_api_token}" \
        -H "Content-Type: application/json" \
        -d '{
          "name": "Emergency-Backup-${var.app_name}-Local",
          "type": "Backup",
          "description": "Backup d urgence activé automatiquement - ${var.app_name}",
          "enabled": true,
          "virtualMachines": ${jsonencode(var.vms_to_protect)},
          "storage": {
            "repositoryName": "${var.veeam_repository_local}"
          },
          "schedule": {
            "type": "Daily",
            "dailyOptions": {
              "times": ${jsonencode(var.backup_times_local)}
            }
          },
          "retentionPolicy": {
            "type": "Days",
            "value": ${var.local_retention_days}
          },
          "compressionLevel": "Optimal",
          "storageOptimization": "Local",
          "enableEncryption": ${var.enable_encryption},
          "tags": ["emergency", "${var.app_name}", "active-active-protection"]
        }'
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      curl -X DELETE "${var.veeam_api_endpoint}/api/v1/jobs/Emergency-Backup-${var.app_name}-Local" \
        -H "Authorization: Bearer ${var.veeam_api_token}"
    EOT
  }
}

# Job Veeam Backup Copy vers S3
resource "null_resource" "veeam_s3_job" {
  count = var.enable_s3_backup ? 1 : 0

  triggers = {
    bucket_name = ovh_cloud_project_database_s3_bucket.emergency_backup[0].name
    app_name    = var.app_name
    schedule    = var.backup_schedule_s3
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -X POST "${var.veeam_api_endpoint}/api/v1/backupCopyJobs" \
        -H "Authorization: Bearer ${var.veeam_api_token}" \
        -H "Content-Type: application/json" \
        -d '{
          "name": "Emergency-Backup-${var.app_name}-S3",
          "type": "BackupCopy",
          "description": "Copie backup vers S3 immuable - ${var.app_name}",
          "enabled": true,
          "sourceJob": "Emergency-Backup-${var.app_name}-Local",
          "target": {
            "type": "S3Compatible",
            "endpoint": "${var.s3_endpoint}",
            "bucket": "${ovh_cloud_project_database_s3_bucket.emergency_backup[0].name}",
            "region": "${var.s3_region}",
            "accessKey": "${ovh_cloud_project_user_s3_credential.veeam_s3_user[0].access_key_id}",
            "secretKey": "${ovh_cloud_project_user_s3_credential.veeam_s3_user[0].secret_access_key}",
            "immutabilityEnabled": ${var.s3_immutable}
          },
          "schedule": {
            "type": "Daily",
            "dailyOptions": {
              "times": ${jsonencode(var.backup_times_s3)}
            }
          },
          "retentionPolicy": {
            "type": "Days",
            "value": ${var.s3_retention_days}
          },
          "compressionLevel": "Optimal",
          "enableEncryption": true,
          "tags": ["emergency", "${var.app_name}", "s3-immutable", "offsite"]
        }'
    EOT

    environment = {
      S3_ACCESS_KEY = ovh_cloud_project_user_s3_credential.veeam_s3_user[0].access_key_id
      S3_SECRET_KEY = ovh_cloud_project_user_s3_credential.veeam_s3_user[0].secret_access_key
    }
  }

  depends_on = [
    null_resource.veeam_local_job,
    ovh_cloud_project_database_s3_bucket.emergency_backup
  ]

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      curl -X DELETE "${var.veeam_api_endpoint}/api/v1/backupCopyJobs/Emergency-Backup-${var.app_name}-S3" \
        -H "Authorization: Bearer ${var.veeam_api_token}"
    EOT
  }
}

###############################################################################
# MONITORING - CLOUDWATCH / GRAFANA
###############################################################################

# Alerte si backup échoue
resource "null_resource" "backup_monitoring" {
  count = var.enable_monitoring ? 1 : 0

  triggers = {
    app_name = var.app_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      cat > /tmp/backup-monitor-${var.app_name}.sh <<'EOF'
#!/bin/bash
# Monitoring des backups d'urgence pour ${var.app_name}

VEEAM_API="${var.veeam_api_endpoint}"
VEEAM_TOKEN="${var.veeam_api_token}"
WEBHOOK_URL="${var.alert_webhook_url}"

# Vérifier le dernier backup local
LOCAL_JOB_STATUS=$(curl -s "$VEEAM_API/api/v1/jobs/Emergency-Backup-${var.app_name}-Local/lastSession" \
  -H "Authorization: Bearer $VEEAM_TOKEN" | jq -r '.result')

if [[ "$LOCAL_JOB_STATUS" != "Success" ]]; then
  curl -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{\"text\": \"🚨 CRITICAL: Emergency backup local failed for ${var.app_name}\", \"priority\": \"high\"}"
fi

# Vérifier le dernier backup S3
S3_JOB_STATUS=$(curl -s "$VEEAM_API/api/v1/backupCopyJobs/Emergency-Backup-${var.app_name}-S3/lastSession" \
  -H "Authorization: Bearer $VEEAM_TOKEN" | jq -r '.result')

if [[ "$S3_JOB_STATUS" != "Success" ]]; then
  curl -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{\"text\": \"🚨 CRITICAL: Emergency backup S3 failed for ${var.app_name}\", \"priority\": \"high\"}"
fi
EOF
      chmod +x /tmp/backup-monitor-${var.app_name}.sh
    EOT
  }
}

###############################################################################
# OUTPUTS
###############################################################################

output "s3_bucket_name" {
  description = "Nom du bucket S3 pour les backups immuables"
  value       = var.enable_s3_backup ? ovh_cloud_project_database_s3_bucket.emergency_backup[0].name : null
}

output "s3_endpoint" {
  description = "Endpoint S3 pour connexion Veeam"
  value       = var.enable_s3_backup ? var.s3_endpoint : null
}

output "s3_access_key_id" {
  description = "Access Key ID S3 (sensible)"
  value       = var.enable_s3_backup ? ovh_cloud_project_user_s3_credential.veeam_s3_user[0].access_key_id : null
  sensitive   = true
}

output "veeam_local_job_name" {
  description = "Nom du job Veeam local"
  value       = var.enable_local_backup ? "Emergency-Backup-${var.app_name}-Local" : null
}

output "veeam_s3_job_name" {
  description = "Nom du job Veeam S3"
  value       = var.enable_s3_backup ? "Emergency-Backup-${var.app_name}-S3" : null
}

output "backup_status" {
  description = "Statut de la configuration du backup d'urgence"
  value = {
    local_enabled = var.enable_local_backup
    s3_enabled    = var.enable_s3_backup
    immutable     = var.s3_immutable
    application   = var.app_name
  }
}
