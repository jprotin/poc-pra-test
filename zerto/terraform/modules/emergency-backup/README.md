# Module Terraform - Emergency Backup

## Vue d'Ensemble

Ce module Terraform provisionne automatiquement une infrastructure de **backup d'urgence** pour protéger les applications dans une architecture Zerto Active/Active lorsqu'un site tombe.

### Problématique

Dans une architecture Active/Active :
- **Application A** tourne sur RBX (répliquée vers SBG)
- **Application B** tourne sur SBG (répliquée vers RBX)

Si le site **RBX tombe** :
- ✅ Application A peut être failovée vers SBG (protection Zerto fonctionne)
- ⚠️ **Application B perd sa protection** (cible de réplication RBX inaccessible)
- 🔴 **Risque "Double Peine"** : Si SBG tombe pendant que RBX est KO → Perte totale App B

### Solution

Ce module active automatiquement une **protection compensatoire** :
1. **Backup Local** : Veeam Backup vers repository local SBG (RTO: 2-4h, RPO: 12h)
2. **Backup S3 Immuable** : Veeam Backup Copy vers OVHcloud S3 GRA (RTO: 4-8h, RPO: 12h, immutable 30j)

---

## Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                    PROTECTION NORMALE                          │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  RBX ←─────────── Zerto ────────→ SBG                        │
│   │                                 │                          │
│   │  Application A (prod)           │  Application B (prod)   │
│   │  Réplica B (DR)                 │  Réplica A (DR)         │
│   │                                 │                          │
│   └─── RPO 5 min ───────────────────┘                          │
│                                                                │
└────────────────────────────────────────────────────────────────┘

         ⬇️  INCIDENT: Perte Site RBX

┌────────────────────────────────────────────────────────────────┐
│              PROTECTION COMPENSATOIRE ACTIVÉE                  │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  RBX (❌ DOWN)              SBG (✅ SURVIVANT)                 │
│                              │                                 │
│                              │  Application A (failovée)      │
│                              │  Application B (prod)           │
│                              │                                 │
│                              │  ⚙️ EMERGENCY BACKUP            │
│                              │                                 │
│                              ├──► Veeam Local (12h RPO)        │
│                              │    Repository SBG               │
│                              │    Rétention: 7 jours           │
│                              │                                 │
│                              └──► Veeam S3 (12h RPO)           │
│                                   Bucket: GRA                  │
│                                   Immutable: 30 jours          │
│                                   Chiffré: AES-256             │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

---

## Fonctionnalités

### ✅ Backup Local

- **Provider** : Veeam Backup & Replication
- **Target** : Repository local sur le site survivant
- **Fréquence** : 2x par jour (02:00 et 14:00)
- **Rétention** : 7 jours
- **Compression** : Optimal
- **RTO** : 2-4 heures
- **RPO** : 12 heures max

### ✅ Backup S3 Immuable

- **Provider** : OVHcloud Object Storage S3
- **Target** : Bucket S3 région GRA (hors RBX et SBG)
- **Immutabilité** : Object Lock (WORM) - 30 jours
- **Fréquence** : 2x par jour (04:00 et 16:00)
- **Rétention** : 30 jours
- **Chiffrement** : AES-256
- **RTO** : 4-8 heures
- **RPO** : 12 heures max

### ✅ Automatisation

- **Trigger** : Détection VPG `NotMeetingSLA` (monitoring automatique)
- **Provisioning** : Terraform (création infrastructure)
- **Activation** : Ansible (jobs Veeam + backup immédiat)
- **Monitoring** : Scripts de surveillance quotidienne
- **Alertes** : Webhook Slack/Teams + Email

---

## Prérequis

### Infrastructure

- ✅ OVHcloud Public Cloud Project actif
- ✅ Veeam Backup & Replication 12+ installé
- ✅ Repository local configuré sur chaque site
- ✅ Connectivité API Veeam (port 9419)
- ✅ Credentials OVH API

### Logiciels

```bash
terraform >= 1.0
ansible >= 2.10
jq >= 1.6
curl >= 7.68
veeam-cli (optionnel)
```

---

## Usage

### 1. Configuration des Variables

Créer un fichier `emergency-backup-app-b.auto.tfvars` :

```hcl
# Application et environnement
app_name     = "Application-B"
site         = "SBG"
environment  = "production"

# VMs à protéger
vms_to_protect = [
  "sbg-app-prod-01",
  "sbg-db-prod-01"
]

# Veeam API
veeam_api_endpoint = "https://veeam-server.local:9419"
veeam_api_token    = "your-veeam-api-token"

# Backup Local
enable_local_backup     = true
veeam_repository_local  = "Repository-SBG"
local_retention_days    = 7
backup_times_local      = ["02:00", "14:00"]

# Backup S3
enable_s3_backup        = true
ovh_project_id          = "your-ovh-project-id"
s3_region               = "GRA"
s3_endpoint             = "https://s3.gra.cloud.ovh.net"
s3_immutable            = true
s3_immutable_days       = 30
s3_retention_days       = 30
backup_times_s3         = ["04:00", "16:00"]

# Monitoring
enable_monitoring       = true
alert_webhook_url       = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
alert_emails            = ["ops-team@example.com"]

# Sécurité
enable_encryption       = true
compression_level       = "Optimal"

# Tags
common_tags = {
  "Project"     = "POC-PRA"
  "Environment" = "Production"
  "Solution"    = "Zerto-Emergency-Backup"
  "ManagedBy"   = "Terraform"
}
```

### 2. Déploiement

```bash
# Initialiser Terraform
cd zerto/terraform
terraform init

# Planifier le déploiement
terraform plan \
  -var-file="emergency-backup-app-b.auto.tfvars" \
  -target=module.emergency_backup_application_b

# Déployer (NE PAS exécuter manuellement - laissez Ansible le faire)
# terraform apply -auto-approve
```

### 3. Activation Automatique (Recommandé)

**Via Ansible lors de la détection d'un VPG KO :**

```bash
ansible-playbook zerto/ansible/playbooks/activate-emergency-backup.yml \
  -e "app_name=Application-B" \
  -e "site=SBG" \
  -e "vms_to_protect=[\"sbg-app-prod-01\", \"sbg-db-prod-01\"]" \
  --vault-password-file ~/.ansible/vault_pass.txt
```

Le playbook va :
1. ✅ Vérifier l'état du VPG
2. ✅ Générer le fichier `.tfvars` automatiquement
3. ✅ Exécuter `terraform apply`
4. ✅ Créer les jobs Veeam (local + S3)
5. ✅ Lancer le premier backup immédiat
6. ✅ Configurer le monitoring
7. ✅ Envoyer les alertes

### 4. Surveillance

**Script de monitoring (à mettre en cron) :**

```bash
# Vérifier les VPGs toutes les 5 minutes
*/5 * * * * /path/to/zerto/scripts/check-vpg-status.sh --all --auto-remediate

# Check quotidien manuel
./zerto/scripts/check-vpg-status.sh --all --verbose
```

**Vérifier les backups :**

```bash
# Via Veeam CLI
veeam-cli job list | grep Emergency
veeam-cli job info "Emergency-Backup-Application-B-Local"

# Via API Veeam
curl -H "Authorization: Bearer $VEEAM_API_TOKEN" \
  https://veeam-server:9419/api/v1/jobs/Emergency-Backup-Application-B-Local
```

---

## Variables

### Obligatoires

| Variable | Type | Description |
|----------|------|-------------|
| `app_name` | `string` | Nom de l'application (Application-A ou Application-B) |
| `site` | `string` | Site de déploiement (RBX ou SBG) |
| `vms_to_protect` | `list(string)` | Liste des VMs à inclure dans le backup |
| `veeam_api_endpoint` | `string` | URL API Veeam REST |
| `veeam_api_token` | `string` | Token authentification Veeam |
| `ovh_project_id` | `string` | ID projet OVHcloud Public Cloud |

### Optionnelles

| Variable | Type | Défaut | Description |
|----------|------|--------|-------------|
| `enable_local_backup` | `bool` | `true` | Activer backup local |
| `enable_s3_backup` | `bool` | `true` | Activer backup S3 |
| `local_retention_days` | `number` | `7` | Rétention backups locaux (jours) |
| `s3_retention_days` | `number` | `30` | Rétention backups S3 (jours) |
| `s3_immutable` | `bool` | `true` | Activer immutabilité S3 (Object Lock) |
| `s3_immutable_days` | `number` | `30` | Durée immutabilité (jours) |
| `s3_region` | `string` | `"GRA"` | Région S3 OVHcloud |
| `enable_encryption` | `bool` | `true` | Activer chiffrement AES-256 |
| `compression_level` | `string` | `"Optimal"` | Niveau compression (None, Dedupe, Optimal, High, Extreme) |

---

## Outputs

| Output | Description |
|--------|-------------|
| `s3_bucket_name` | Nom du bucket S3 créé |
| `s3_endpoint` | Endpoint S3 pour connexion Veeam |
| `s3_access_key_id` | Access Key S3 (sensible) |
| `veeam_local_job_name` | Nom du job Veeam local |
| `veeam_s3_job_name` | Nom du job Veeam S3 |
| `backup_status` | Statut général du backup d'urgence |

---

## Exemples

### Exemple 1: Protection Application B (SBG survivant)

```hcl
module "emergency_backup_app_b" {
  source = "./modules/emergency-backup"

  app_name        = "Application-B"
  site            = "SBG"
  environment     = "production"

  vms_to_protect = [
    "sbg-app-prod-01",
    "sbg-db-prod-01"
  ]

  # Veeam
  veeam_api_endpoint     = "https://veeam-sbg.local:9419"
  veeam_api_token        = var.veeam_api_token
  veeam_repository_local = "Repository-SBG"

  # S3
  enable_s3_backup   = true
  ovh_project_id     = var.ovh_project_id
  s3_region          = "GRA"
  s3_immutable       = true
  s3_immutable_days  = 30

  # Monitoring
  alert_webhook_url = var.alert_webhook_url
  alert_emails      = ["ops-team@example.com"]
}
```

### Exemple 2: Backup Local Seulement (Coût réduit)

```hcl
module "emergency_backup_app_a" {
  source = "./modules/emergency-backup"

  app_name        = "Application-A"
  site            = "RBX"
  vms_to_protect  = ["rbx-app-prod-01", "rbx-db-prod-01"]

  # Veeam
  veeam_api_endpoint     = var.veeam_api_endpoint
  veeam_api_token        = var.veeam_api_token

  # Backup local uniquement
  enable_local_backup    = true
  local_retention_days   = 14

  # Désactiver S3 (économie)
  enable_s3_backup       = false
}
```

---

## Sécurité

### Chiffrement

- **Backups locaux** : Chiffrement AES-256 (si `enable_encryption = true`)
- **Backups S3** : Chiffrement AES-256 server-side + transit TLS 1.3

### Immutabilité S3

- **Mode COMPLIANCE** : Les backups ne peuvent être supprimés pendant la période d'immutabilité (30j par défaut)
- **Protection ransomware** : Même un administrateur avec accès root ne peut supprimer les backups immuables
- **Conformité** : RGPD, ISO 27001, SOC 2

### Credentials

- **Veeam API Token** : Stocké dans variables Terraform `sensitive = true`
- **S3 Credentials** : Créées automatiquement, non exposées dans outputs
- **Recommandation** : Utiliser Terraform Cloud / Vault pour gestion secrets

---

## Coûts Estimés

### Backup Local (Repository SBG)

- **Storage** : Dépend du stockage existant (sunk cost)
- **Estimation** : 500 GB × 7 jours = 3,5 TB requis
- **Coût** : Inclus dans infrastructure existante

### Backup S3 Immuable (GRA)

Hypothèses :
- Taille VMs : 500 GB
- Compression : 2:1 → 250 GB stockés
- Rétention : 30 jours
- Backups quotidiens (×2)

| Composant | Calcul | Coût Mensuel |
|-----------|--------|--------------|
| **Storage S3** | 250 GB × €0.02/GB/mois | €5 |
| **Requêtes PUT** | 2 × 30 jours × €0.005 | €0.30 |
| **Egress (restauration)** | 250 GB × €0.01/GB (ponctuel) | €2.50 (si restauration) |
| **TOTAL MENSUEL** | | **~€6-8** |

**Note** : Coût très faible par rapport à la valeur de l'application protégée.

---

## Limitations

- ❌ Nécessite Veeam Backup & Replication 12+ (pour API REST)
- ❌ S3 Object Lock disponible uniquement sur certaines régions OVHcloud
- ❌ RTO de 4-8h depuis S3 (bande passante dépendante)
- ⚠️ Consomme de l'espace disque supplémentaire sur le site survivant
- ⚠️ Veeam doit être licencié pour les VMs protégées

---

## FAQ

### Q: Quand ce module s'active-t-il ?

**R:** Automatiquement lorsqu'un VPG Zerto passe en état `NotMeetingSLA` (détecté par le script de monitoring).

### Q: Peut-on activer manuellement ?

**R:** Oui, via Ansible :
```bash
ansible-playbook activate-emergency-backup.yml -e "app_name=Application-B" -e "site=SBG"
```

### Q: Que se passe-t-il au retour du site KO ?

**R:** Zerto resynchronise automatiquement (Delta Sync basé sur bitmap). Vous pouvez :
- **Option A** : Conserver les backups d'urgence (double protection)
- **Option B** : Désactiver les backups (économie coûts)

### Q: Quelle est la différence entre backup local et S3 ?

| Critère | Backup Local | Backup S3 |
|---------|--------------|-----------|
| **RTO** | 2-4h | 4-8h |
| **RPO** | 12h | 12h |
| **Protection site** | ❌ Même site | ✅ Hors site (GRA) |
| **Immutabilité** | ⚠️ Optionnelle | ✅ WORM 30j |
| **Coût** | Inclus | ~€8/mois |
| **Ransomware** | ⚠️ Vulnérable | ✅ Protégé |

**Recommandation** : Activer les DEUX pour protection maximale.

---

## Support

### Documentation

- 📄 [Documentation Technique Zerto](../../../Documentation/zerto/01-implementation-technique.md)
- 📄 [Analyse Perte Site Active/Active](../../../Documentation/zerto/03-analyse-perte-site-active-active.md)
- 📄 [Runbook Perte Site](../../runbooks/runbook-site-loss.md)

### Contacts

- **Équipe Ops** : ops-team@example.com
- **Équipe Infra** : infra-team@example.com
- **Support Veeam** : https://www.veeam.com/support.html
- **Support OVHcloud** : https://www.ovh.com/manager/

---

**Auteur** : Équipe Infrastructure
**Version** : 1.0
**Dernière MAJ** : 2025-12-17
