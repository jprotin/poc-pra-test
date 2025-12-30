# Documentation Fonctionnelle - Infrastructure Applicative OVH VMware

## Vue d'ensemble

Cette feature déploie une infrastructure applicative complète sur l'environnement OVH Private Cloud VMware, répartie sur deux datacenters (RBX et SBG) avec un Plan de Reprise d'Activité (PRA) intégré via Zerto.

## Objectifs métier

### Problématique

L'entreprise a besoin de :
1. Héberger des applications conteneurisées (Docker) avec haute disponibilité
2. Fournir des bases de données MySQL dédiées par site géographique
3. Garantir la continuité de service en cas de panne d'un datacenter
4. Assurer une réplication continue des données (RPO < 5 minutes)
5. Sécuriser les flux réseau via firewalls dédiés (FortiGate)

### Solution

Déploiement automatisé via Infrastructure as Code (Terraform + Ansible) de :
- **4 Virtual Machines** : 2 hosts Docker + 2 serveurs MySQL
- **Réseau privé sécurisé** : vRack OVH avec isolation VLAN
- **Plan de Reprise d'Activité** : Réplication Zerto bidirectionnelle
- **Sécurité périmétrique** : Règles FortiGate automatisées

## Cas d'usage

### CU-001 : Déploiement initial de l'infrastructure

**Acteur** : Administrateur DevOps
**Objectif** : Provisionner l'infrastructure complète en moins de 30 minutes

**Scénario nominal :**
1. L'admin configure le fichier `terraform.tfvars` avec les paramètres de l'environnement
2. Il exécute `./scripts/deploy-ovh-infrastructure.sh`
3. Le script déploie automatiquement :
   - Les VMs Docker et MySQL sur RBX et SBG
   - La configuration réseau vRack (VLANs 100, 200, 900)
   - Les règles FortiGate pour communication inter-VMs
   - Les Virtual Protection Groups (VPG) Zerto
4. Les playbooks Ansible configurent les VMs (Docker, MySQL, monitoring)
5. L'infrastructure est opérationnelle

**Résultat** : Infrastructure prête à héberger des applications en production

### CU-002 : Failover RBX → SBG (sinistre datacenter RBX)

**Acteur** : Équipe Ops
**Objectif** : Basculer l'Application A de RBX vers SBG en moins de 15 minutes

**Scénario nominal :**
1. Le datacenter RBX devient indisponible (sinistre)
2. L'équipe Ops initie un failover Zerto RBX → SBG
3. Zerto démarre les VMs répliquées sur SBG dans l'ordre :
   - VM-MYSQL-APP-A-RBX (répliquée → SBG) démarre en priorité 1
   - VM-DOCKER-APP-A-RBX (répliquée → SBG) démarre 60s après avec IP remappée
4. Les règles FortiGate SBG autorisent automatiquement le trafic
5. L'application A est opérationnelle sur le site SBG

**Résultat** : RTO < 15 minutes, RPO < 5 minutes

### CU-003 : Déploiement d'une application Docker

**Acteur** : Développeur
**Objectif** : Déployer une application conteneurisée sur la VM Docker RBX

**Scénario nominal :**
1. Le développeur se connecte à la VM Docker RBX via SSH
2. Il crée un fichier `docker-compose.yml` définissant son application
3. Il configure les variables d'environnement pour connexion MySQL :
   ```yaml
   DB_HOST: 10.100.0.11  # VM MySQL RBX
   DB_PORT: 3306
   DB_NAME: app_rbx_db
   DB_USER: appuser
   DB_PASSWORD: ${MYSQL_APP_PASSWORD}
   ```
4. Il démarre l'application : `docker-compose up -d`
5. L'application se connecte automatiquement à MySQL via le réseau privé

**Résultat** : Application opérationnelle avec accès base de données

## Règles métier

### RG-001 : Isolation réseau

- Les VMs MySQL ne sont accessibles **que depuis** les VMs Docker du même site
- Aucun accès Internet direct vers les VMs MySQL (pas de NAT)
- Communication inter-sites (RBX ↔ SBG) uniquement pour Zerto (ports 4007-4008)

### RG-002 : Ordre de démarrage en cas de failover

- **Priorité 1** : VM MySQL (base de données)
- **Priorité 2** : VM Docker (applications) - démarre **60 secondes** après MySQL
- Raison : Les applications Docker dépendent de la disponibilité de MySQL

### RG-003 : Sauvegarde MySQL

- Backup quotidien automatique (mysqldump) à 02h00
- Rétention locale : 7 jours
- Compression gzip obligatoire
- Stockage dans `/var/backups/mysql/`

### RG-004 : Remapping IP après failover

| VM Source (RBX) | IP Source | IP Cible (SBG) |
|-----------------|-----------|----------------|
| VM-DOCKER-APP-A-RBX | 10.100.0.10 | 10.200.0.10 |
| VM-MYSQL-APP-A-RBX  | 10.100.0.11 | 10.200.0.11 |

| VM Source (SBG) | IP Source | IP Cible (RBX) |
|-----------------|-----------|----------------|
| VM-DOCKER-APP-B-SBG | 10.200.0.10 | 10.100.0.10 |
| VM-MYSQL-APP-B-SBG  | 10.200.0.11 | 10.100.0.11 |

## Acteurs

| Acteur | Responsabilités |
|--------|----------------|
| **Administrateur DevOps** | Déploiement initial, configuration Terraform/Ansible |
| **Équipe Ops** | Monitoring, maintenance, exécution failover/failback |
| **Développeur** | Déploiement applications Docker, configuration connexions MySQL |
| **DBA** | Gestion bases de données, optimisation MySQL, backups |
| **Équipe Sécurité** | Audit règles FortiGate, gestion certificats, hardening OS |

## Contraintes non-fonctionnelles

### Performance

- **RPO (Recovery Point Objective)** : < 5 minutes (300 secondes)
- **RTO (Recovery Time Objective)** : < 15 minutes
- **Latence réseau inter-DC** : < 10ms (vRack OVH RBX ↔ SBG)

### Disponibilité

- **SLA VMs** : 99.9% (hors maintenance planifiée)
- **SLA Zerto réplication** : 99.9%
- **Monitoring actif** : node_exporter (port 9100), mysqld_exporter (port 9104)

### Sécurité

- **Chiffrement réplication Zerto** : AES-256 activé
- **Firewall OS** : UFW activé sur toutes les VMs
- **Fail2ban SSH** : 3 tentatives max, ban 1 heure
- **Mises à jour automatiques** : Activées (unattended-upgrades Ubuntu)

### Capacité

| Ressource | VM Docker | VM MySQL |
|-----------|-----------|----------|
| vCPU | 4 | 4 |
| RAM | 8 Go | 16 Go |
| Disque OS | 100 Go | 50 Go |
| Disque Data | 0 Go (optionnel) | 200 Go (SSD) |

## Dépendances externes

- **OVH Private Cloud VMware** : vSphere 7.x sur RBX et SBG
- **Zerto Virtual Replication** : Version 9.x minimum
- **FortiGate OS** : Version 7.x avec API REST activée
- **vRack OVH** : Interconnexion L2 entre datacenters

## Évolutions futures

- **Scaling horizontal** : Ajout de VMs Docker supplémentaires avec load balancing
- **MySQL Replication** : Master-Slave natif MySQL en complément de Zerto
- **Monitoring centralisé** : Intégration Prometheus + Grafana
- **CI/CD** : Déploiement automatique via GitLab CI/CD
