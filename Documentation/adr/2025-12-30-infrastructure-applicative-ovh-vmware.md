# Infrastructure Applicative OVH VMware Multi-Régions avec Docker et MySQL

* **Statut :** Proposé
* **Date :** 2025-12-30
* **Décideurs :** Équipe DevOps / Architecture
* **Tags :** Infrastructure, OVH, VMware, Docker, MySQL, PRA, Zerto

## Contexte

Le projet nécessite la mise en place d'une infrastructure applicative distribuée sur deux datacenters OVH VMware (RBX et SBG) pour héberger :

- **Applications conteneurisées** : Déploiement via Docker et Docker Compose
- **Bases de données MySQL** : Instances dédiées pour chaque site
- **Plan de Reprise d'Activité (PRA)** : Réplication Zerto bidirectionnelle entre sites
- **Isolation réseau** : Communication sécurisée via FortiGate et vRack OVH

### Contraintes techniques

1. **Environnement OVH Private Cloud** : VMware vSphere 7.x sur RBX et SBG
2. **Réseau distribué** : vRack OVH pour interconnexion privée L2 entre datacenters
3. **Sécurité périmétrique** : FortiGate en frontal pour filtrage et VPN
4. **Réplication synchrone** : Zerto pour RPO < 5 minutes
5. **Automatisation complète** : Infrastructure as Code (IaC) obligatoire

### Problématique

Comment architecturer et provisionner automatiquement une infrastructure multi-régions résiliente, sécurisée et conforme aux exigences de PRA tout en garantissant la reproductibilité et la maintenabilité ?

## Décision

### Architecture cible

Nous déployons **4 Virtual Machines** réparties sur 2 sites :

#### Site RBX (Roubaix - Production primaire)
1. **VM-DOCKER-APP-A-RBX**
   - OS : Ubuntu 22.04 LTS
   - Rôle : Host Docker pour Application A
   - Spécifications : 4 vCPU, 8 Go RAM, 100 Go SSD
   - Réseau : Connectée au vRack via interface privée + interface publique via FortiGate

2. **VM-MYSQL-APP-A-RBX**
   - OS : Ubuntu 22.04 LTS
   - Rôle : Base de données MySQL 8.0
   - Spécifications : 4 vCPU, 16 Go RAM, 200 Go SSD
   - Réseau : Interface privée uniquement (vRack), accessible depuis VM Docker RBX

#### Site SBG (Strasbourg - Production secondaire / PRA)
3. **VM-DOCKER-APP-B-SBG**
   - OS : Ubuntu 22.04 LTS
   - Rôle : Host Docker pour Application B
   - Spécifications : 4 vCPU, 8 Go RAM, 100 Go SSD
   - Réseau : Connectée au vRack via interface privée + interface publique via FortiGate

4. **VM-MYSQL-APP-B-SBG**
   - OS : Ubuntu 22.04 LTS
   - Rôle : Base de données MySQL 8.0
   - Spécifications : 4 vCPU, 16 Go RAM, 200 Go SSD
   - Réseau : Interface privée uniquement (vRack), accessible depuis VM Docker SBG

### Stack technologique retenue

#### 1. Terraform (Provisioning Infrastructure)
- **Provider VMware vSphere** : Création des VMs sur vCenter RBX/SBG
- **Provider FortiOS** : Configuration des règles firewall et NAT
- **Modules réutilisables** :
  - `modules/06-ovh-vm-docker` : Déploiement VM Docker standardisée
  - `modules/07-ovh-vm-mysql` : Déploiement VM MySQL avec disques optimisés
  - `modules/08-ovh-network-config` : Configuration vRack et port groups
  - `modules/09-ovh-fortigate-rules` : Règles de sécurité et VIP

#### 2. Ansible (Configuration Management)
- **Playbook `configure-docker-vm.yml`** :
  - Installation Docker Engine 24.x + Docker Compose v2
  - Hardening OS (UFW, fail2ban, auditd)
  - Configuration monitoring (node_exporter)
  - Déploiement clés SSH et certificats TLS

- **Playbook `configure-mysql-vm.yml`** :
  - Installation MySQL 8.0 (APT repository officiel)
  - Configuration performance (InnoDB, buffer pool)
  - Création utilisateurs et schémas applicatifs
  - Backup automatisé (mysqldump + rotation)

- **Playbook `configure-zerto-protection.yml`** :
  - Installation VRA (Virtual Replication Appliance) Zerto
  - Création VPG (Virtual Protection Group) :
    - RBX → SBG : VM-DOCKER-APP-A-RBX + VM-MYSQL-APP-A-RBX
    - SBG → RBX : VM-DOCKER-APP-B-SBG + VM-MYSQL-APP-B-SBG
  - Configuration RPO 300s, journal 24h

#### 3. Scripts Shell (Orchestration)
- **`scripts/deploy-ovh-infrastructure.sh`** :
  - Validation prérequis (credentials, connectivité vCenter/FortiGate)
  - Exécution séquentielle Terraform (plan → apply)
  - Exécution Ansible post-provisioning
  - Tests de connectivité et healthchecks

- **`scripts/destroy-ovh-infrastructure.sh`** :
  - Désactivation protection Zerto (évite erreurs de réplication)
  - Destruction Terraform avec confirmation explicite
  - Nettoyage configurations FortiGate orphelines

### Configuration réseau détaillée

#### vRack OVH (VLAN Privés)
- **VLAN 100 - RBX Private Network** : `10.100.0.0/24`
  - VM-DOCKER-APP-A-RBX : `10.100.0.10`
  - VM-MYSQL-APP-A-RBX : `10.100.0.11`
  - FortiGate RBX Interface Interne : `10.100.0.1`

- **VLAN 200 - SBG Private Network** : `10.200.0.0/24`
  - VM-DOCKER-APP-B-SBG : `10.200.0.10`
  - VM-MYSQL-APP-B-SBG : `10.200.0.11`
  - FortiGate SBG Interface Interne : `10.200.0.1`

- **VLAN 900 - Inter-DC Backbone** : `10.255.0.0/30`
  - FortiGate RBX Tunnel Endpoint : `10.255.0.1`
  - FortiGate SBG Tunnel Endpoint : `10.255.0.2`

#### Règles FortiGate

**RBX FortiGate :**
```
# Permettre VM Docker RBX → MySQL RBX (port 3306)
policy 100: allow 10.100.0.10 → 10.100.0.11 tcp/3306

# NAT/VIP pour accès Internet depuis VM Docker RBX
policy 101: SNAT 10.100.0.10 → <public-ip-rbx>

# Permettre trafic Zerto réplication (ports 4007-4008)
policy 102: allow 10.100.0.0/24 → 10.200.0.0/24 tcp/4007-4008
```

**SBG FortiGate :**
```
# Permettre VM Docker SBG → MySQL SBG (port 3306)
policy 200: allow 10.200.0.10 → 10.200.0.11 tcp/3306

# NAT/VIP pour accès Internet depuis VM Docker SBG
policy 201: SNAT 10.200.0.10 → <public-ip-sbg>

# Permettre trafic Zerto réplication (ports 4007-4008)
policy 202: allow 10.200.0.0/24 → 10.100.0.0/24 tcp/4007-4008
```

### Intégration Zerto PRA

#### Virtual Protection Groups (VPG)

**VPG-RBX-TO-SBG :**
- **VMs protégées** : VM-DOCKER-APP-A-RBX, VM-MYSQL-APP-A-RBX
- **Site source** : RBX
- **Site cible** : SBG
- **RPO** : 300 secondes (5 minutes)
- **Journal** : 24 heures
- **Réseau cible** : VLAN 200 (10.200.0.0/24)
- **Ordre de boot** :
  1. VM-MYSQL-APP-A-RBX (priorité 1)
  2. VM-DOCKER-APP-A-RBX (priorité 2, délai 60s après MySQL)

**VPG-SBG-TO-RBX :**
- **VMs protégées** : VM-DOCKER-APP-B-SBG, VM-MYSQL-APP-B-SBG
- **Site source** : SBG
- **Site cible** : RBX
- **RPO** : 300 secondes
- **Journal** : 24 heures
- **Réseau cible** : VLAN 100 (10.100.0.0/24)
- **Ordre de boot** :
  1. VM-MYSQL-APP-B-SBG (priorité 1)
  2. VM-DOCKER-APP-B-SBG (priorité 2, délai 60s après MySQL)

#### Scripts de test PRA

```bash
# Test failover RBX → SBG (non destructif)
scripts/zerto/test-failover-rbx-to-sbg.sh

# Test failback SBG → RBX (après failover)
scripts/zerto/test-failback-sbg-to-rbx.sh
```

## Alternatives rejetées

### Alternative 1 : Kubernetes au lieu de Docker Compose
**Rejeté car :**
- Complexité excessive pour 2 applications
- Overhead de gestion (control plane, workers)
- Zerto supporte mieux la réplication de VMs simples que de clusters K8s distribués
- Coût : nécessiterait 6+ VMs (3 masters + 3 workers par site)

### Alternative 2 : MySQL managé OVH (Database as a Service)
**Rejeté car :**
- Moins de contrôle sur les configurations InnoDB
- Pas de support Zerto natif (nécessiterait backup/restore au lieu de réplication continue)
- Coût mensuel plus élevé (€180/mois vs €60/mois VM autogérée)
- Latence cross-région non optimisable

### Alternative 3 : Pulumi au lieu de Terraform
**Rejeté car :**
- Équipe déjà formée sur Terraform
- Écosystème de providers plus mature (vsphere, fortios)
- State file compatible avec pipelines CI/CD existants
- Communauté plus large pour troubleshooting OVH-spécifique

### Alternative 4 : Scripts Shell purs (sans Terraform/Ansible)
**Rejeté car :**
- Pas d'idempotence garantie
- Gestion d'état manuelle (risques de drift)
- Difficile à tester (pas de `terraform plan`)
- Maintenance complexe (parsing XML vCenter)

## Conséquences

### ✅ Impacts positifs

1. **Reproductibilité** : Infrastructure complète déployable en 20 minutes via `deploy.sh`
2. **Versioning** : Code IaC versionné dans Git avec review de merge requests
3. **Isolation** : Applications isolées par VM (pas de conteneurs partagés multi-tenant)
4. **PRA robuste** : RPO 5 minutes avec tests automatisés mensuels
5. **Coût optimisé** : Sizing ajustable via variables Terraform
6. **Sécurité** : Hardening OS via Ansible (CIS benchmarks Ubuntu)

### ⚠️ Impacts négatifs / Dette technique

1. **Gestion des secrets** :
   - **Problème** : Mots de passe MySQL et clés SSH à stocker sécurisément
   - **Mitigation** : Utilisation d'Ansible Vault + rotation trimestrielle
   - **Dette** : Migration future vers HashiCorp Vault souhaitable

2. **Backup MySQL** :
   - **Problème** : Zerto réplique les VMs mais pas optimisé pour cohérence transactionnelle MySQL
   - **Mitigation** : `mysqldump` quotidien + stockage S3 OVH (voir module emergency-backup)
   - **Dette** : Envisager MySQL replication native (master-slave) en complément de Zerto

3. **Monitoring** :
   - **Problème** : Pas de supervision centralisée dans cette phase
   - **Mitigation** : Installation de node_exporter (Prometheus-ready)
   - **Dette** : Intégrer à une stack Prometheus/Grafana dédiée (roadmap Q2 2025)

4. **Mises à jour OS** :
   - **Problème** : Ubuntu 22.04 aura des updates de sécurité à appliquer
   - **Mitigation** : Playbook Ansible `update-os.yml` + snapshots vCenter pré-update
   - **Dette** : Automatisation via Ansible Tower ou AWX souhaitable

5. **Coût mensuel estimé** :
   - 4 VMs × €30/mois = **€120/mois** (hors FortiGate et Zerto déjà provisionnés)
   - Bande passante vRack : incluse
   - Stockage : €0.08/Go/mois → 600 Go × €0.08 = **€48/mois**
   - **Total : ~€170/mois**

6. **Dépendance OVH** :
   - Migration future vers un autre cloud nécessitera réécriture partielle (provider Terraform)
   - **Mitigation** : Utilisation de modules abstraits et séparation concerns (network, compute, storage)

## Métriques de succès

- ✅ Déploiement complet < 30 minutes (Terraform + Ansible)
- ✅ Tous les tests de connectivité passent (ping, MySQL, Docker)
- ✅ Zerto VPG actifs avec RPO < 300s
- ✅ Test failover simulé réussi (RTO < 15 minutes)
- ✅ Documentation à jour (runbooks, architecture diagrams)

## Prochaines étapes

1. Valider l'ADR avec l'équipe DevOps/Ops ✅
2. Créer les modules Terraform (semaine 1)
3. Développer les playbooks Ansible (semaine 1)
4. Tests en environnement de développement (semaine 2)
5. Déploiement en production (semaine 3)
6. Formation équipe Ops sur runbooks (semaine 4)

## Références

- [OVH Private Cloud VMware Documentation](https://docs.ovh.com/fr/private-cloud/)
- [Zerto Virtual Replication Guide](https://www.zerto.com/myzerto/knowledge-base/)
- [Terraform Provider vSphere](https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs)
- [Ansible Collection community.mysql](https://docs.ansible.com/ansible/latest/collections/community/mysql/)
- [FortiGate Administration Guide 7.x](https://docs.fortinet.com/product/fortigate/7.0)
