# Zerto Disaster Recovery - Architecture Active/Active RBX ⟷ SBG

Solution de Plan de Reprise d'Activité (PRA/PRI) basée sur Zerto pour la réplication bi-directionnelle entre les régions OVHcloud RBX (Roubaix) et SBG (Strasbourg).

> **📌 Plateforme** : Cette solution est conçue pour **OVHcloud Hosted Private Cloud (VMware vSphere)**
>
> Les VMs protégées doivent être hébergées sur l'infrastructure VMware vSphere (non compatible avec Public Cloud OpenStack).

> **⚠️ Architecture Réseau** : Les Fortigates sont connectés à **Azure VPN Gateway** (hub BGP), PAS entre eux.
>
> Le failover BGP est géré automatiquement par Azure. Zerto gère uniquement la réplication des VMs.

---

## 🎯 Vue d'ensemble

Cette solution protège vos applications critiques dans une architecture **Active/Active Distribuée** avec protection compensatoire automatique en cas de perte de site.

### Caractéristiques

- **RPO : 5 minutes** - Perte de données maximale (réplication continue)
- **RTO : 15 minutes** - Temps de restauration maximal (failover automatisé)
- **Architecture Active/Active** - Deux applications en production simultanée
- **Protection "Double Peine"** - Backup d'urgence automatique si un site tombe
- **Failover automatisé** - Scripts d'orchestration pour bascule rapide
- **Infrastructure as Code** - Terraform + Ansible pour déploiement reproductible
- **Monitoring proactif** - Détection et mitigation automatique des incidents

### Modèle de Déploiement

```
┌────────────────────────────────────────────────────────────────┐
│                 ARCHITECTURE ACTIVE/ACTIVE                     │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  RBX (Production)                    SBG (Production)         │
│  ┌──────────────────┐                ┌──────────────────┐     │
│  │ Application A    │                │ Application B    │     │
│  │ (actif)          │                │ (actif)          │     │
│  └────────┬─────────┘                └────────┬─────────┘     │
│           │                                   │               │
│           │  Zerto Réplication (RPO 5 min)   │               │
│           │                                   │               │
│  ┌────────▼─────────┐                ┌───────▼──────────┐     │
│  │ Réplica B (DR)   │◄───────────────│ Réplica A (DR)   │     │
│  └──────────────────┘                └──────────────────┘     │
│                                                                │
│         │                                            │         │
│  ┌──────▼────────┐                        ┌─────────▼──────┐  │
│  │ Fortigate RBX │                        │ Fortigate SBG  │  │
│  │ (Primary)     │◄────────vRack──────────│ (Backup)       │  │
│  └───────┬───────┘                        └────────┬───────┘  │
│          │                                         │           │
│          └────────────┐                  ┌─────────┘           │
│                       │ Tunnel IPsec/BGP │                     │
│                       ▼                  ▼                     │
│                  ┌─────────────────────────┐                   │
│                  │  Azure VPN Gateway      │                   │
│                  │  (BGP Hub - Failover)   │                   │
│                  └─────────────────────────┘                   │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

**En cas de perte d'un site** :
- ✅ Application du site KO : Failover automatique vers le site survivant
- ⚠️ Application du site survivant : Protection compensatoire activée (backup local + S3)

---

## 📁 Structure du projet

```
zerto/
├── terraform/                    # Infrastructure as Code
│   ├── main.tf                  # Configuration principale (VMware vSphere)
│   ├── variables.tf             # Variables Terraform (vCenter + Fortigate)
│   ├── outputs.tf               # Sorties Terraform
│   ├── terraform.tfvars.example # Exemple configuration VMware
│   └── modules/
│       ├── zerto-vpg-vmware/    # Virtual Protection Groups (VMware)
│       ├── zerto-network/       # VIPs et firewall Fortigate (Zerto)
│       ├── zerto-monitoring/    # Monitoring et alertes
│       └── emergency-backup/    # 🆕 Backup d'urgence (S3 + Veeam)
│
├── ansible/                     # Configuration management
│   └── playbooks/
│       ├── deploy-zerto.yml     # Déploiement principal
│       ├── configure-fortigate.yml  # Configuration Fortigate
│       └── activate-emergency-backup.yml  # 🆕 Activation backup urgence
│
├── scripts/                     # Scripts d'orchestration
│   ├── failover-rbx-to-sbg.sh  # Failover RBX → SBG
│   ├── failover-sbg-to-rbx.sh  # Failover SBG → RBX
│   ├── failback.sh             # Retour à la normale
│   ├── check-vpg-status.sh     # 🆕 Monitoring VPGs + auto-remediate
│   └── monitoring/             # Scripts de monitoring
│
├── runbooks/                    # 🆕 Procédures opérationnelles
│   └── runbook-site-loss.md    # Runbook perte totale d'un site
│
├── config/                      # Fichiers de configuration
├── logs/                        # Logs des opérations
└── README.md                    # Ce fichier
```

---

## 🚀 Démarrage rapide

### Prérequis

#### Infrastructure OVHcloud

- ✅ 2× Hosted Private Cloud VMware (RBX + SBG)
- ✅ Accès vCenter sur les deux sites (admin@vsphere.local)
- ✅ VMs déjà déployées dans vCenter
- ✅ Licence Zerto activée sur les deux sites
- ✅ Fortigates déployés avec :
  - Tunnels IPsec/BGP vers Azure VPN Gateway (déjà configurés)
  - Accès API REST (port 443)
  - vRack OVHcloud entre RBX et SBG
- ✅ Azure VPN Gateway configuré (gère le failover BGP)

#### Infrastructure Backup (pour protection compensatoire)

- ✅ Veeam Backup & Replication 12+ installé
- ✅ Repository local configuré (RBX + SBG)
- ✅ OVHcloud Public Cloud Project (pour S3)
- ✅ Accès API Veeam REST

#### Outils locaux

```bash
terraform >= 1.0
ansible >= 2.10
jq >= 1.6
curl >= 7.68
git
```

#### Informations nécessaires

**vCenter :**
- URLs des vCenter (ex: `pcc-xxx-xxx.ovh.com`)
- Credentials admin vCenter
- Site IDs Zerto (depuis console Zerto)
- Noms EXACTS des VMs dans vCenter (sensible à la casse)
- Noms des réseaux et datastores vSphere

**Fortigate :**
- IPs management (10.1.0.1 / 10.2.0.1)
- API Keys Fortigate (REST API)
- VIP ranges pour Zerto

**Backup (optionnel) :**
- URL API Veeam (ex: `https://veeam-server:9419`)
- Token API Veeam
- OVHcloud Project ID (pour S3)

---

### Installation

#### 1. Cloner le repository

```bash
git clone https://github.com/votre-org/poc-pra-test.git
cd poc-pra-test/zerto
```

#### 2. Récupérer les informations vCenter

**Se connecter à vCenter RBX et SBG** :
```
https://pcc-xxx-xxx.ovh.com/ui
```

**Noter les informations suivantes** :
- ✅ Noms EXACTS des VMs (sensible à la casse)
- ✅ Nom du datacenter (ex: `pcc-xxx-xxx-xxx-rbx`)
- ✅ Nom du cluster (ex: `Cluster1`)
- ✅ Nom du réseau vSphere (ex: `VM Network`)
- ✅ Nom du datastore pour le journal Zerto (min 240 GB)

**Récupérer les Site IDs Zerto** :
1. Se connecter à la console Zerto
2. Aller dans **Sites > Manage Sites**
3. Noter les Site IDs pour RBX et SBG (UUID)

#### 3. Configurer les variables Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

**Variables principales à remplir** :

```hcl
# vCenter RBX
vcenter_rbx_server     = "pcc-xxx-xxx.ovh.com"
vcenter_rbx_user       = "admin@vsphere.local"
vcenter_rbx_password   = "VOTRE_MOT_DE_PASSE"
vcenter_rbx_datacenter = "pcc-xxx-xxx-rbx"
vcenter_rbx_cluster    = "Cluster1"

# vCenter SBG
vcenter_sbg_server     = "pcc-yyy-yyy.ovh.com"
vcenter_sbg_user       = "admin@vsphere.local"
vcenter_sbg_password   = "VOTRE_MOT_DE_PASSE"
vcenter_sbg_datacenter = "pcc-yyy-yyy-sbg"
vcenter_sbg_cluster    = "Cluster1"

# Zerto
zerto_site_id_rbx = "SITE_ID_DEPUIS_CONSOLE_ZERTO"
zerto_site_id_sbg = "SITE_ID_DEPUIS_CONSOLE_ZERTO"
zerto_rpo_seconds = 300  # 5 minutes

# VMs à protéger (noms EXACTS depuis vCenter)
rbx_protected_vms = [
  {
    name            = "rbx-app-prod-01"
    vm_name_vcenter = "rbx-app-prod-01"  # EXACT name in vCenter
    boot_order      = 2
    failover_ip     = "10.1.1.10"
    failover_subnet = "10.1.1.0/24"
    description     = "Application A - Production RBX"
  }
]

# Fortigate
rbx_fortigate_ip      = "10.1.0.1"
rbx_fortigate_api_key = "VOTRE_API_KEY_RBX"
sbg_fortigate_ip      = "10.2.0.1"
sbg_fortigate_api_key = "VOTRE_API_KEY_SBG"
```

**⚠️ IMPORTANT** : Ne JAMAIS commiter `terraform.tfvars` dans Git (contient des secrets).

#### 4. Déployer l'infrastructure Zerto

```bash
# Initialiser Terraform
terraform init

# Vérifier le plan de déploiement
terraform plan

# Appliquer (créer VPGs + configuration réseau)
terraform apply
```

**Durée estimée** : 15-30 minutes

#### 5. Vérifier le déploiement

```bash
# Retourner au répertoire racine
cd ..

# Vérifier l'état des VPGs
./scripts/check-vpg-status.sh --all --verbose
```

**Attendu** :
```
VPG-RBX-to-SBG: ✅ HEALTHY (Status: MeetingSLA, RPO: 180s)
VPG-SBG-to-RBX: ✅ HEALTHY (Status: MeetingSLA, RPO: 195s)
```

#### 6. Configurer le monitoring automatique (Recommandé)

```bash
# Activer la surveillance automatique toutes les 5 minutes
crontab -e

# Ajouter :
*/5 * * * * /path/to/zerto/scripts/check-vpg-status.sh --all --auto-remediate >> /var/log/zerto/monitoring.log 2>&1
```

**Comportement** :
- Vérifie l'état des VPGs toutes les 5 minutes
- Si un VPG passe en `NotMeetingSLA` → Alerte + Activation backup d'urgence automatique

---

## 🔧 Opérations

### Surveillance quotidienne

```bash
# Health check complet
./scripts/check-vpg-status.sh --all --verbose

# Vérifier les outputs Terraform
cd terraform && terraform output

# Dashboard Grafana
# URL: http://monitoring.local:3000/d/zerto-production
```

**Indicateurs à surveiller** :
- ✅ VPG Status : `MeetingSLA`
- ✅ RPO : < 300 secondes
- ✅ Journal Usage : < 70%
- ✅ Tunnels IPsec vers Azure : `UP`

---

### Gestion des Incidents

#### 🚨 Scénario 1 : Perte Totale du Site RBX

**Impacts** :
- ❌ Application A (RBX) : Indisponible → Nécessite failover vers SBG
- ⚠️ Application B (SBG) : Fonctionne mais **non protégée** (réplication vers RBX impossible)

**Actions automatiques** :

1. **Détection** (T+0 à T+5 min)
   - Script `check-vpg-status.sh` détecte VPG `NotMeetingSLA`
   - Alerte envoyée (Slack/Email)

2. **Failover Application A** (T+5 à T+20 min)
   ```bash
   ./scripts/failover-rbx-to-sbg.sh --force --vpg VPG-RBX-to-SBG
   ```
   - VMs Application A démarrées sur SBG
   - Routes statiques ajoutées sur Fortigate SBG
   - Azure VPN Gateway bascule automatiquement vers tunnel SBG (BGP)

3. **Protection Compensatoire Application B** (T+20 à T+90 min)
   ```bash
   # Activation automatique (si --auto-remediate activé)
   # Sinon, lancer manuellement :
   ansible-playbook ansible/playbooks/activate-emergency-backup.yml \
     -e "app_name=Application-B" \
     -e "site=SBG"
   ```
   - Création bucket S3 immuable (région GRA)
   - Création job Veeam Local (backup toutes les 12h)
   - Création job Veeam S3 (copie immuable 30j)
   - Premier backup complet lancé immédiatement

**Résultat** :
- ✅ Application A : Disponible sur SBG (RTO < 30 min)
- ✅ Application B : Protégée par backup (RPO 12h max)

**Suivre le runbook détaillé** : `runbooks/runbook-site-loss.md`

---

#### 🚨 Scénario 2 : Perte Totale du Site SBG

**Procédure identique mais inversée** :

```bash
# Failover Application B vers RBX
./scripts/failover-sbg-to-rbx.sh --force --vpg VPG-SBG-to-RBX

# Activation backup urgence Application A
ansible-playbook ansible/playbooks/activate-emergency-backup.yml \
  -e "app_name=Application-A" \
  -e "site=RBX"
```

---

#### ✅ Retour à la Normale

**Quand le site KO revient en ligne** :

1. **Détection automatique** (T+0)
   - Script détecte le retour du site
   - Zerto commence la resynchronisation (Delta Sync)

2. **Resynchronisation** (T+0 à T+X heures)
   ```bash
   # Surveiller la progression
   watch -n 60 './scripts/check-vpg-status.sh --vpg VPG-SBG-to-RBX'
   ```
   - Zerto transfère uniquement les différences (Bitmap)
   - Durée dépend du volume modifié pendant l'incident

3. **Validation** (T+X heures)
   ```bash
   # Vérifier RPO < 5 min
   ./scripts/check-vpg-status.sh --all
   ```

4. **Décision Backups d'urgence** (T+X+1 heures)

   **Option A (Recommandée)** : Conserver les backups (double protection)
   - Coût : ~€8/mois S3
   - Avantage : Protection renforcée contre ransomware

   **Option B** : Désactiver les backups
   ```bash
   ansible-playbook ansible/playbooks/deactivate-emergency-backup.yml \
     -e "app_name=Application-B" \
     -e "confirm=yes"
   ```

**Suivre le runbook complet** : `runbooks/runbook-site-loss.md` (section "Phase 4")

---

## 📊 Architecture Détaillée

### Architecture Réseau

**Topologie Hub-and-Spoke avec Azure** :

```
                  ┌───────────────────────┐
                  │   Azure VPN Gateway   │
                  │   BGP Hub (Failover)  │
                  └──────────┬────────────┘
                             │
              ┌──────────────┼──────────────┐
              │ Tunnel IPsec │ Tunnel IPsec │
              │ BGP Primary  │ BGP Backup   │
              │              │              │
┌─────────────▼──────┐      │      ┌───────▼─────────────┐
│   Fortigate RBX    │      │      │   Fortigate SBG     │
│   10.1.0.1         │◄─────┼──────►   10.2.0.1          │
│   (Primary)        │  vRack       │   (Backup)          │
└─────────┬──────────┘              └──────────┬──────────┘
          │                                    │
┌─────────▼────────────┐          ┌───────────▼──────────┐
│  OVHcloud RBX        │          │  OVHcloud SBG        │
│  ┌────────────────┐  │          │  ┌────────────────┐  │
│  │ Application A  │  │◄────────►│  │ Application B  │  │
│  │ (Production)   │  │  Zerto   │  │ (Production)   │  │
│  │ + Réplica B    │  │  VRA     │  │ + Réplica A    │  │
│  └────────────────┘  │          │  └────────────────┘  │
│  VMware vSphere      │          │  VMware vSphere      │
└──────────────────────┘          └──────────────────────┘
```

**Points clés** :
- ✅ **BGP Hub** : Azure gère le failover automatiquement (RBX primary, SBG backup)
- ✅ **vRack** : Interconnexion privée RBX ⟷ SBG (trafic SBG → RBX → Azure)
- ✅ **Zerto** : Réplication continue des VMs (indépendant du réseau)
- ⚠️ **Pas de BGP entre Fortigates** : Ils se connectent à Azure, PAS entre eux

### Flux Réseau

**Mode Normal (RBX Primary)** :
```
VMs RBX → Fortigate RBX → Tunnel IPsec → Azure VPN Gateway
VMs SBG → vRack → Fortigate RBX → Tunnel IPsec → Azure VPN Gateway
```

**Après Failover (SBG Active)** :
```
VMs SBG (+ VMs failovées RBX) → Fortigate SBG → Tunnel IPsec → Azure VPN Gateway
Routes statiques ajoutées sur Fortigate SBG pour IPs 10.1.x.x
```

### Composants Zerto

- **Virtual Protection Groups (VPG)** : Groupes de VMs protégées ensemble
  - `VPG-RBX-to-SBG` : Protection Application A
  - `VPG-SBG-to-RBX` : Protection Application B

- **Virtual Replication Appliances (VRA)** : Appliances de réplication (1 par ESXi)
  - Gèrent la réplication au niveau bloc
  - Mode Bitmap si site cible inaccessible

- **Journal Zerto** : Historique des modifications (24h de rétention)
  - Point-in-time recovery
  - Consommation : ~10% de la taille VM

### Module Emergency Backup

**Architecture de protection compensatoire** :

```
Site SBG (Survivant après perte RBX)
  │
  │  Application B (Production) - NON PROTÉGÉE
  │
  ├──► Backup Local (Veeam)
  │    └─ Repository SBG
  │       └─ RPO: 12h, Rétention: 7 jours
  │
  └──► Backup S3 Immuable (Veeam)
       └─ Bucket OVHcloud GRA (hors site)
          └─ RPO: 12h, Rétention: 30j
             └─ Object Lock COMPLIANCE (WORM)
                └─ Protection ransomware
```

**Déclenchement** : Automatique sur détection VPG `NotMeetingSLA`

---

## 📚 Documentation

Documentation complète dans `Documentation/zerto/` :

### 1. Documentation Technique (40+ pages)
**Fichier** : `../Documentation/zerto/01-implementation-technique.md`

**Contenu** :
- Architecture technique détaillée (diagrammes)
- Installation et configuration complète
- Infrastructure as Code (Terraform)
- Configuration réseau (Fortigate, Azure VPN Gateway)
- Monitoring et alertes (Grafana)
- Troubleshooting et FAQ

### 2. Guide Fonctionnel (40+ pages)
**Fichier** : `../Documentation/zerto/02-guide-fonctionnel.md`

**Contenu** :
- Opérations quotidiennes
- Procédures de failover/failback
- Gestion des incidents
- Tests et validation
- Maintenance et mise à jour

### 3. Analyse Perte Site Active/Active (50+ pages) 🆕
**Fichier** : `../Documentation/zerto/03-analyse-perte-site-active-active.md`

**Contenu** :
- Comportement technique Zerto (mode Bitmap)
- Analyse risque "Double Peine" (matrice détaillée)
- Stratégies de mitigation (Local + S3)
- Procédure retour à la normale (Delta Sync)
- Recommandations opérationnelles

### 4. Runbook Opérationnel (60+ pages) 🆕
**Fichier** : `runbooks/runbook-site-loss.md`

**Contenu** :
- Phase 1 : Détection (0-15 min)
- Phase 2 : Actions immédiates (15-60 min)
- Phase 3 : Surveillance continue (quotidien)
- Phase 4 : Retour à la normale
- Checklist complète + Contacts escalade

---

## 🔍 Monitoring

### Dashboard Grafana

**URL** : `http://monitoring.local:3000/d/zerto-production`

**Métriques surveillées** :
- ✅ État des VPGs en temps réel (MeetingSLA / NotMeetingSLA)
- ✅ RPO actuel vs cible (5 minutes)
- ✅ Utilisation du journal Zerto (%)
- ✅ Bande passante de réplication (Mbps)
- ✅ État des tunnels IPsec vers Azure
- ✅ Backups d'urgence (si activés)

### Alertes

**Notifications via** :
- 📧 Email : Configuré dans `alert_emails`
- 💬 Webhook : Slack/Teams configuré dans `alert_webhook_url`

**Seuils** :

| Métrique | Warning | Critical | Action |
|----------|---------|----------|--------|
| **RPO** | > 450s | > 600s | Investigation immédiate |
| **VPG Status** | - | NotMeetingSLA | Activation backup urgence |
| **Journal Usage** | > 70% | > 85% | Augmenter datastore |
| **Backup Job** | - | Failed | Relancer backup |

### Script de Monitoring Automatique 🆕

**Fichier** : `scripts/check-vpg-status.sh`

**Fonctionnalités** :
- ✅ Vérification état VPGs via API Zerto
- ✅ Détection automatique `NotMeetingSLA`
- ✅ Alertes webhook + email
- ✅ Activation backup d'urgence (avec `--auto-remediate`)
- ✅ Logs détaillés

**Usage** :
```bash
# Vérifier tous les VPGs
./scripts/check-vpg-status.sh --all --verbose

# Mode automatique (activation backup si nécessaire)
./scripts/check-vpg-status.sh --all --auto-remediate

# Vérifier un VPG spécifique
./scripts/check-vpg-status.sh --vpg VPG-SBG-to-RBX
```

**Cron recommandé** :
```bash
*/5 * * * * /path/to/zerto/scripts/check-vpg-status.sh --all --auto-remediate
```

---

## 🛠️ Maintenance

### Ajouter une VM à protéger

1. **Identifier la VM dans vCenter**
   - Nom EXACT (sensible à la casse)
   - IP de failover à assigner

2. **Éditer** `terraform/terraform.tfvars`
   ```hcl
   rbx_protected_vms = [
     # ... VMs existantes ...
     {
       name            = "rbx-new-vm"
       vm_name_vcenter = "rbx-new-vm"  # EXACT
       boot_order      = 3
       failover_ip     = "10.1.1.30"
       failover_subnet = "10.1.1.0/24"
       description     = "Nouvelle VM application"
     }
   ]
   ```

3. **Appliquer**
   ```bash
   cd terraform
   terraform plan  # Vérifier les changements
   terraform apply
   ```

4. **Valider**
   ```bash
   cd ..
   ./scripts/check-vpg-status.sh --vpg VPG-RBX-to-SBG
   ```

### Modifier le RPO

```bash
# Éditer terraform.tfvars
nano terraform/terraform.tfvars

# Modifier la valeur (ex: 10 minutes = 600 secondes)
zerto_rpo_seconds = 600

# Appliquer
terraform apply
```

### Mise à jour de la configuration

```bash
# 1. Modifier la configuration
nano terraform/terraform.tfvars

# 2. Vérifier les changements
terraform plan

# 3. Appliquer
terraform apply

# 4. Valider
./scripts/check-vpg-status.sh --all
```

---

## 🔐 Sécurité

### Secrets Management

**⚠️ CRITICAL** : Ne JAMAIS commiter ces fichiers dans Git :
- ❌ `terraform/terraform.tfvars` (credentials vCenter, API keys)
- ❌ `~/.ansible/vault_pass.txt` (mot de passe Ansible Vault)
- ❌ Fichiers `.env` (variables d'environnement)

**Solutions recommandées** :
- ✅ **Terraform Cloud** : Stockage sécurisé des variables
- ✅ **HashiCorp Vault** : Gestion centralisée des secrets
- ✅ **Ansible Vault** : Chiffrement des playbooks
- ✅ **Variables d'environnement** : Export via `.env` non versionné

### Chiffrement

| Composant | Méthode | Description |
|-----------|---------|-------------|
| **Zerto - Transit** | AES-256 | Réplication chiffrée |
| **Zerto - Journal** | AES-256 | Données au repos |
| **Backup Local** | AES-256 | Veeam encryption |
| **Backup S3** | AES-256 | Server-side + Transit TLS |
| **S3 Immutable** | Object Lock | WORM 30 jours (ransomware) |
| **API** | TLS 1.3 | HTTPS uniquement |

### Conformité

- ✅ **RGPD** : Données hébergées en France (RBX, SBG, GRA)
- ✅ **ISO 27001** : OVHcloud certifié
- ✅ **SOC 2** : Zerto certifié
- ✅ **Immutabilité** : S3 Object Lock (protection ransomware)

---

## 🧪 Tests

### Test Mensuel (Obligatoire)

**Objectif** : Valider la capacité de failover sans impact production

```bash
# Test failover en environnement isolé (Zerto Test Failover)
./scripts/test-failover.sh --vpg VPG-RBX-to-SBG --isolated

# Valider :
# - VMs démarrent correctement
# - Connectivité réseau OK
# - Applications fonctionnelles

# Nettoyer
./scripts/test-failover.sh --vpg VPG-RBX-to-SBG --cleanup
```

**Rapport à produire** :
- Date et heure du test
- VPG testé
- Résultat (Success/Failure)
- RTO observé
- Actions correctives si besoin

### Test Trimestriel (Recommandé)

**Objectif** : Failover réel planifié

**Procédure** :
1. Planifier une fenêtre de maintenance (ex: Dimanche 02:00-06:00)
2. Notifier les équipes applicatives
3. Exécuter le failover réel
4. Valider toutes les applications
5. Exécuter le failback
6. Post-mortem et rapport

### Test Annuel (Obligatoire)

**Objectif** : Simulation perte totale d'un site

**Procédure** :
1. Désactiver manuellement un site (ex: RBX)
2. Suivre le runbook `runbooks/runbook-site-loss.md`
3. Valider failover + backup d'urgence
4. Laisser en mode dégradé pendant 24h
5. Réactiver le site et valider resynchronisation
6. Rapport complet avec métriques (RTO/RPO réels)

---

## 📈 Métriques et KPIs

### Indicateurs de Performance

| Métrique | Cible | Mesure | Fréquence |
|----------|-------|--------|-----------|
| **Disponibilité globale** | 99.9% | Monitoring uptime | Continue |
| **RPO moyen** | < 5 min | Dashboard Zerto | Continue |
| **RTO Failover** | < 15 min | Tests mensuels | Mensuel |
| **RPO Backup urgence** | < 12h | Veeam logs | Si activé |
| **Tests réussis** | 100% | Rapports | Mensuel |
| **Incidents majeurs** | 0/an | Tickets | Annuel |

### Rapports

**Mensuel** :
- Nombre de tests failover
- RPO moyen observé
- Incidents et résolutions
- Espace disque journal Zerto

**Trimestriel** :
- Résultats test failover réel
- Évolution des métriques
- Recommandations d'amélioration

**Annuel** :
- Test simulation perte site
- Coûts infrastructure DR
- Audit conformité
- Roadmap évolutions

---

## 🆘 Support

### Contacts Internes

**Niveau 1 - Ops (0-30 min)** :
- Email : ops-team@exemple.com
- Slack : #ops-incidents
- Téléphone : +33 X XX XX XX XX
- Disponibilité : 24/7

**Niveau 2 - Infrastructure (30 min - 2h)** :
- Email : infra-team@exemple.com
- Slack : #infra-critical
- Téléphone : +33 X XX XX XX XX
- Disponibilité : 24/7

**Niveau 3 - Management / Crise (2h+)** :
- Email : cto@exemple.com
- Téléphone : +33 X XX XX XX XX
- Disponibilité : Sur appel

### Support Externe

**OVHcloud Support** :
- URL : https://www.ovh.com/manager/dedicated/#/support
- Téléphone : +33 9 72 10 10 07
- Email : support@ovh.com
- Contrat : Premium 24/7

**Zerto Support** :
- URL : https://www.zerto.com/support/
- Email : support@zerto.com
- Téléphone : +1-617-456-9200
- Contrat : Enterprise Support

**Fortigate Support** :
- URL : https://support.fortinet.com/
- Email : support@fortinet.com
- Contrat : FortiCare Premium

---

## 📝 Changelog

### Version 2.0 (2025-12-17) 🆕

**Nouvelles fonctionnalités** :
- ✨ Architecture Active/Active avec protection "Double Peine"
- ✨ Module emergency-backup (Terraform)
- ✨ Playbook Ansible activation backup automatique
- ✨ Script monitoring `check-vpg-status.sh` avec auto-remediation
- ✨ Runbook opérationnel perte de site (60+ pages)
- ✨ Documentation analyse risque Active/Active (50+ pages)

**Corrections architecture** :
- 🔧 Correction architecture réseau (Azure VPN Gateway hub)
- 🔧 Suppression BGP entre Fortigates (BGP vers Azure uniquement)
- 🔧 Clarification flux réseau avec vRack

**Améliorations** :
- 📚 Documentation technique enrichie (Azure BGP)
- 📚 Guide failover/failback mis à jour
- 📚 README complet avec nouveaux modules

### Version 1.0 (2025-12-17)

- ✨ Implémentation initiale Zerto
- ✨ Terraform pour déploiement automatisé (VMware vSphere)
- ✨ Scripts de failover/failback
- ✨ Monitoring avec Grafana
- ✨ Documentation technique et fonctionnelle (80+ pages)

---

## 🤝 Contribution

Pour contribuer au projet :

1. **Créer une branche feature**
   ```bash
   git checkout -b feature/ma-nouvelle-fonctionnalite
   ```

2. **Implémenter les changements**
   - Respecter les conventions de code
   - Ajouter des tests si applicable
   - Mettre à jour la documentation

3. **Tester localement**
   ```bash
   terraform validate
   terraform plan
   # Tester les scripts
   ```

4. **Créer une Pull Request**
   - Décrire les changements
   - Ajouter des captures d'écran si pertinent
   - Référencer les issues liées

5. **Validation par l'équipe SRE**
   - Code review
   - Tests d'intégration
   - Merge vers main

---

## 📄 Licence

**Propriétaire** - Usage interne uniquement

Ce code et cette documentation sont la propriété exclusive de l'entreprise. Toute reproduction, distribution ou utilisation en dehors du cadre interne est strictement interdite.

---

## 🙏 Remerciements

- **Équipe Infrastructure OVHcloud** : Support et expertise
- **Support Zerto** : Assistance technique
- **Équipe SRE** : Développement et maintenance
- **Claude (Anthropic)** : Assistance IA pour documentation et automatisation

---

**Maintenu par** : Équipe Infrastructure & SRE
**Dernière mise à jour** : 2025-12-17
**Version** : 2.0

Pour toute question, consulter la [documentation complète](../Documentation/zerto/) ou contacter l'équipe SRE.

---

## 🔗 Liens Utiles

- 📖 [Documentation Technique](../Documentation/zerto/01-implementation-technique.md)
- 📖 [Guide Fonctionnel](../Documentation/zerto/02-guide-fonctionnel.md)
- 📖 [Analyse Perte Site Active/Active](../Documentation/zerto/03-analyse-perte-site-active-active.md)
- 📋 [Runbook Perte Site](runbooks/runbook-site-loss.md)
- 🔧 [Module Emergency Backup](terraform/modules/emergency-backup/README.md)
- 🌐 [Documentation Officielle Zerto](https://www.zerto.com/documentation/)
- 🌐 [API Zerto](https://www.zerto.com/page/api-documentation/)
- 🌐 [Terraform vSphere Provider](https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs)
