# Zerto Disaster Recovery - RBX ⟷ SBG

Solution de Plan de Reprise d'Activité (PRA) basée sur Zerto pour la réplication bi-directionnelle entre les régions OVHcloud RBX (Roubaix) et SBG (Strasbourg).

> **📌 Plateforme** : Cette solution est conçue pour **OVHcloud Hosted Private Cloud (VMware vSphere)**
> Les VMs protégées doivent être hébergées sur l'infrastructure VMware (non compatible avec Public Cloud OpenStack).

## 🎯 Vue d'ensemble

Cette solution protège vos applications critiques avec :

- **RPO : 5 minutes** - Perte de données maximale
- **RTO : 15 minutes** - Temps de restauration maximal
- **Réplication bi-directionnelle** - Chaque site peut servir de principal ou secours
- **Failover automatisé** - Scripts d'orchestration pour bascule rapide
- **Failback simplifié** - Retour à la normale en un clic
- **Infrastructure as Code** - Terraform + Ansible pour déploiement reproductible

## 📁 Structure du projet

```
zerto/
├── terraform/              # Infrastructure as Code
│   ├── main.tf            # Configuration principale (VMware vSphere)
│   ├── variables.tf       # Variables Terraform (vCenter)
│   ├── outputs.tf         # Sorties Terraform
│   ├── terraform.tfvars.example  # Exemple configuration VMware
│   └── modules/           # Modules Terraform
│       ├── zerto-vpg-vmware/  # Virtual Protection Groups (VMware)
│       ├── zerto-network/ # Configuration réseau/Fortigate
│       └── zerto-monitoring/  # Monitoring et alertes
│
├── ansible/               # Configuration management
│   ├── playbooks/         # Playbooks Ansible
│   │   ├── deploy-zerto.yml         # Déploiement principal
│   │   └── configure-fortigate.yml  # Configuration Fortigate
│   └── roles/             # Rôles Ansible (à venir)
│
├── scripts/               # Scripts d'orchestration
│   ├── failover-rbx-to-sbg.sh  # Failover RBX → SBG
│   ├── failover-sbg-to-rbx.sh  # Failover SBG → RBX
│   ├── failback.sh             # Retour à la normale
│   └── monitoring/             # Scripts de monitoring
│
├── config/                # Fichiers de configuration
├── logs/                  # Logs des opérations
└── README.md              # Ce fichier
```

## 🚀 Démarrage rapide

### Prérequis

**Infrastructure OVHcloud** :
- 2x Hosted Private Cloud VMware (RBX + SBG)
- Accès vCenter sur les deux sites
- VMs déjà déployées dans vCenter
- Licence Zerto activée sur les deux sites
- Fortigates déployés avec accès API

**Outils locaux** :
- Terraform >= 1.0
- Ansible >= 2.10
- jq (pour parsing JSON)
- curl

**Informations nécessaires** :
- URLs des vCenter (ex: pcc-xxx-xxx.ovh.com)
- Credentials admin vCenter
- Site IDs Zerto (depuis console Zerto)
- Noms EXACTS des VMs dans vCenter
- Noms des réseaux et datastores vSphere

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

**Noter** :
- Noms EXACTS des VMs (sensible à la casse)
- Nom du datacenter (ex: "pcc-xxx-xxx-xxx-rbx")
- Nom du cluster (ex: "Cluster1")
- Nom du réseau (ex: "VM Network")
- Nom du datastore pour le journal Zerto

**Récupérer les Site IDs Zerto** :
- Se connecter à la console Zerto
- Aller dans **Sites > Manage Sites**
- Noter les Site IDs pour RBX et SBG

#### 3. Configurer les variables Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

Remplir les valeurs :
- URLs et credentials vCenter (RBX + SBG)
- Site IDs Zerto
- Noms exacts des VMs depuis vCenter
- Noms des réseaux et datastores
- Configuration Fortigate (API keys)

#### 4. Déployer l'infrastructure

```bash
# Initialiser Terraform
terraform init

# Vérifier le plan
terraform plan

# Appliquer
terraform apply
```

#### 4. Vérifier le déploiement

```bash
# Vérifier l'état des VPGs
cd ..
./scripts/monitoring/health-check.sh
```

## 🔧 Opérations

### Vérification quotidienne

```bash
# Health check automatisé
./scripts/monitoring/health-check.sh

# Vérifier les outputs Terraform
cd terraform && terraform output
```

### Test mensuel

```bash
# Test failover (sans impact production)
./scripts/test-failover.sh --vpg rbx-to-sbg
```

### En cas d'incident

#### Scénario 1 : Site RBX indisponible

```bash
# Failover vers SBG
./scripts/failover-rbx-to-sbg.sh
```

#### Scénario 2 : Site SBG indisponible

```bash
# Failover vers RBX
./scripts/failover-sbg-to-rbx.sh
```

#### Retour à la normale

```bash
# Failback après résolution
./scripts/failback.sh --from sbg --to rbx
```

## 📊 Architecture

### Vue d'ensemble

```
┌─────────────────────────┐          ┌─────────────────────────┐
│   RBX (Roubaix)         │          │   SBG (Strasbourg)      │
│                         │          │                         │
│  ┌──────────────────┐   │          │   ┌──────────────────┐  │
│  │ App Server       │   │          │   │ App Server       │  │
│  │ DB Server        │   │◄────────►│   │ DB Server        │  │
│  └──────────────────┘   │          │   └──────────────────┘  │
│          │              │   Zerto   │           │             │
│  ┌───────▼──────┐       │ Replication│   ┌──────▼──────┐     │
│  │ Fortigate    │       │  RPO 5min │   │ Fortigate   │     │
│  │ 10.1.0.1     │◄──────┴───BGP────►│   │ 10.2.0.1    │     │
│  └──────────────┘       │            │   └─────────────┘     │
└─────────────────────────┘            └─────────────────────────┘
```

### Composants

- **Virtual Protection Groups (VPG)** : Groupes de VMs protégées ensemble
- **Virtual Replication Appliances (VRA)** : Appliances de réplication Zerto
- **Fortigate** : Firewall avec routage BGP
- **BGP** : Protocole de routage dynamique pour failover automatique

## 📚 Documentation

Documentation complète disponible dans `Documentation/zerto/` :

1. **[Documentation technique](../Documentation/zerto/01-implementation-technique.md)**
   - Architecture détaillée
   - Installation et configuration
   - Infrastructure as Code
   - Réseau et sécurité

2. **[Guide fonctionnel](../Documentation/zerto/02-guide-fonctionnel.md)**
   - Opérations quotidiennes
   - Gestion des incidents
   - Tests et validation
   - FAQ

## 🔍 Monitoring

### Dashboard Grafana

URL : `http://monitoring.local:3000/d/zerto-production`

Métriques surveillées :
- État des VPGs en temps réel
- RPO actuel vs cible
- Utilisation du journal
- Bande passante de réplication
- État du peering BGP

### Alertes

Notifications envoyées via :
- Email (configuré dans `alert_emails`)
- Webhook Slack/Teams (configuré dans `alert_webhook_url`)

Seuils :
- **Warning** : RPO > 450s, Journal > 70%
- **Critical** : RPO > 600s, Journal > 85%

## 🛠️ Maintenance

### Ajouter une VM à protéger

1. Éditer `terraform/terraform.tfvars`
2. Ajouter la VM dans `rbx_protected_vms` ou `sbg_protected_vms`
3. Appliquer : `terraform apply`

### Modifier le RPO

1. Éditer `terraform/terraform.tfvars`
2. Modifier `zerto_rpo_seconds`
3. Appliquer : `terraform apply`

### Mise à jour de la configuration

```bash
# Modifier la configuration
nano terraform/terraform.tfvars

# Vérifier les changements
terraform plan

# Appliquer
terraform apply
```

## 🔐 Sécurité

### Secrets management

**IMPORTANT** : Ne jamais commiter `terraform.tfvars` dans Git !

Ce fichier contient :
- Credentials OVH API
- API Keys Fortigate
- Tokens Zerto

Utiliser :
- Terraform Cloud pour stocker les secrets
- HashiCorp Vault
- Variables d'environnement

### Chiffrement

- **Données en transit** : AES-256 (Zerto) + TLS 1.2+
- **Données au repos** : Journal Zerto chiffré
- **Communications API** : HTTPS uniquement

## 🧪 Tests

### Test mensuel obligatoire

```bash
# Test failover en environnement isolé
./scripts/test-failover.sh --vpg rbx-to-sbg
```

### Test trimestriel

Failover réel planifié avec :
- Fenêtre de maintenance
- Équipes applicatives disponibles
- Validation complète

## 📈 Métriques et KPIs

| Métrique | Cible | Méthode de mesure |
|----------|-------|-------------------|
| Disponibilité | 99.9% | Monitoring uptime |
| RPO moyen | < 5 min | Dashboard Zerto |
| Temps de failover | < 15 min | Tests réguliers |
| Tests mensuels | 1/mois | Rapports |

## 🆘 Support

### Contacts internes

- **Ops L1** : ops@exemple.com
- **SRE L2** : sre@exemple.com
- **Manager IT** : manager@exemple.com
- **Astreinte** : +33 X XX XX XX XX

### Support externe

- **OVH Support** : https://www.ovh.com/manager
- **Zerto Support** : support@zerto.com
- **Fortigate Support** : support@fortinet.com

## 📝 Changelog

### Version 1.0 (2025-12-17)

- ✨ Implémentation initiale
- ✨ Terraform pour déploiement automatisé
- ✨ Scripts de failover/failback
- ✨ Monitoring avec Grafana
- ✨ Documentation complète
- ✨ Configuration réseau avec BGP

## 🤝 Contribution

Pour contribuer :

1. Créer une branche feature
2. Implémenter les changements
3. Tester localement
4. Créer une Pull Request
5. Validation par l'équipe SRE

## 📄 Licence

Propriétaire - Usage interne uniquement

## 🙏 Remerciements

- Équipe Infrastructure OVHcloud
- Support Zerto
- Équipe SRE

---

**Maintenu par** : Équipe Infrastructure & SRE
**Dernière mise à jour** : 2025-12-17
**Version** : 1.0

Pour toute question, consulter la [documentation complète](../Documentation/zerto/) ou contacter l'équipe SRE.
