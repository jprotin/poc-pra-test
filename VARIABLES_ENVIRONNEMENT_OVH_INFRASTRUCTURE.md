# Variables d'Environnement - Infrastructure OVH VMware Applicative

## Description

Cette section documente les variables d'environnement spécifiques au module **Infrastructure OVH VMware Applicative** (Docker + MySQL + vRack + FortiGate + Zerto PRA).

## Fichier Terraform

Les variables sont configurées dans : `terraform/ovh-infrastructure/terraform.tfvars`

Template disponible : `terraform/ovh-infrastructure/terraform.tfvars.example`

---

## 1. Infrastructure OVH VMware - Configuration vSphere RBX

Variables pour la connexion au vCenter OVH Private Cloud RBX (Roubaix).

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `vsphere_rbx_server` | `pcc-xxx-xxx-xxx.ovh.com` | 🔴 | Adresse du serveur vCenter RBX |
| `vsphere_rbx_user` | `admin@vsphere.local` | 🔴 | Nom d'utilisateur vCenter avec privilèges admin |
| `vsphere_rbx_password` | `SuperSecretPassword123!` | 🔴 | Mot de passe vCenter RBX |
| `vsphere_rbx_datacenter` | `Datacenter-RBX` | 🟢 | Nom du datacenter vSphere |
| `vsphere_rbx_cluster` | `Cluster1` | 🟢 | Nom du cluster vSphere où déployer les VMs |
| `vsphere_rbx_datastore` | `datastore1` | 🟢 | Nom du datastore pour stockage des disques |
| `vsphere_rbx_distributed_switch` | `vRack-DSwitch-RBX` | 🟢 | Nom du Distributed Switch pour vRack |

---

## 2. Infrastructure OVH VMware - Configuration vSphere SBG

Variables pour la connexion au vCenter OVH Private Cloud SBG (Strasbourg).

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `vsphere_sbg_server` | `pcc-yyy-yyy-yyy.ovh.com` | 🔴 | Adresse du serveur vCenter SBG |
| `vsphere_sbg_user` | `admin@vsphere.local` | 🔴 | Nom d'utilisateur vCenter avec privilèges admin |
| `vsphere_sbg_password` | `SuperSecretPassword456!` | 🔴 | Mot de passe vCenter SBG |
| `vsphere_sbg_datacenter` | `Datacenter-SBG` | 🟢 | Nom du datacenter vSphere |
| `vsphere_sbg_cluster` | `Cluster1` | 🟢 | Nom du cluster vSphere où déployer les VMs |
| `vsphere_sbg_datastore` | `datastore1` | 🟢 | Nom du datastore pour stockage des disques |
| `vsphere_sbg_distributed_switch` | `vRack-DSwitch-SBG` | 🟢 | Nom du Distributed Switch pour vRack |

---

## 3. Infrastructure OVH VMware - Configuration vRack (Réseaux privés)

Variables pour la configuration des VLANs vRack OVH (interconnexion privée L2 entre datacenters).

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `vrack_vlan_rbx_id` | `100` | 🟢 | ID du VLAN pour le réseau privé RBX (2-4094) |
| `vrack_vlan_rbx_cidr` | `10.100.0.0/24` | 🟢 | CIDR du réseau privé RBX |
| `vrack_vlan_sbg_id` | `200` | 🟢 | ID du VLAN pour le réseau privé SBG (2-4094) |
| `vrack_vlan_sbg_cidr` | `10.200.0.0/24` | 🟢 | CIDR du réseau privé SBG |
| `vrack_vlan_backbone_id` | `900` | 🟢 | ID du VLAN pour l'interconnexion inter-DC (backbone) |
| `vrack_vlan_backbone_cidr` | `10.255.0.0/30` | 🟢 | CIDR du réseau backbone RBX ↔ SBG |

**Notes** :
- Les VLANs doivent être configurés dans le vRack OVH via l'interface OVH Manager
- VLAN 1 et 4095 sont réservés (ne pas utiliser)

---

## 4. Infrastructure OVH VMware - Configuration VMs (Général)

Variables communes à toutes les VMs.

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `vm_template` | `ubuntu-22.04-template` | 🟢 | Nom du template vSphere Ubuntu à cloner |
| `admin_username` | `vmadmin` | 🟢 | Nom d'utilisateur administrateur des VMs |
| `admin_ssh_public_key` | `ssh-rsa AAAAB3Nza...` | 🔴 | Clé SSH publique pour accès administrateur |
| `vm_ipv4_netmask` | `24` | 🟢 | Masque de sous-réseau (bits) pour toutes les VMs |
| `dns_servers` | `["213.186.33.99", "8.8.8.8"]` | 🟢 | Serveurs DNS (OVH DNS + Google DNS) |

---

## 5. Infrastructure OVH VMware - Adresses IP VMs

Plan d'adressage IP statique pour les 4 VMs.

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `vm_docker_rbx_ip` | `10.100.0.10` | 🟢 | Adresse IP de la VM Docker RBX |
| `vm_mysql_rbx_ip` | `10.100.0.11` | 🟢 | Adresse IP de la VM MySQL RBX |
| `vm_docker_sbg_ip` | `10.200.0.10` | 🟢 | Adresse IP de la VM Docker SBG |
| `vm_mysql_sbg_ip` | `10.200.0.11` | 🟢 | Adresse IP de la VM MySQL SBG |
| `rbx_gateway_ip` | `10.100.0.1` | 🟢 | Passerelle par défaut RBX (FortiGate interface interne) |
| `sbg_gateway_ip` | `10.200.0.1` | 🟢 | Passerelle par défaut SBG (FortiGate interface interne) |
| `rbx_domain_name` | `rbx.prod.local` | 🟢 | Nom de domaine pour les VMs RBX |
| `sbg_domain_name` | `sbg.prod.local` | 🟢 | Nom de domaine pour les VMs SBG |

---

## 6. Infrastructure OVH VMware - Configuration VMs Docker

Variables de dimensionnement et configuration pour les VMs Docker.

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `docker_vm_num_cpus` | `4` | 🟢 | Nombre de vCPUs alloués (2-16) |
| `docker_vm_memory_mb` | `8192` | 🟢 | RAM en Mo (8 Go minimum recommandé) |
| `docker_vm_disk_size_gb` | `100` | 🟢 | Taille du disque principal en Go (min 50 Go) |
| `docker_vm_additional_disk_size_gb` | `0` | 🟢 | Disque additionnel pour volumes Docker (0=désactivé) |
| `docker_version` | `24.0` | 🟢 | Version de Docker Engine à installer |
| `docker_compose_version` | `2.23.0` | 🟢 | Version de Docker Compose à installer |
| `enable_docker_monitoring` | `true` | 🟢 | Activer monitoring (node_exporter + cAdvisor) |

---

## 7. Infrastructure OVH VMware - Configuration VMs MySQL

Variables de dimensionnement et configuration pour les VMs MySQL.

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `mysql_vm_num_cpus` | `4` | 🟢 | Nombre de vCPUs alloués (2-32) |
| `mysql_vm_memory_mb` | `16384` | 🟢 | RAM en Mo (16 Go, min 8 Go) |
| `mysql_vm_disk_size_gb` | `50` | 🟢 | Taille du disque OS en Go (min 30 Go) |
| `mysql_vm_data_disk_size_gb` | `200` | 🟢 | Disque dédié pour `/var/lib/mysql` (min 50 Go) |
| `mysql_vm_log_disk_size_gb` | `0` | 🟢 | Disque optionnel pour logs MySQL (0=désactivé) |
| `mysql_version` | `8.0` | 🟢 | Version de MySQL à installer |
| `mysql_root_password` | `SuperSecretMySQLRoot123!` | 🔴 | Mot de passe root MySQL (min 16 caractères) |
| `mysql_database_name_rbx` | `app_rbx_db` | 🟢 | Nom de la base de données applicative RBX |
| `mysql_database_name_sbg` | `app_sbg_db` | 🟢 | Nom de la base de données applicative SBG |
| `mysql_app_user` | `appuser` | 🟢 | Nom d'utilisateur MySQL pour applications |
| `mysql_app_password` | `AppUserPassword456!` | 🔴 | Mot de passe utilisateur MySQL applicatif |
| `mysql_innodb_buffer_pool_size` | `12G` | 🟢 | Taille buffer pool InnoDB (70-80% de la RAM) |
| `mysql_max_connections` | `500` | 🟢 | Nombre maximum de connexions simultanées (50-10000) |
| `enable_mysql_backup` | `true` | 🟢 | Activer backups automatiques MySQL (mysqldump) |
| `mysql_backup_retention_days` | `7` | 🟢 | Rétention des backups locaux en jours |
| `enable_mysql_monitoring` | `true` | 🟢 | Activer monitoring MySQL (mysqld_exporter) |

**Notes performances MySQL** :
- `innodb_buffer_pool_size` doit être ~70% de la RAM pour performances optimales
- Pour 16 Go RAM : `12G` est recommandé
- `mysql_max_connections` : Calculer selon formule : `(RAM_MB - innodb_buffer_pool_MB) / 12`

---

## 8. Infrastructure OVH VMware - Configuration FortiGate

Variables pour la configuration automatique des règles firewall FortiGate.

### FortiGate RBX

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `fortigate_rbx_hostname` | `192.168.10.1` | 🔴 | IP de management du FortiGate RBX |
| `fortigate_rbx_token` | `xyz789abcdef...` | 🔴 | API Token FortiGate RBX (REST API) |
| `fortigate_rbx_public_ip` | `51.210.100.50` | 🟠 | Adresse IP publique du FortiGate RBX |
| `fortigate_rbx_internal_interface` | `port1` | 🟢 | Nom de l'interface interne (vRack) |
| `fortigate_rbx_external_interface` | `port2` | 🟢 | Nom de l'interface externe (Internet) |

### FortiGate SBG

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `fortigate_sbg_hostname` | `192.168.20.1` | 🔴 | IP de management du FortiGate SBG |
| `fortigate_sbg_token` | `abc123ghijkl...` | 🔴 | API Token FortiGate SBG (REST API) |
| `fortigate_sbg_public_ip` | `51.210.200.75` | 🟠 | Adresse IP publique du FortiGate SBG |
| `fortigate_sbg_internal_interface` | `port1` | 🟢 | Nom de l'interface interne (vRack) |
| `fortigate_sbg_external_interface` | `port2` | 🟢 | Nom de l'interface externe (Internet) |

### Options FortiGate

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `enable_nat_docker_rbx` | `true` | 🟢 | Activer NAT/SNAT pour VM Docker RBX vers Internet |
| `enable_nat_docker_sbg` | `true` | 🟢 | Activer NAT/SNAT pour VM Docker SBG vers Internet |
| `enable_fortigate_logging` | `true` | 🟢 | Activer logging des règles firewall |

**Génération API Token FortiGate** :
```bash
# Via FortiGate CLI
config system api-user
    edit "terraform-api"
        set accprofile "super_admin"
        set vdom "root"
        set schedule "always"
        config trusthost
            edit 1
                set ipv4-trusthost 0.0.0.0/0
            next
        end
    next
end

# Via FortiGate UI : System > Administrators > Create New > REST API Admin
```

---

## 9. Infrastructure OVH VMware - Configuration Zerto VPG

Variables pour la configuration des Virtual Protection Groups (VPG) Zerto.

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `zerto_site_id_rbx` | `rbx-site-12345` | 🟢 | Identifiant du site Zerto RBX (depuis Zerto UI) |
| `zerto_site_id_sbg` | `sbg-site-67890` | 🟢 | Identifiant du site Zerto SBG (depuis Zerto UI) |
| `zerto_rpo_seconds` | `300` | 🟢 | RPO (Recovery Point Objective) en secondes (5 min) |
| `zerto_journal_hours` | `24` | 🟢 | Rétention du journal Zerto en heures |
| `zerto_test_interval_hours` | `168` | 🟢 | Intervalle entre tests de failover (168h = 7 jours) |
| `zerto_priority` | `High` | 🟢 | Priorité de réplication (Low, Medium, High) |
| `zerto_enable_compression` | `true` | 🟢 | Activer compression des données répliquées |
| `zerto_enable_encryption` | `true` | 🟢 | Activer chiffrement AES-256 des données répliquées |
| `zerto_wan_acceleration` | `true` | 🟢 | Activer accélération WAN (optimisation débit) |

**Notes Zerto** :
- Les IDs de sites Zerto sont récupérables via : Zerto UI → Sites → Site Identifier
- RPO minimum : 300 secondes (5 minutes)
- Journal minimum : 1 heure (24h recommandé pour flexibilité recovery)

---

## 10. Infrastructure OVH VMware - Sécurité

Variables de configuration sécurité pour toutes les VMs.

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `enable_firewall` | `true` | 🟢 | Activer UFW (Uncomplicated Firewall) sur les VMs |
| `allowed_ssh_cidrs` | `["10.0.0.0/8"]` | 🟢 | CIDRs autorisés pour SSH (restreindre en prod) |
| `enable_automatic_updates` | `true` | 🟢 | Activer mises à jour automatiques de sécurité Ubuntu |

**Recommandations sécurité** :
- `allowed_ssh_cidrs` : Restreindre au réseau de management uniquement en production
- Exemple production : `["10.50.0.0/24"]` (réseau bastion/jump server)
- Fail2ban est activé automatiquement (3 tentatives SSH max → ban 1h)

---

## 11. Infrastructure OVH VMware - Configuration générale

Variables métier et tagging.

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `environment` | `prod` | 🟢 | Environnement (dev, test, staging, prod) |
| `project_name` | `pra` | 🟢 | Nom du projet pour tagging et organisation |
| `owner` | `devops-team` | 🟢 | Propriétaire ou équipe responsable |

---

## Mapping vers fichiers .env

Les variables Terraform peuvent être exportées depuis fichiers .env via :

```bash
# Charger depuis .env et .env-protected
source scripts/utils/load-env.sh --with-protected --export-terraform

# Vérifier export
env | grep TF_VAR_
```

**Convention naming** :
- Variable Terraform : `vsphere_rbx_server`
- Variable environnement : `TF_VAR_vsphere_rbx_server`

---

## Scripts de déploiement

### Déploiement complet

```bash
# Prérequis
cd terraform/ovh-infrastructure
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Configurer toutes les variables

# Déploiement automatisé
./scripts/deploy-ovh-infrastructure.sh

# Déploiement sans confirmation (CI/CD)
./scripts/deploy-ovh-infrastructure.sh --auto-approve
```

### Destruction complète

```bash
# Destruction avec confirmation
./scripts/destroy-ovh-infrastructure.sh

# Destruction sans confirmation (DANGEREUX)
./scripts/destroy-ovh-infrastructure.sh --auto-approve
```

---

## Checklist avant déploiement

- [ ] Fichier `terraform.tfvars` créé depuis `terraform.tfvars.example`
- [ ] Credentials vSphere RBX et SBG configurés
- [ ] API Tokens FortiGate RBX et SBG générés
- [ ] IDs sites Zerto récupérés (via Zerto UI)
- [ ] Clé SSH publique générée : `ssh-keygen -t rsa -b 4096`
- [ ] Mots de passe MySQL root et app respectent min 16 caractères
- [ ] Templates Ubuntu 22.04 disponibles dans vCenter
- [ ] vRack OVH configuré manuellement (VLANs 100, 200, 900)
- [ ] Distributed Switches vSphere créés (RBX + SBG)
- [ ] Quotas vSphere suffisants : 4 VMs, 16 vCPUs, 48 Go RAM, 600 Go stockage

---

## Références

- ADR : `Documentation/adr/2025-12-30-infrastructure-applicative-ovh-vmware.md`
- Documentation fonctionnelle : `Documentation/features/ovh-vmware-infrastructure/functional.md`
- Documentation technique : `Documentation/features/ovh-vmware-infrastructure/technical.md`
- Code Terraform : `terraform/ovh-infrastructure/`
- Modules : `modules/06-ovh-vm-docker/`, `modules/07-ovh-vm-mysql/`
- Playbooks Ansible : `ansible/playbooks/ovh-infrastructure/`
