# Documentation Technique - Implémentation Zerto sur OVHcloud

## Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Architecture technique](#architecture-technique)
3. [Prérequis](#prérequis)
4. [Installation et configuration](#installation-et-configuration)
5. [Infrastructure as Code](#infrastructure-as-code)
6. [Configuration réseau](#configuration-réseau)
7. [Monitoring et alertes](#monitoring-et-alertes)
8. [Sécurité](#sécurité)
9. [Dépannage](#dépannage)

---

## 1. Vue d'ensemble

### 1.1 Objectif

Cette implémentation met en place une solution de Plan de Reprise d'Activité (PRA) et de Plan de Reprise Informatique (PRI) basée sur Zerto entre deux régions OVHcloud :

- **RBX (Roubaix)** ⟷ **SBG (Strasbourg)**

### 1.2 Fonctionnalités

- Réplication bi-directionnelle des VMs
- RPO de 5 minutes (configurable)
- Failover automatisé
- Failback simplifié
- Reconfiguration réseau automatique via Fortigate
- Monitoring et alertes en temps réel

### 1.3 Technologies utilisées

| Technologie | Version | Usage |
|-------------|---------|-------|
| Terraform | >= 1.0 | Infrastructure as Code |
| Ansible | >= 2.10 | Configuration management |
| Zerto | 9.x | Réplication et DR |
| Fortigate | 7.x | Réseau et routage (BGP vers Azure) |
| Bash | 5.x | Scripts d'orchestration |

---

## 2. Architecture technique

### 2.1 Architecture globale

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
┌───────────────▼──────┐      │      ┌───────▼─────────────┐
│   Fortigate RBX      │      │      │   Fortigate SBG     │
│   10.1.0.1           │◄─────┼──────►   10.2.0.1          │
│   (Primary)          │  vRack       │   (Backup)          │
└──────────┬───────────┘              └──────────┬──────────┘
           │                                     │
┌──────────▼────────────┐          ┌────────────▼──────────┐
│  OVHcloud RBX         │          │  OVHcloud SBG         │
│  ┌─────────────────┐  │          │  ┌─────────────────┐  │
│  │ VMs Production  │  │◄────────►│  │ VMs Production  │  │
│  │ - App Server    │  │  Zerto   │  │ - App Server    │  │
│  │ - DB Server     │  │  VRA     │  │ - DB Server     │  │
│  └─────────────────┘  │          │  └─────────────────┘  │
│  VMware vSphere       │          │  VMware vSphere       │
└───────────────────────┘          └───────────────────────┘
```

**Notes importantes** :
- Les Fortigates sont connectés à Azure VPN Gateway (hub), PAS entre eux
- Azure gère le failover BGP automatiquement (RBX primary, SBG backup)
- Le trafic SBG vers Azure transite par vRack puis Fortigate RBX en mode normal
- Lors d'un failover Zerto, des routes statiques sont ajoutées au Fortigate SBG

### 2.2 Composants Zerto

#### Virtual Protection Groups (VPG)

Deux VPGs sont configurés :

1. **VPG-RBX-to-SBG** : Protection des VMs RBX vers SBG
2. **VPG-SBG-to-RBX** : Protection des VMs SBG vers RBX

#### Virtual Replication Appliances (VRA)

- Déployées automatiquement par Zerto
- Une VRA par hyperviseur
- Gèrent la réplication au niveau block

### 2.3 Flux de réplication

```
VM Source → VRA Source → WAN → VRA Cible → VM Répliquée
              │                    │
              ▼                    ▼
         Compression          Journal
         Encryption          (24h)
```

### 2.4 Réseau

#### Plages IP

| Site | Réseau | Gateway | Plage VMs |
|------|--------|---------|-----------|
| RBX | 10.1.0.0/16 | 10.1.0.1 | 10.1.1.0/24 |
| SBG | 10.2.0.0/16 | 10.2.0.1 | 10.2.1.0/24 |

#### Ports Zerto

| Port | Protocol | Usage |
|------|----------|-------|
| 9071 | TCP | VSS to ZVM |
| 9072 | TCP | ZVM to VSS |
| 9073 | TCP | Zerto GUI |
| 4007 | TCP | VRA to VRA |
| 4008 | TCP | VRA to VRA |

#### Configuration réseau Fortigate

**Connexion à Azure VPN Gateway** :
- **RBX** : Tunnel IPsec/BGP Primary vers Azure
- **SBG** : Tunnel IPsec/BGP Backup vers Azure
- **vRack** : Interconnexion privée RBX ⟷ SBG

**Routes statiques de failover** :
- Ajoutées dynamiquement au Fortigate SBG lors du failover RBX → SBG
- Ajoutées dynamiquement au Fortigate RBX lors du failover SBG → RBX
- Permettent le routage des VMs basculées avec leurs IPs d'origine

---

## 3. Prérequis

### 3.1 Infrastructure OVHcloud

- Compte OVHcloud Hosted Private Cloud (VMware vSphere) actif
- vCenter RBX et SBG configurés et accessibles
- Accès administrateur vSphere (admin@vsphere.local)
- Régions RBX et SBG activées

### 3.2 Accès Zerto

- Licence Zerto valide
- Accès à la console Zerto OVHcloud
- Credentials API Zerto
- Site IDs pour RBX et SBG

### 3.3 Réseau

- VLANs configurés sur les deux sites VMware
- Fortigate déployés avec tunnels IPsec/BGP vers Azure VPN Gateway
- Clés API Fortigate pour configuration automatique
- vRack OVHcloud pour interconnexion privée RBX ⟷ SBG
- Azure VPN Gateway configuré (gère le failover BGP automatiquement)

### 3.4 Outils locaux

```bash
# Versions minimales requises
terraform >= 1.0
ansible >= 2.10
jq >= 1.6
curl >= 7.68
bash >= 5.0
```

### 3.5 VMs à protéger

Liste des VMs existantes avec leurs IDs :

**RBX :**
- `rbx-app-prod-01` : Instance ID à récupérer
- `rbx-db-prod-01` : Instance ID à récupérer

**SBG :**
- `sbg-app-prod-01` : Instance ID à récupérer
- `sbg-db-prod-01` : Instance ID à récupérer

---

## 4. Installation et configuration

### 4.1 Clonage du repository

```bash
git clone https://github.com/votre-org/poc-pra-test.git
cd poc-pra-test/zerto
```

### 4.2 Configuration des variables

#### Étape 1 : Copier le fichier d'exemple

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

#### Étape 2 : Éditer terraform.tfvars

```bash
nano terraform.tfvars
```

Remplir les valeurs suivantes :

```hcl
# OVH Cloud
ovh_application_key    = "VOTRE_KEY"
ovh_application_secret = "VOTRE_SECRET"
ovh_consumer_key       = "VOTRE_CONSUMER_KEY"
ovh_project_id         = "VOTRE_PROJECT_ID"

# Zerto
zerto_site_id_rbx = "SITE_ID_RBX"
zerto_site_id_sbg = "SITE_ID_SBG"

# VMs à protéger (récupérer les IDs depuis la console OVH)
rbx_protected_vms = [
  {
    name           = "rbx-app-prod-01"
    instance_id    = "xxxxx-xxxxx-xxxxx"
    boot_order     = 2
    failover_ip    = "10.1.1.10"
    failover_subnet = "10.1.1.0/24"
    description    = "App Server RBX"
  },
  {
    name           = "rbx-db-prod-01"
    instance_id    = "xxxxx-xxxxx-xxxxx"
    boot_order     = 1
    failover_ip    = "10.1.1.20"
    failover_subnet = "10.1.1.0/24"
    description    = "DB Server RBX"
  }
]

# Répéter pour sbg_protected_vms...

# Fortigate
rbx_fortigate_ip      = "10.1.0.1"
rbx_fortigate_api_key = "VOTRE_API_KEY_RBX"
sbg_fortigate_ip      = "10.2.0.1"
sbg_fortigate_api_key = "VOTRE_API_KEY_SBG"

# Alertes
alert_emails = ["ops@example.com"]
```

### 4.3 Récupération des IDs OVH

#### Instances IDs

```bash
# Lister les instances RBX
openstack --os-region-name=GRA7 server list

# Lister les instances SBG
openstack --os-region-name=SBG5 server list
```

#### Network IDs

```bash
# Lister les réseaux
openstack network list

# Récupérer les détails
openstack network show <NETWORK_NAME>
```

### 4.4 Configuration Zerto

#### Récupérer les Site IDs

1. Se connecter à la console Zerto : https://zerto.ovhcloud.com
2. Aller dans **Sites** > **Manage Sites**
3. Noter les Site IDs pour RBX et SBG

#### Créer les credentials API

1. Dans la console Zerto : **Administration** > **API Access**
2. Générer un token API
3. Exporter les variables :

```bash
export ZERTO_API_TOKEN="votre_token"
# OU
export ZERTO_USERNAME="admin"
export ZERTO_PASSWORD="password"
```

### 4.5 Configuration Fortigate

#### Générer les API Keys

Sur chaque Fortigate :

```
# Via CLI Fortigate
config system api-user
    edit "terraform-api"
        set api-key <GÉNÉRER_UNE_CLÉ>
        set accprofile "super_admin"
        set vdom "root"
    next
end
```

#### Vérifier l'accès API

```bash
curl -k -H "Authorization: Bearer VOTRE_API_KEY" \
  https://10.1.0.1/api/v2/monitor/system/status
```

---

## 5. Infrastructure as Code

### 5.1 Structure du code Terraform

```
zerto/terraform/
├── main.tf                 # Configuration principale
├── variables.tf            # Définition des variables
├── outputs.tf              # Sorties Terraform
├── terraform.tfvars        # Valeurs des variables (à créer)
└── modules/
    ├── zerto-vpg/          # Module VPG
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── scripts/
    │       ├── create-vpg.sh
    │       └── delete-vpg.sh
    ├── zerto-network/      # Module réseau
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── zerto-monitoring/   # Module monitoring
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

### 5.2 Déploiement Terraform

#### Initialisation

```bash
cd zerto/terraform
terraform init
```

#### Validation

```bash
terraform validate
```

#### Plan

```bash
terraform plan -out=tfplan
```

Vérifier attentivement les ressources qui seront créées.

#### Application

```bash
terraform apply tfplan
```

#### Récupération des outputs

```bash
terraform output -json > ../terraform-outputs.json
```

### 5.3 Modules Terraform

#### Module zerto-vpg

Responsable de :
- Création des Virtual Protection Groups
- Configuration des VMs protégées
- Définition du RPO et du journal
- Génération des fichiers d'inventaire Ansible

**Variables principales :**
- `vpg_name` : Nom du VPG
- `protected_vms` : Liste des VMs à protéger
- `rpo_seconds` : RPO en secondes
- `journal_history_hours` : Rétention du journal

#### Module zerto-network

Responsable de :
- Configuration des VIPs Fortigate pour Zerto
- Règles firewall pour ports Zerto (9071-9073, 4007-4008)
- Routes statiques commentées (activées par scripts de failover)

**Note** : Le BGP vers Azure est géré dans les modules `/tunnel-ipsec-bgp-*` (hors scope Zerto)

**Variables principales :**
- `rbx_fortigate` : Config Fortigate RBX (IP, VIP range, interfaces)
- `sbg_fortigate` : Config Fortigate SBG (IP, VIP range, interfaces)
- `zerto_firewall_rules` : Ports et plages IP pour Zerto

#### Module zerto-monitoring

Responsable de :
- Génération des règles Prometheus
- Création du dashboard Grafana
- Configuration des alertes
- Scripts de health check

**Variables principales :**
- `alert_thresholds` : Seuils d'alerte
- `notification_emails` : Emails pour notifications

### 5.4 Maintenance Terraform

#### Mise à jour de la configuration

```bash
# Modifier terraform.tfvars
nano terraform.tfvars

# Replanifier
terraform plan

# Appliquer les changements
terraform apply
```

#### Destruction des ressources

**ATTENTION** : Cette opération supprime toute la configuration Zerto !

```bash
terraform destroy
```

---

## 6. Configuration réseau

### 6.1 Architecture réseau

```
┌─────────────┐                    ┌─────────────┐
│  RBX Site   │                    │  SBG Site   │
│             │                    │             │
│ 10.1.0.0/16 │◄──────BGP─────────►│ 10.2.0.0/16 │
│             │                    │             │
│  Fortigate  │                    │  Fortigate  │
│  10.1.0.1   │                    │  10.2.0.1   │
│  AS 65001   │                    │  AS 65001   │
└─────────────┘                    └─────────────┘
```

### 6.2 Configuration réseau Fortigate

#### Architecture réseau

**Topologie Hub-and-Spoke avec Azure** :
- **Hub** : Azure VPN Gateway (gère BGP et failover)
- **Spoke 1** : Fortigate RBX (tunnel IPsec/BGP Primary)
- **Spoke 2** : Fortigate SBG (tunnel IPsec/BGP Backup)
- **Interconnexion** : vRack OVHcloud entre RBX et SBG

**Flux réseau en mode normal (RBX actif)** :
```
VMs RBX → Fortigate RBX → Azure VPN Gateway
VMs SBG → vRack → Fortigate RBX → Azure VPN Gateway
```

**Flux réseau après failover (SBG actif)** :
```
VMs SBG (incluant VMs failovées de RBX) → Fortigate SBG → Azure VPN Gateway
```

#### Configuration BGP vers Azure

**Note importante** : Le BGP est configuré entre chaque Fortigate et Azure VPN Gateway, PAS entre les deux Fortigates. Cette configuration est gérée par les modules Terraform situés dans `/tunnel-ipsec-bgp-*` (hors scope Zerto).

#### Routes statiques de failover

Les routes statiques sont ajoutées **dynamiquement** lors d'un failover Zerto :

**Sur Fortigate SBG** (lors failover RBX → SBG) :
```bash
config router static
    edit 0
        set dst 10.1.1.10/32
        set device "internal"
        set comment "VM rbx-app-prod-01 failovée"
    next
    edit 0
        set dst 10.1.1.20/32
        set device "internal"
        set comment "VM rbx-db-prod-01 failovée"
    next
end
```

**Sur Fortigate RBX** (lors failover SBG → RBX) :
```bash
config router static
    edit 0
        set dst 10.2.1.10/32
        set device "internal"
        set comment "VM sbg-app-prod-01 failovée"
    next
    edit 0
        set dst 10.2.1.20/32
        set device "internal"
        set comment "VM sbg-db-prod-01 failovée"
    next
end
```

Ces routes sont automatiquement configurées par les scripts de failover (`failover-rbx-to-sbg.sh` et `failover-sbg-to-rbx.sh`).

### 6.3 Règles firewall Zerto

#### Règle Inbound (autoriser le trafic Zerto entrant)

```
config firewall policy
    edit 100
        set name "ALLOW-ZERTO-INBOUND"
        set srcintf "wan1"
        set dstintf "internal"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "TCP_9071" "TCP_9072" "TCP_9073" "TCP_4007" "TCP_4008"
        set logtraffic all
        set comments "Zerto replication traffic"
    next
end
```

#### Règle Outbound (autoriser le trafic Zerto sortant)

```
config firewall policy
    edit 101
        set name "ALLOW-ZERTO-OUTBOUND"
        set srcintf "internal"
        set dstintf "wan1"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "TCP_9071" "TCP_9072" "TCP_9073" "TCP_4007" "TCP_4008"
        set logtraffic all
        set comments "Zerto replication traffic"
    next
end
```

### 6.4 Vérifications réseau

#### Vérifier la connectivité Azure VPN Gateway

**Note** : Les tunnels IPsec/BGP vers Azure sont gérés séparément dans les modules `/tunnel-ipsec-bgp-*`

```bash
# Vérifier les tunnels IPsec actifs
get vpn ipsec tunnel summary

# Vérifier le statut BGP vers Azure
get router info bgp summary
# Vous devriez voir le peer Azure VPN Gateway (pas l'autre Fortigate)
```

#### Tester la connectivité Zerto

```bash
# Depuis RBX vers SBG
nc -zv 10.2.0.1 9071
nc -zv 10.2.0.1 4007

# Depuis SBG vers RBX
nc -zv 10.1.0.1 9071
nc -zv 10.1.0.1 4007
```

#### Vérifier les routes

```bash
# Afficher la table de routage complète
get router info routing-table all

# Vérifier les routes statiques (après failover)
get router info routing-table static

# Vérifier les routes BGP vers Azure
get router info routing-table bgp
# Note: Vous verrez les routes apprises depuis Azure VPN Gateway
```

---

## 7. Monitoring et alertes

### 7.1 Métriques surveillées

| Métrique | Seuil Warning | Seuil Critical | Action |
|----------|---------------|----------------|--------|
| RPO | > 450s | > 600s | Alerte équipe |
| Journal Usage | > 70% | > 85% | Investigation |
| Bandwidth | > 800 Mbps | > 950 Mbps | Throttling |
| VPG Status | != MeetingSLA | Error | Escalade |

### 7.2 Dashboard Grafana

Un dashboard est automatiquement généré avec :
- État des VPGs en temps réel
- Graphique RPO sur 24h
- Utilisation du journal
- Bande passante de réplication
- Historique des alertes

**Accès** : http://monitoring.local:3000/d/zerto-production

### 7.3 Alertes

#### Configuration Prometheus

Fichier généré : `ansible/playbooks/configs/prometheus-zerto-rules.yml`

```yaml
groups:
  - name: zerto
    interval: 30s
    rules:
      - alert: ZertoRPOHigh
        expr: zerto_vpg_rpo_seconds > 600
        for: 5m
        annotations:
          summary: "RPO Zerto élevé"
```

#### Notifications

Les alertes sont envoyées via :
- **Email** : Liste configurée dans `alert_emails`
- **Webhook** : Slack/Teams configuré dans `alert_webhook_url`

### 7.4 Health checks

Script automatique : `scripts/monitoring/health-check.sh`

```bash
# Exécution manuelle
./zerto/scripts/monitoring/health-check.sh

# Output exemple
[OK] VPG RBX->SBG: Status=MeetingSLA, RPO=285s
[OK] VPG SBG->RBX: Status=MeetingSLA, RPO=290s
[OK] BGP Peering: Established
[OK] Network: Latency=12ms
```

---

## 8. Sécurité

### 8.1 Chiffrement

#### Chiffrement en transit

- **Zerto** : AES-256 pour la réplication
- **Fortigate** : IPsec pour le tunnel inter-sites
- **API** : TLS 1.2+ pour toutes les communications

#### Chiffrement au repos

- **Journal Zerto** : Chiffré sur le datastore
- **Credentials** : Stockés dans Terraform Cloud / Vault

### 8.2 Authentification

#### API OVH
- Application Key + Secret + Consumer Key
- Rotation tous les 90 jours recommandée

#### API Zerto
- Token avec expiration
- Permissions limitées au strict nécessaire

#### API Fortigate
- Clés API dédiées par usage
- Profil d'accès restreint

### 8.3 Secrets management

#### Recommandations

1. **Ne jamais commiter** terraform.tfvars dans Git
2. Utiliser **Terraform Cloud** pour stocker les secrets
3. Ou utiliser **HashiCorp Vault** pour la gestion des secrets
4. Chiffrer les backups avec GPG

#### Exemple avec Vault

```bash
# Stocker les secrets dans Vault
vault kv put secret/zerto/ovh \
  application_key="xxx" \
  application_secret="xxx" \
  consumer_key="xxx"

# Récupérer dans Terraform
data "vault_generic_secret" "ovh" {
  path = "secret/zerto/ovh"
}
```

### 8.4 Audit et logging

#### Logs à conserver

- **Terraform** : terraform.log (état des apply/destroy)
- **Zerto** : Logs d'événements VPG
- **Fortigate** : Logs des changements de config
- **Scripts** : Tous les logs de failover/failback

#### Rétention

- Logs opérationnels : 90 jours
- Logs de sécurité : 1 an
- Logs de conformité : 7 ans

---

## 9. Dépannage

### 9.1 Problèmes courants

#### VPG en état "Initial Sync"

**Symptôme** : Le VPG reste bloqué en synchronisation initiale

**Causes** :
- Bande passante insuffisante
- Connectivité réseau instable
- Espace disque insuffisant sur le journal

**Solutions** :
```bash
# Vérifier la bande passante
iperf3 -c 10.2.0.1 -t 60

# Vérifier l'espace disque
# Dans la console Zerto, vérifier le datastore du journal

# Augmenter la bande passante allouée
# Éditer le VPG > Settings > Network > WAN Compression: Enable
```

#### RPO élevé

**Symptôme** : Le RPO dépasse régulièrement le seuil configuré

**Causes** :
- Activité élevée sur les VMs sources
- Bande passante saturée
- Problème de performance du stockage

**Solutions** :
```bash
# Vérifier l'activité disque des VMs
# Sur la VM source
iostat -x 1 10

# Vérifier la bande passante Zerto
# Console Zerto > Monitoring > Bandwidth

# Actions correctives :
# 1. Augmenter la compression
# 2. Activer WAN Acceleration
# 3. Augmenter la bande passante réseau
# 4. Exclure des disques non critiques de la réplication
```

#### Échec du failover

**Symptôme** : Le failover échoue ou ne démarre pas

**Causes** :
- VPG en état d'erreur
- Site cible inaccessible
- Espace insuffisant sur le site cible

**Solutions** :
```bash
# Vérifier l'état du VPG
./zerto/scripts/check-vpg-status.sh

# Vérifier la connectivité au site cible
ping -c 10 10.2.0.1
nc -zv 10.2.0.1 9071

# Vérifier l'espace disque sur le site cible
# Console OVH > Stockage

# Tester le failover en mode test d'abord
./zerto/scripts/failover-rbx-to-sbg.sh --test
```

### 9.2 Commandes de diagnostic

#### État des VPGs

```bash
# Via script
./zerto/scripts/check-vpg-status.sh

# Via API directement
curl -s -H "Authorization: Bearer $ZERTO_API_TOKEN" \
  https://zerto-api.ovh.net/v1/vpgs | jq '.'
```

#### État des tunnels et routes

```bash
# Vérifier les tunnels IPsec vers Azure
get vpn ipsec tunnel summary
get vpn ipsec tunnel details

# Vérifier le BGP vers Azure VPN Gateway
get router info bgp summary
diagnose ip router bgp all

# Vérifier les routes statiques (après failover)
get router info routing-table static
```

#### Logs Terraform

```bash
# Activer le debug Terraform
export TF_LOG=DEBUG
export TF_LOG_PATH=terraform-debug.log

# Relancer l'opération
terraform plan
```

### 9.3 Procédures de récupération

#### Recréer un VPG

```bash
# 1. Détruire le VPG problématique
terraform destroy -target=module.zerto_rbx_to_sbg

# 2. Recréer le VPG
terraform apply -target=module.zerto_rbx_to_sbg
```

#### Resynchroniser les VMs

```bash
# Via l'API Zerto
curl -X POST -H "Authorization: Bearer $ZERTO_API_TOKEN" \
  https://zerto-api.ovh.net/v1/vpgs/${VPG_ID}/resync
```

#### Réinitialiser les tunnels vers Azure

**Note** : Utilisez avec précaution - cela va couper temporairement la connectivité

```bash
# Réinitialiser le tunnel IPsec vers Azure
diagnose vpn ipsec tunnel down <tunnel_name>
diagnose vpn ipsec tunnel up <tunnel_name>

# Réinitialiser le peering BGP vers Azure VPN Gateway
execute router clear bgp all
```

### 9.4 Support et escalade

#### Niveau 1 - Équipe Ops
- Vérifications de base
- Redémarrage des services
- Consultation des logs

#### Niveau 2 - Ingénieurs Infrastructure
- Problèmes réseau complexes
- Reconfiguration Fortigate
- Problèmes de performance

#### Niveau 3 - Support OVH / Zerto
- Problèmes de plateforme
- Bugs Zerto
- Problèmes de licence

**Contact Support OVH** : https://www.ovh.com/manager/dedicated/#/support
**Contact Support Zerto** : support@zerto.com

---

## 10. Annexes

### 10.1 Checklist de déploiement

- [ ] Prérequis infrastructure vérifiés
- [ ] Credentials OVH configurés
- [ ] Credentials Zerto configurés
- [ ] Fortigates accessibles et configurés
- [ ] IDs des VMs récupérés
- [ ] Network IDs récupérés
- [ ] terraform.tfvars complété
- [ ] `terraform init` exécuté avec succès
- [ ] `terraform plan` vérifié
- [ ] `terraform apply` exécuté avec succès
- [ ] VPGs créés et en état "MeetingSLA"
- [ ] Tunnels IPsec vers Azure opérationnels
- [ ] Routes statiques de failover validées
- [ ] Test failover réussi (RBX → SBG et SBG → RBX)
- [ ] Monitoring configuré
- [ ] Documentation à jour

### 10.2 Références

- [Documentation Zerto](https://www.zerto.com/documentation/)
- [API Zerto](https://www.zerto.com/page/api-documentation/)
- [Terraform vSphere Provider](https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs)
- [OVHcloud Hosted Private Cloud](https://docs.ovh.com/fr/private-cloud/)
- [Fortigate Administration Guide](https://docs.fortinet.com/)
- [Azure VPN Gateway BGP](https://learn.microsoft.com/fr-fr/azure/vpn-gateway/vpn-gateway-bgp-overview)

### 10.3 Glossaire

| Terme | Définition |
|-------|------------|
| **VPG** | Virtual Protection Group - Groupe de VMs protégées ensemble |
| **VRA** | Virtual Replication Appliance - Appliance de réplication Zerto |
| **RPO** | Recovery Point Objective - Perte de données maximale acceptable |
| **RTO** | Recovery Time Objective - Temps de restauration maximal |
| **Failover** | Bascule vers le site de secours |
| **Failback** | Retour au site principal |
| **Journal** | Historique des modifications pour point-in-time recovery |
| **vRack** | Réseau privé OVHcloud interconnectant les datacenters |
| **vSphere** | Plateforme de virtualisation VMware |
| **Hub-and-Spoke** | Topologie réseau avec un hub central (Azure) et des spokes (RBX, SBG) |

---

**Document maintenu par** : Équipe Infrastructure
**Dernière mise à jour** : 2025-12-17
**Version** : 1.0
