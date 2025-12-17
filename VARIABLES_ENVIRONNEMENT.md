# Variables d'Environnement - POC PRA

Ce document centralise toutes les variables d'environnement utilisées dans le projet POC PRA (Proof of Concept - Plan de Reprise d'Activité). Les variables sont organisées par brique technique avec leur niveau de sensibilité et des exemples de valeurs.

## Table des matières

1. [Azure VPN Gateway](#1-azure-vpn-gateway)
2. [StrongSwan VM (Simulation On-Premises)](#2-strongswan-vm-simulation-on-premises)
3. [OVHCloud Infrastructure (RBX & SBG)](#3-ovhcloud-infrastructure-rbx--sbg)
4. [FortiGate](#4-fortigate)
5. [vCenter VMware](#5-vcenter-vmware)
6. [Zerto - Réplication & VPG](#6-zerto---réplication--vpg)
7. [Zerto - Emergency Backup (Veeam)](#7-zerto---emergency-backup-veeam)
8. [Zerto - Monitoring](#8-zerto---monitoring)
9. [Zerto - Network](#9-zerto---network)
10. [Zerto - Scripts de Failover](#10-zerto---scripts-de-failover)
11. [Configuration Générale](#11-configuration-générale)
12. [Azure Authentication (Provider)](#12-azure-authentication-provider)
13. [Implémentation sur GitLab CI](#implémentation-sur-gitlab-ci)
14. [Implémentation sur GitHub Actions](#implémentation-sur-github-actions)
15. [Guide d'Implémentation CI/CD sur GitLab](#guide-dimplémentation-cicd-sur-gitlab)

---

## Légende des niveaux de sensibilité

| Niveau | Description |
|--------|-------------|
| 🔴 **Sensible** | Credentials, clés API, tokens, mots de passe, PSK - À stocker dans un vault sécurisé |
| 🟠 **Moyennement sensible** | Adresses IP publiques, noms d'hôtes, configuration réseau - À protéger mais moins critique |
| 🟢 **Pas sensible** | Configuration générale, noms de ressources, paramètres techniques publics |

---

## 1. Azure VPN Gateway

Variables pour le déploiement de la passerelle VPN Azure.

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `azure_location` | `francecentral` | 🟢 | Région Azure pour déployer le VPN Gateway |
| `azure_vnet_cidr` | `10.1.0.0/16` | 🟢 | CIDR du réseau virtuel Azure |
| `azure_gateway_subnet_cidr` | `10.1.255.0/24` | 🟢 | CIDR du sous-réseau GatewaySubnet (requis par Azure) |
| `azure_default_subnet_cidr` | `10.1.1.0/24` | 🟢 | CIDR du sous-réseau par défaut pour les VMs |
| `vpn_gateway_sku` | `VpnGw1` | 🟢 | SKU de la passerelle VPN (VpnGw1 à VpnGw5) |
| `vpn_gateway_active_active` | `false` | 🟢 | Active le mode Active-Active pour la haute disponibilité |
| `enable_bgp` | `true` | 🟢 | Active le protocole BGP pour le routage dynamique |
| `azure_bgp_asn` | `65515` | 🟢 | Numéro AS (Autonomous System) BGP pour Azure |

---

## 2. StrongSwan VM (Simulation On-Premises)

Variables pour la VM StrongSwan qui simule un site on-premises avec IPsec.

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `deploy_strongswan` | `true` | 🟢 | Active le déploiement de la VM StrongSwan |
| `onprem_location` | `francecentral` | 🟢 | Région Azure pour déployer la VM StrongSwan |
| `onprem_vnet_cidr` | `192.168.0.0/16` | 🟢 | CIDR du réseau on-premises simulé |
| `onprem_subnet_cidr` | `192.168.1.0/24` | 🟢 | CIDR du sous-réseau on-premises |
| `strongswan_vm_size` | `Standard_B1s` | 🟢 | Taille de la VM Azure (SKU) |
| `ipsec_psk_strongswan` | `MyStr0ng!PSK#2024` | 🔴 | Pre-Shared Key pour le tunnel IPsec StrongSwan |
| `ipsec_policy_strongswan.dh_group` | `DHGroup14` | 🟢 | Groupe Diffie-Hellman pour IKE Phase 1 |
| `ipsec_policy_strongswan.ike_encryption` | `AES256` | 🟢 | Algorithme de chiffrement IKE Phase 1 |
| `ipsec_policy_strongswan.ike_integrity` | `SHA256` | 🟢 | Algorithme d'intégrité IKE Phase 1 |
| `ipsec_policy_strongswan.ipsec_encryption` | `AES256` | 🟢 | Algorithme de chiffrement IPsec Phase 2 |
| `ipsec_policy_strongswan.ipsec_integrity` | `SHA256` | 🟢 | Algorithme d'intégrité IPsec Phase 2 |
| `ipsec_policy_strongswan.pfs_group` | `None` | 🟢 | Groupe Perfect Forward Secrecy (None, PFS2048, etc.) |
| `ipsec_policy_strongswan.sa_lifetime` | `3600` | 🟢 | Durée de vie de la Security Association (secondes) |
| `ipsec_policy_strongswan.sa_datasize` | `102400000` | 🟢 | Taille maximale de données avant rekey (KB) |

---

## 3. OVHCloud Infrastructure (RBX & SBG)

Variables pour les tunnels IPsec et BGP vers les datacenters OVHCloud Roubaix (RBX) et Strasbourg (SBG).

### 3.1 Site RBX (Roubaix - Site Principal)

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `deploy_ovh_rbx` | `false` | 🟢 | Active le déploiement du tunnel vers RBX |
| `ovh_rbx_public_ip` | `51.210.100.50` | 🟠 | Adresse IP publique du FortiGate RBX |
| `ovh_rbx_mgmt_ip` | `192.168.10.1` | 🟠 | Adresse IP de management du FortiGate RBX |
| `ovh_rbx_bgp_asn` | `65001` | 🟢 | Numéro AS BGP pour le site RBX |
| `ovh_rbx_bgp_peer_ip` | `169.254.30.2` | 🟢 | Adresse IP de peering BGP (APIPA) pour RBX |
| `ipsec_psk_rbx` | `RBX#SecurePSK!2024` | 🔴 | Pre-Shared Key pour le tunnel IPsec vers RBX |

### 3.2 Site SBG (Strasbourg - Site Backup)

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `deploy_ovh_sbg` | `false` | 🟢 | Active le déploiement du tunnel vers SBG |
| `ovh_sbg_public_ip` | `51.210.200.75` | 🟠 | Adresse IP publique du FortiGate SBG |
| `ovh_sbg_mgmt_ip` | `192.168.20.1` | 🟠 | Adresse IP de management du FortiGate SBG |
| `ovh_sbg_bgp_asn` | `65002` | 🟢 | Numéro AS BGP pour le site SBG |
| `ovh_sbg_bgp_peer_ip` | `169.254.31.2` | 🟢 | Adresse IP de peering BGP (APIPA) pour SBG |
| `ipsec_psk_sbg` | `SBG#SecurePSK!2024` | 🔴 | Pre-Shared Key pour le tunnel IPsec vers SBG |

### 3.3 Politique IPsec pour FortiGate

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `ipsec_policy_fortigate.dh_group` | `DHGroup14` | 🟢 | Groupe Diffie-Hellman pour FortiGate |
| `ipsec_policy_fortigate.ike_encryption` | `AES256` | 🟢 | Chiffrement IKE Phase 1 pour FortiGate |
| `ipsec_policy_fortigate.ike_integrity` | `SHA256` | 🟢 | Intégrité IKE Phase 1 pour FortiGate |
| `ipsec_policy_fortigate.ipsec_encryption` | `AES256` | 🟢 | Chiffrement IPsec Phase 2 pour FortiGate |
| `ipsec_policy_fortigate.ipsec_integrity` | `SHA256` | 🟢 | Intégrité IPsec Phase 2 pour FortiGate |
| `ipsec_policy_fortigate.pfs_group` | `PFS2048` | 🟢 | Perfect Forward Secrecy pour FortiGate |
| `ipsec_policy_fortigate.sa_lifetime` | `27000` | 🟢 | Durée de vie SA (secondes) - Plus long pour stabilité |
| `ipsec_policy_fortigate.sa_datasize` | `102400000` | 🟢 | Taille maximale de données avant rekey (KB) |

---

## 4. FortiGate

Variables de configuration pour les FortiGate RBX et SBG (gestion réseau, firewall, VPN).

### 4.1 FortiGate RBX

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `rbx_fortigate_ip` | `10.1.0.1` | 🟠 | Adresse IP interne du FortiGate RBX |
| `rbx_fortigate_api_key` | `fgt-api-key-rbx-abc123xyz` | 🔴 | Clé API pour l'administration du FortiGate RBX |
| `rbx_fortigate_vip_range` | `10.1.100.0/24` | 🟢 | Plage d'IP virtuelles (VIP) pour la réplication Zerto |
| `rbx_fortigate_internal_if` | `port1` | 🟢 | Interface interne du FortiGate RBX |
| `rbx_fortigate_external_if` | `port2` | 🟢 | Interface externe du FortiGate RBX |

### 4.2 FortiGate SBG

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `sbg_fortigate_ip` | `10.2.0.1` | 🟠 | Adresse IP interne du FortiGate SBG |
| `sbg_fortigate_api_key` | `fgt-api-key-sbg-def456uvw` | 🔴 | Clé API pour l'administration du FortiGate SBG |
| `sbg_fortigate_vip_range` | `10.2.100.0/24` | 🟢 | Plage d'IP virtuelles (VIP) pour la réplication Zerto |
| `sbg_fortigate_internal_if` | `port1` | 🟢 | Interface interne du FortiGate SBG |
| `sbg_fortigate_external_if` | `port2` | 🟢 | Interface externe du FortiGate SBG |

### 4.3 Configuration Générale FortiGate

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `fortigate_mgmt_port` | `443` | 🟢 | Port de management HTTPS pour les FortiGate |

---

## 5. vCenter VMware

Variables d'authentification et de configuration pour les vCenter RBX et SBG.

### 5.1 vCenter RBX (Roubaix)

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `vcenter_rbx_server` | `pcc-xxx-xxx-xxx.ovh.com` | 🟠 | Nom d'hôte du vCenter RBX (OVH Private Cloud) |
| `vcenter_rbx_user` | `admin@vsphere.local` | 🟠 | Nom d'utilisateur administrateur vCenter RBX |
| `vcenter_rbx_password` | `MyVcenterP@ssw0rd!` | 🔴 | Mot de passe administrateur vCenter RBX |
| `vcenter_rbx_datacenter` | `Datacenter-RBX` | 🟢 | Nom du datacenter dans vCenter RBX |
| `vcenter_rbx_cluster` | `Cluster1` | 🟢 | Nom du cluster dans vCenter RBX |

### 5.2 vCenter SBG (Strasbourg)

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `vcenter_sbg_server` | `pcc-yyy-yyy-yyy.ovh.com` | 🟠 | Nom d'hôte du vCenter SBG (OVH Private Cloud) |
| `vcenter_sbg_user` | `admin@vsphere.local` | 🟠 | Nom d'utilisateur administrateur vCenter SBG |
| `vcenter_sbg_password` | `MyVcenterP@ssw0rd!` | 🔴 | Mot de passe administrateur vCenter SBG |
| `vcenter_sbg_datacenter` | `Datacenter-SBG` | 🟢 | Nom du datacenter dans vCenter SBG |
| `vcenter_sbg_cluster` | `Cluster1` | 🟢 | Nom du cluster dans vCenter SBG |

---

## 6. Zerto - Réplication & VPG

Variables pour la configuration de Zerto Virtual Protection Groups (VPG) et de la réplication.

### 6.1 Configuration Générale Zerto

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `zerto_api_endpoint` | `https://zerto-api.ovh.net` | 🟠 | URL de l'API Zerto OVHCloud |
| `zerto_api_token` | `zrt-token-abc123xyz456` | 🔴 | Token d'authentification API Zerto |
| `zerto_site_id_rbx` | `rbx-site-12345` | 🟢 | Identifiant du site Zerto RBX |
| `zerto_site_id_sbg` | `sbg-site-67890` | 🟢 | Identifiant du site Zerto SBG |

### 6.2 Paramètres de Réplication

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `zerto_rpo_seconds` | `300` | 🟢 | RPO (Recovery Point Objective) en secondes (5 minutes) |
| `zerto_journal_hours` | `24` | 🟢 | Rétention du journal Zerto en heures |
| `zerto_test_interval` | `168` | 🟢 | Intervalle entre les tests de failover (168h = 7 jours) |
| `zerto_priority_high` | `High` | 🟢 | Priorité de réplication (Low/Medium/High) |
| `zerto_enable_compression` | `true` | 🟢 | Active la compression des données répliquées |
| `zerto_enable_encryption` | `true` | 🟢 | Active le chiffrement des données répliquées |
| `zerto_wan_acceleration` | `true` | 🟢 | Active l'accélération WAN pour la réplication |

### 6.3 Configuration VMs Protégées - RBX

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `rbx_protected_vms` | Voir structure ci-dessous | 🟢 | Liste des VMs à protéger depuis RBX |

**Structure d'un objet VM :**
```hcl
{
  name            = "rbx-app-prod-01"
  vm_name_vcenter = "rbx-app-prod-01"
  boot_order      = 2
  failover_ip     = "10.1.1.10"
  failover_subnet = "10.1.1.0/24"
  description     = "Application de production principale"
}
```

### 6.4 Configuration Réseau - RBX

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `rbx_target_network_name` | `VM Network` | 🟢 | Nom du réseau vSphere cible dans RBX |
| `rbx_journal_datastore` | `datastore1` | 🟢 | Datastore pour le journal Zerto dans RBX |
| `rbx_network_ranges` | `["10.1.0.0/16", "10.1.1.0/24"]` | 🟢 | Plages réseau dans RBX |
| `rbx_failover_network_config.gateway` | `10.1.1.1` | 🟢 | Passerelle par défaut après failover |
| `rbx_failover_network_config.dns_primary` | `213.186.33.99` | 🟢 | DNS primaire (OVH DNS) |
| `rbx_failover_network_config.dns_secondary` | `8.8.8.8` | 🟢 | DNS secondaire (Google DNS) |
| `rbx_failover_network_config.domain_name` | `rbx.prod.local` | 🟢 | Nom de domaine pour les VMs après failover |

### 6.5 Configuration Réseau - SBG

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `sbg_target_network_name` | `VM Network` | 🟢 | Nom du réseau vSphere cible dans SBG |
| `sbg_journal_datastore` | `datastore1` | 🟢 | Datastore pour le journal Zerto dans SBG |
| `sbg_network_ranges` | `["10.2.0.0/16", "10.2.1.0/24"]` | 🟢 | Plages réseau dans SBG |
| `sbg_failover_network_config.gateway` | `10.2.1.1` | 🟢 | Passerelle par défaut après failover |
| `sbg_failover_network_config.dns_primary` | `213.186.33.99` | 🟢 | DNS primaire (OVH DNS) |
| `sbg_failover_network_config.dns_secondary` | `8.8.8.8` | 🟢 | DNS secondaire (Google DNS) |
| `sbg_failover_network_config.domain_name` | `sbg.prod.local` | 🟢 | Nom de domaine pour les VMs après failover |

---

## 7. Zerto - Emergency Backup (Veeam)

Variables pour les backups d'urgence utilisant Veeam Backup & Replication.

### 7.1 Configuration Veeam

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `veeam_api_endpoint` | `https://veeam-server:9419` | 🟠 | URL de l'API Veeam Backup & Replication |
| `veeam_api_token` | `veeam-token-abc123xyz` | 🔴 | Token d'authentification API Veeam |
| `veeam_repository_local` | `Local-Repository` | 🟢 | Nom du repository local Veeam |

### 7.2 Backup Local

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `enable_local_backup` | `true` | 🟢 | Active les backups sur repository local |
| `backup_schedule_local` | `0 2,14 * * *` | 🟢 | Schedule cron pour backups locaux (02:00 et 14:00) |
| `backup_times_local` | `["02:00", "14:00"]` | 🟢 | Heures de backup local |
| `local_retention_days` | `7` | 🟢 | Rétention des backups locaux (3-30 jours) |

### 7.3 Backup S3 (OVH Object Storage)

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `enable_s3_backup` | `true` | 🟢 | Active les backups vers S3 Object Storage |
| `ovh_project_id` | `abc123def456ghi789` | 🟠 | ID du projet OVH Public Cloud |
| `s3_region` | `GRA` | 🟢 | Région S3 (GRA/SBG/BHS/DE/UK/WAW) |
| `s3_endpoint` | `https://s3.gra.cloud.ovh.net` | 🟢 | Endpoint S3 OVH Object Storage |
| `s3_immutable` | `true` | 🟢 | Active l'immutabilité S3 (WORM - Write Once Read Many) |
| `s3_immutable_days` | `30` | 🟢 | Durée d'immutabilité S3 (7-90 jours) |
| `s3_retention_days` | `30` | 🟢 | Rétention totale des backups S3 |
| `backup_schedule_s3` | `0 4,16 * * *` | 🟢 | Schedule cron pour backups S3 (04:00 et 16:00) |
| `backup_times_s3` | `["04:00", "16:00"]` | 🟢 | Heures de backup S3 |

### 7.4 Paramètres de Performance

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `enable_encryption` | `true` | 🟢 | Active le chiffrement des backups |
| `encryption_algorithm` | `AES256` | 🟢 | Algorithme de chiffrement (AES256/AES128) |
| `compression_level` | `Optimal` | 🟢 | Niveau de compression (None/Dedupe/Optimal/High/Extreme) |
| `parallel_tasks` | `4` | 🟢 | Nombre de tâches parallèles (1-32) |
| `bandwidth_throttling_enabled` | `false` | 🟢 | Active la limitation de bande passante |
| `bandwidth_throttling_mbps` | `100` | 🟢 | Limite de bande passante (10-10000 Mbps) |

### 7.5 Monitoring et Alertes

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `enable_monitoring` | `true` | 🟢 | Active le monitoring des backups |
| `alert_webhook_url` | `https://hooks.slack.com/...` | 🟠 | URL webhook pour alertes (Slack/Teams) |
| `alert_emails` | `["ops@example.com"]` | 🟢 | Liste d'emails pour les alertes backup |

---

## 8. Zerto - Monitoring

Variables pour le monitoring des VPG Zerto et des métriques de réplication.

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `vpg_rbx_to_sbg_id` | `vpg-rbx-sbg-12345` | 🟢 | ID du VPG RBX → SBG à monitorer |
| `vpg_sbg_to_rbx_id` | `vpg-sbg-rbx-67890` | 🟢 | ID du VPG SBG → RBX à monitorer |
| `alert_thresholds.rpo_warning_seconds` | `360` | 🟢 | Seuil warning pour RPO (6 minutes) |
| `alert_thresholds.rpo_critical_seconds` | `600` | 🟢 | Seuil critique pour RPO (10 minutes) |
| `alert_thresholds.journal_usage_warning` | `70` | 🟢 | Seuil warning utilisation journal (70%) |
| `alert_thresholds.journal_usage_critical` | `90` | 🟢 | Seuil critique utilisation journal (90%) |
| `alert_thresholds.bandwidth_warning_mbps` | `80` | 🟢 | Seuil warning bande passante (80 Mbps) |
| `alert_thresholds.bandwidth_critical_mbps` | `100` | 🟢 | Seuil critique bande passante (100 Mbps) |
| `notification_emails` | `["ops@example.com"]` | 🟢 | Emails pour notifications monitoring |
| `webhook_url` | `https://hooks.slack.com/...` | 🟠 | Webhook pour notifications (Slack/Teams) |
| `enable_custom_metrics` | `true` | 🟢 | Active les métriques personnalisées |
| `metrics_retention_days` | `90` | 🟢 | Rétention des métriques (jours) |

---

## 9. Zerto - Network

Variables pour la configuration réseau Zerto (règles firewall FortiGate).

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `rbx_fortigate.ip_address` | `10.1.0.1` | 🟠 | IP du FortiGate RBX |
| `rbx_fortigate.mgmt_port` | `443` | 🟢 | Port de management FortiGate RBX |
| `rbx_fortigate.api_key` | `fgt-api-key-rbx-abc123` | 🔴 | Clé API FortiGate RBX |
| `rbx_fortigate.vip_range` | `10.1.100.0/24` | 🟢 | Plage VIP pour réplication Zerto RBX |
| `rbx_fortigate.internal_interface` | `port1` | 🟢 | Interface interne FortiGate RBX |
| `rbx_fortigate.external_interface` | `port2` | 🟢 | Interface externe FortiGate RBX |
| `sbg_fortigate.ip_address` | `10.2.0.1` | 🟠 | IP du FortiGate SBG |
| `sbg_fortigate.mgmt_port` | `443` | 🟢 | Port de management FortiGate SBG |
| `sbg_fortigate.api_key` | `fgt-api-key-sbg-def456` | 🔴 | Clé API FortiGate SBG |
| `sbg_fortigate.vip_range` | `10.2.100.0/24` | 🟢 | Plage VIP pour réplication Zerto SBG |
| `sbg_fortigate.internal_interface` | `port1` | 🟢 | Interface interne FortiGate SBG |
| `sbg_fortigate.external_interface` | `port2` | 🟢 | Interface externe FortiGate SBG |

---

## 10. Zerto - Scripts de Failover

Variables d'environnement pour les scripts shell de failover Zerto.

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `ZERTO_API_ENDPOINT` | `https://zerto-api.ovh.net` | 🟠 | URL de l'API Zerto |
| `ZERTO_API_TOKEN` | `zrt-token-abc123` | 🔴 | Token d'authentification API Zerto |
| `ZERTO_USERNAME` | `admin@zerto` | 🔴 | Nom d'utilisateur Zerto (auth alternative) |
| `ZERTO_PASSWORD` | `ZertoP@ssw0rd!` | 🔴 | Mot de passe Zerto (auth alternative) |
| `VPG_NAME_RBX_TO_SBG` | `VPG-RBX-to-SBG-production` | 🟢 | Nom du VPG pour failover RBX → SBG |
| `VPG_NAME_SBG_TO_RBX` | `VPG-SBG-to-RBX-production` | 🟢 | Nom du VPG pour failover SBG → RBX |
| `RBX_FORTIGATE_IP` | `10.1.0.1` | 🟠 | IP du FortiGate RBX |
| `RBX_FORTIGATE_API_KEY` | `fgt-api-key-rbx-abc123` | 🔴 | Clé API FortiGate RBX |
| `SBG_FORTIGATE_IP` | `10.2.0.1` | 🟠 | IP du FortiGate SBG |
| `SBG_FORTIGATE_API_KEY` | `fgt-api-key-sbg-def456` | 🔴 | Clé API FortiGate SBG |
| `WEBHOOK_URL` | `https://hooks.slack.com/...` | 🟠 | Webhook Slack/Teams pour notifications |
| `ALERT_EMAILS` | `ops@exemple.com` | 🟢 | Emails pour les alertes de failover |
| `LOG_LEVEL` | `INFO` | 🟢 | Niveau de log (DEBUG/INFO/WARNING/ERROR) |

---

## 11. Configuration Générale

Variables de configuration globale du projet.

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `environment` | `dev` | 🟢 | Environnement de déploiement (dev/test/staging/prod) |
| `project_name` | `pra` | 🟢 | Nom du projet |
| `owner` | `poc-pra-team` | 🟢 | Propriétaire du projet (équipe/email) |
| `admin_username` | `azureuser` | 🟢 | Nom d'utilisateur admin pour les VMs |
| `ssh_public_key` | `ssh-rsa AAAAB3NzaC1...` | 🟠 | Clé SSH publique (contenu direct) |
| `ssh_public_key_path` | `~/.ssh/id_rsa.pub` | 🟠 | Chemin vers la clé SSH publique |
| `ssh_source_address_prefix` | `*` | 🟠 | Préfixe d'adresse IP autorisée pour SSH (⚠️ `*` = non sécurisé) |
| `deploy_ovh_infrastructure` | `false` | 🟢 | Active le déploiement de l'infrastructure VMware OVH |
| `common_tags` | Voir ci-dessous | 🟢 | Tags communs pour toutes les ressources |

**Exemple de tags communs :**
```hcl
{
  "Project"     = "POC-PRA"
  "ManagedBy"   = "Terraform"
  "Solution"    = "Zerto"
  "Platform"    = "VMware-vSphere"
  "CostCenter"  = "IT-Infrastructure"
  "Owner"       = "ops-team@exemple.com"
}
```

---

## 12. Azure Authentication (Provider)

Variables d'environnement pour l'authentification Azure Terraform Provider (Service Principal).

| Variable | Exemple de valeur | Sensibilité | Description |
|----------|-------------------|-------------|-------------|
| `ARM_SUBSCRIPTION_ID` | `12345678-1234-1234-1234-123456789abc` | 🔴 | ID de la souscription Azure |
| `ARM_CLIENT_ID` | `87654321-4321-4321-4321-cba987654321` | 🔴 | ID du Service Principal Azure (Application ID) |
| `ARM_CLIENT_SECRET` | `MyS3cretV@lue!2024` | 🔴 | Secret du Service Principal Azure |
| `ARM_TENANT_ID` | `abcdef12-3456-7890-abcd-ef1234567890` | 🔴 | ID du tenant Azure Active Directory |

---

## Implémentation sur GitLab CI

### Vue d'ensemble

GitLab CI utilise un fichier `.gitlab-ci.yml` à la racine du projet pour définir les pipelines. Les variables d'environnement sensibles sont stockées dans **GitLab CI/CD Variables** (Settings > CI/CD > Variables).

### Configuration des variables sensibles dans GitLab

#### 1. Accéder aux variables CI/CD

```
Projet GitLab → Settings → CI/CD → Variables → Expand
```

#### 2. Ajouter les variables sensibles

Pour chaque variable sensible (🔴), créez une variable dans GitLab :

| Clé GitLab | Type | Protégée | Masquée | Description |
|------------|------|----------|---------|-------------|
| `TF_VAR_ipsec_psk_strongswan` | Variable | ✅ | ✅ | PSK StrongSwan |
| `TF_VAR_ipsec_psk_rbx` | Variable | ✅ | ✅ | PSK RBX |
| `TF_VAR_ipsec_psk_sbg` | Variable | ✅ | ✅ | PSK SBG |
| `TF_VAR_vcenter_rbx_password` | Variable | ✅ | ✅ | Mot de passe vCenter RBX |
| `TF_VAR_vcenter_sbg_password` | Variable | ✅ | ✅ | Mot de passe vCenter SBG |
| `TF_VAR_zerto_api_token` | Variable | ✅ | ✅ | Token API Zerto |
| `TF_VAR_rbx_fortigate_api_key` | Variable | ✅ | ✅ | API Key FortiGate RBX |
| `TF_VAR_sbg_fortigate_api_key` | Variable | ✅ | ✅ | API Key FortiGate SBG |
| `TF_VAR_veeam_api_token` | Variable | ✅ | ✅ | Token API Veeam |
| `ARM_SUBSCRIPTION_ID` | Variable | ✅ | ✅ | Azure Subscription ID |
| `ARM_CLIENT_ID` | Variable | ✅ | ✅ | Azure Client ID |
| `ARM_CLIENT_SECRET` | Variable | ✅ | ✅ | Azure Client Secret |
| `ARM_TENANT_ID` | Variable | ✅ | ✅ | Azure Tenant ID |

**Options importantes :**
- **Protégée (Protected)** : La variable n'est disponible que sur les branches protégées (main, production)
- **Masquée (Masked)** : La valeur est masquée dans les logs CI/CD
- **Type File** : Pour les clés SSH ou certificats, utilisez le type "File"

#### 3. Variables non-sensibles dans le code

Les variables non-sensibles (🟢 et 🟠 moyennement sensibles) peuvent être définies directement dans `.gitlab-ci.yml` :

```yaml
variables:
  TF_VAR_environment: "production"
  TF_VAR_azure_location: "francecentral"
  TF_VAR_project_name: "pra"
  TF_VAR_enable_bgp: "true"
```

### Exemple de structure `.gitlab-ci.yml`

```yaml
stages:
  - validate
  - plan
  - deploy
  - test

variables:
  # Variables Terraform non-sensibles
  TF_VAR_environment: "production"
  TF_VAR_azure_location: "francecentral"
  TF_VAR_project_name: "pra"
  TF_VAR_enable_bgp: "true"

  # Configuration Terraform
  TF_ROOT: "${CI_PROJECT_DIR}/terraform"
  TF_STATE_NAME: "default"

# Template pour les jobs Terraform
.terraform_template:
  image: hashicorp/terraform:1.6
  before_script:
    - cd ${TF_ROOT}
    - terraform init -backend-config="key=${TF_STATE_NAME}"
  only:
    - main
    - develop

# Validation Terraform
terraform:validate:
  extends: .terraform_template
  stage: validate
  script:
    - terraform fmt -check
    - terraform validate

# Plan Terraform
terraform:plan:
  extends: .terraform_template
  stage: plan
  script:
    - terraform plan -out=tfplan
  artifacts:
    paths:
      - ${TF_ROOT}/tfplan
    expire_in: 1 week

# Apply Terraform (manuel pour production)
terraform:apply:
  extends: .terraform_template
  stage: deploy
  script:
    - terraform apply -auto-approve tfplan
  dependencies:
    - terraform:plan
  when: manual
  only:
    - main

# Tests post-déploiement
test:connectivity:
  stage: test
  image: alpine:latest
  before_script:
    - apk add --no-cache curl jq
  script:
    - echo "Testing IPsec tunnels..."
    - curl -X GET "${ZERTO_API_ENDPOINT}/v1/vpgs" -H "Authorization: Bearer ${TF_VAR_zerto_api_token}"
  dependencies:
    - terraform:apply
  only:
    - main
```

### Gestion des environnements multiples

Pour gérer plusieurs environnements (dev, staging, production) :

```yaml
# Job pour l'environnement de développement
deploy:dev:
  extends: .terraform_template
  stage: deploy
  variables:
    TF_VAR_environment: "dev"
    TF_STATE_NAME: "dev"
  environment:
    name: development
  only:
    - develop

# Job pour l'environnement de production
deploy:prod:
  extends: .terraform_template
  stage: deploy
  variables:
    TF_VAR_environment: "production"
    TF_STATE_NAME: "prod"
  environment:
    name: production
  when: manual
  only:
    - main
```

### Bonnes pratiques GitLab CI

1. **Ne jamais committer de secrets** dans le code
2. **Utiliser les variables protégées** pour les branches main/production
3. **Activer le masquage** pour toutes les variables sensibles
4. **Utiliser `when: manual`** pour les déploiements en production
5. **Stocker le state Terraform** dans GitLab Managed Terraform State ou un backend S3
6. **Activer les artifacts** pour le plan Terraform (review avant apply)

---

## Implémentation sur GitHub Actions

### Vue d'ensemble

GitHub Actions utilise des fichiers YAML dans `.github/workflows/` et stocke les secrets dans **Settings > Secrets and variables > Actions**.

### Configuration des secrets dans GitHub

#### 1. Accéder aux secrets

```
Repository → Settings → Secrets and variables → Actions → New repository secret
```

#### 2. Ajouter les secrets

Pour chaque variable sensible (🔴), créez un secret GitHub :

| Nom du secret | Type | Description |
|---------------|------|-------------|
| `TF_VAR_IPSEC_PSK_STRONGSWAN` | Secret | PSK StrongSwan |
| `TF_VAR_IPSEC_PSK_RBX` | Secret | PSK RBX |
| `TF_VAR_IPSEC_PSK_SBG` | Secret | PSK SBG |
| `TF_VAR_VCENTER_RBX_PASSWORD` | Secret | Mot de passe vCenter RBX |
| `TF_VAR_VCENTER_SBG_PASSWORD` | Secret | Mot de passe vCenter SBG |
| `TF_VAR_ZERTO_API_TOKEN` | Secret | Token API Zerto |
| `TF_VAR_RBX_FORTIGATE_API_KEY` | Secret | API Key FortiGate RBX |
| `TF_VAR_SBG_FORTIGATE_API_KEY` | Secret | API Key FortiGate SBG |
| `TF_VAR_VEEAM_API_TOKEN` | Secret | Token API Veeam |
| `ARM_SUBSCRIPTION_ID` | Secret | Azure Subscription ID |
| `ARM_CLIENT_ID` | Secret | Azure Client ID |
| `ARM_CLIENT_SECRET` | Secret | Azure Client Secret |
| `ARM_TENANT_ID` | Secret | Azure Tenant ID |

**Note** : GitHub Secrets sont automatiquement masqués dans les logs.

#### 3. Variables d'environnement non-sensibles

Les variables non-sensibles peuvent être définies dans **Settings > Secrets and variables > Actions > Variables** (onglet Variables) ou directement dans le workflow.

### Exemple de workflow GitHub Actions

Créer le fichier `.github/workflows/terraform.yml` :

```yaml
name: Terraform CI/CD

on:
  push:
    branches:
      - main
      - develop
  pull_request:
    branches:
      - main

env:
  TF_VERSION: '1.6.0'
  TF_VAR_environment: ${{ github.ref == 'refs/heads/main' && 'production' || 'dev' }}
  TF_VAR_azure_location: 'francecentral'
  TF_VAR_project_name: 'pra'
  TF_VAR_enable_bgp: 'true'

jobs:
  terraform-validate:
    name: Terraform Validate
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ./terraform

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Terraform Format Check
        run: terraform fmt -check -recursive

      - name: Terraform Init
        run: terraform init -backend=false

      - name: Terraform Validate
        run: terraform validate

  terraform-plan:
    name: Terraform Plan
    runs-on: ubuntu-latest
    needs: terraform-validate
    if: github.event_name == 'pull_request' || github.ref == 'refs/heads/develop' || github.ref == 'refs/heads/main'
    defaults:
      run:
        working-directory: ./terraform

    env:
      ARM_SUBSCRIPTION_ID: ${{ secrets.ARM_SUBSCRIPTION_ID }}
      ARM_CLIENT_ID: ${{ secrets.ARM_CLIENT_ID }}
      ARM_CLIENT_SECRET: ${{ secrets.ARM_CLIENT_SECRET }}
      ARM_TENANT_ID: ${{ secrets.ARM_TENANT_ID }}
      TF_VAR_ipsec_psk_strongswan: ${{ secrets.TF_VAR_IPSEC_PSK_STRONGSWAN }}
      TF_VAR_ipsec_psk_rbx: ${{ secrets.TF_VAR_IPSEC_PSK_RBX }}
      TF_VAR_ipsec_psk_sbg: ${{ secrets.TF_VAR_IPSEC_PSK_SBG }}
      TF_VAR_vcenter_rbx_password: ${{ secrets.TF_VAR_VCENTER_RBX_PASSWORD }}
      TF_VAR_vcenter_sbg_password: ${{ secrets.TF_VAR_VCENTER_SBG_PASSWORD }}
      TF_VAR_zerto_api_token: ${{ secrets.TF_VAR_ZERTO_API_TOKEN }}
      TF_VAR_rbx_fortigate_api_key: ${{ secrets.TF_VAR_RBX_FORTIGATE_API_KEY }}
      TF_VAR_sbg_fortigate_api_key: ${{ secrets.TF_VAR_SBG_FORTIGATE_API_KEY }}
      TF_VAR_veeam_api_token: ${{ secrets.TF_VAR_VEEAM_API_TOKEN }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Terraform Init
        run: terraform init

      - name: Terraform Plan
        id: plan
        run: terraform plan -out=tfplan -no-color
        continue-on-error: true

      - name: Upload Terraform Plan
        uses: actions/upload-artifact@v4
        with:
          name: tfplan
          path: terraform/tfplan
          retention-days: 7

      - name: Comment PR with Plan
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          script: |
            const output = `#### Terraform Plan 📋

            <details><summary>Show Plan</summary>

            \`\`\`
            ${{ steps.plan.outputs.stdout }}
            \`\`\`

            </details>

            *Pusher: @${{ github.actor }}, Action: \`${{ github.event_name }}\`, Workflow: \`${{ github.workflow }}\`*`;

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            })

  terraform-apply:
    name: Terraform Apply
    runs-on: ubuntu-latest
    needs: terraform-plan
    if: github.ref == 'refs/heads/main'
    environment: production
    defaults:
      run:
        working-directory: ./terraform

    env:
      ARM_SUBSCRIPTION_ID: ${{ secrets.ARM_SUBSCRIPTION_ID }}
      ARM_CLIENT_ID: ${{ secrets.ARM_CLIENT_ID }}
      ARM_CLIENT_SECRET: ${{ secrets.ARM_CLIENT_SECRET }}
      ARM_TENANT_ID: ${{ secrets.ARM_TENANT_ID }}
      TF_VAR_ipsec_psk_strongswan: ${{ secrets.TF_VAR_IPSEC_PSK_STRONGSWAN }}
      TF_VAR_ipsec_psk_rbx: ${{ secrets.TF_VAR_IPSEC_PSK_RBX }}
      TF_VAR_ipsec_psk_sbg: ${{ secrets.TF_VAR_IPSEC_PSK_SBG }}
      TF_VAR_vcenter_rbx_password: ${{ secrets.TF_VAR_VCENTER_RBX_PASSWORD }}
      TF_VAR_vcenter_sbg_password: ${{ secrets.TF_VAR_VCENTER_SBG_PASSWORD }}
      TF_VAR_zerto_api_token: ${{ secrets.TF_VAR_ZERTO_API_TOKEN }}
      TF_VAR_rbx_fortigate_api_key: ${{ secrets.TF_VAR_RBX_FORTIGATE_API_KEY }}
      TF_VAR_sbg_fortigate_api_key: ${{ secrets.TF_VAR_SBG_FORTIGATE_API_KEY }}
      TF_VAR_veeam_api_token: ${{ secrets.TF_VAR_VEEAM_API_TOKEN }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Terraform Init
        run: terraform init

      - name: Download Terraform Plan
        uses: actions/download-artifact@v4
        with:
          name: tfplan
          path: terraform/

      - name: Terraform Apply
        run: terraform apply -auto-approve tfplan

  test-deployment:
    name: Test Deployment
    runs-on: ubuntu-latest
    needs: terraform-apply
    if: github.ref == 'refs/heads/main'

    env:
      ZERTO_API_ENDPOINT: https://zerto-api.ovh.net
      ZERTO_API_TOKEN: ${{ secrets.TF_VAR_ZERTO_API_TOKEN }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Test Zerto API Connectivity
        run: |
          curl -X GET "${ZERTO_API_ENDPOINT}/v1/vpgs" \
            -H "Authorization: Bearer ${ZERTO_API_TOKEN}" \
            -o vpgs.json

          echo "✅ Zerto API connection successful"
          cat vpgs.json | jq .
```

### Gestion des environnements avec GitHub

Pour utiliser les environnements GitHub (avec protection rules) :

```yaml
jobs:
  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://production.example.com
    steps:
      # ... deployment steps
```

**Configuration de l'environnement** :
1. Repository → Settings → Environments → New environment
2. Créer "production" avec **Required reviewers** (approbation manuelle)
3. Configurer **Deployment branches** (seulement main)

### Bonnes pratiques GitHub Actions

1. **Utiliser GitHub Secrets** pour toutes les variables sensibles
2. **Activer les environments** avec required reviewers pour production
3. **Ne jamais logger les secrets** (`echo $SECRET` est dangereux)
4. **Utiliser des artifacts** pour passer le plan entre jobs
5. **Utiliser `continue-on-error`** pour le plan (permet de commenter les PRs)
6. **Stocker le state Terraform** dans un backend Azure Storage ou S3
7. **Utiliser des actions officielles** (`hashicorp/setup-terraform`, `actions/checkout@v4`)

---

## Guide d'Implémentation CI/CD sur GitLab

Ce guide décrit les étapes complètes pour implémenter une pipeline CI/CD sur GitLab CI pour le projet POC PRA.

### Prérequis

1. **Compte GitLab** avec accès au projet
2. **GitLab Runner** configuré (shared runners ou dedicated)
3. **Service Principal Azure** (pour Terraform Provider)
4. **Accès aux APIs** : Zerto, vCenter, FortiGate, Veeam
5. **Backend Terraform** : GitLab Managed Terraform State ou Azure Storage Account

---

### Étape 1 : Configuration du Backend Terraform

#### Option A : GitLab Managed Terraform State (Recommandé)

1. **Activer le backend GitLab** dans `terraform/backend.tf` :

```hcl
terraform {
  backend "http" {
    address        = "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/terraform/state/${TF_STATE_NAME}"
    lock_address   = "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/terraform/state/${TF_STATE_NAME}/lock"
    unlock_address = "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/terraform/state/${TF_STATE_NAME}/lock"
    username       = "gitlab-ci-token"
    password       = "${CI_JOB_TOKEN}"
    lock_method    = "POST"
    unlock_method  = "DELETE"
    retry_wait_min = 5
  }
}
```

2. **Variables GitLab CI nécessaires** (définies automatiquement) :
   - `CI_API_V4_URL`
   - `CI_PROJECT_ID`
   - `CI_JOB_TOKEN`

#### Option B : Azure Storage Account Backend

1. **Créer un Storage Account** sur Azure (en dehors de Terraform) :

```bash
az storage account create \
  --name pocpratfstate \
  --resource-group pra-tfstate-rg \
  --location francecentral \
  --sku Standard_LRS

az storage container create \
  --name tfstate \
  --account-name pocpratfstate
```

2. **Configurer le backend** dans `terraform/backend.tf` :

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "pra-tfstate-rg"
    storage_account_name = "pocpratfstate"
    container_name       = "tfstate"
    key                  = "pra.terraform.tfstate"
  }
}
```

3. **Ajouter les variables GitLab** :
   - `ARM_ACCESS_KEY` : Clé d'accès au Storage Account (type: Secret, masked)

---

### Étape 2 : Configuration des Variables et Secrets GitLab

#### 2.1 Accéder aux Variables CI/CD

```
Projet GitLab → Settings → CI/CD → Variables → Expand
```

#### 2.2 Créer les variables sensibles

Pour **chaque variable sensible** listée dans les sections précédentes, créer une variable GitLab :

**Variables Azure (🔴 Sensible)** :
| Clé | Valeur (exemple) | Protégée | Masquée | Environnement |
|-----|------------------|----------|---------|---------------|
| `ARM_SUBSCRIPTION_ID` | `12345678-1234-...` | ✅ | ✅ | `production` |
| `ARM_CLIENT_ID` | `87654321-4321-...` | ✅ | ✅ | `production` |
| `ARM_CLIENT_SECRET` | `MyS3cretV@lue!2024` | ✅ | ✅ | `production` |
| `ARM_TENANT_ID` | `abcdef12-3456-...` | ✅ | ✅ | `production` |

**Variables Terraform (🔴 Sensible)** :
| Clé | Valeur (exemple) | Protégée | Masquée | Environnement |
|-----|------------------|----------|---------|---------------|
| `TF_VAR_ipsec_psk_strongswan` | `MyStr0ng!PSK#2024` | ✅ | ✅ | `production` |
| `TF_VAR_ipsec_psk_rbx` | `RBX#SecurePSK!2024` | ✅ | ✅ | `production` |
| `TF_VAR_ipsec_psk_sbg` | `SBG#SecurePSK!2024` | ✅ | ✅ | `production` |
| `TF_VAR_vcenter_rbx_password` | `VcenterP@ss!` | ✅ | ✅ | `production` |
| `TF_VAR_vcenter_sbg_password` | `VcenterP@ss!` | ✅ | ✅ | `production` |
| `TF_VAR_zerto_api_token` | `zrt-token-abc123...` | ✅ | ✅ | `production` |
| `TF_VAR_rbx_fortigate_api_key` | `fgt-api-rbx-123...` | ✅ | ✅ | `production` |
| `TF_VAR_sbg_fortigate_api_key` | `fgt-api-sbg-456...` | ✅ | ✅ | `production` |
| `TF_VAR_veeam_api_token` | `veeam-token-xyz...` | ✅ | ✅ | `production` |

**Clés SSH (🟠 Moyennement sensible)** :
| Clé | Type | Protégée | Environnement |
|-----|------|----------|---------------|
| `TF_VAR_ssh_public_key` | File | ✅ | `production` |

#### 2.3 Variables non-sensibles (directement dans `.gitlab-ci.yml`)

Les variables non-sensibles seront définies dans le fichier `.gitlab-ci.yml` (voir Étape 3).

---

### Étape 3 : Création du fichier `.gitlab-ci.yml`

Créer le fichier `.gitlab-ci.yml` à la racine du projet avec la structure suivante :

#### Structure globale du pipeline

```yaml
# Pipeline CI/CD pour POC PRA - Infrastructure Terraform
# Date: 2024-01-01
# Description: Déploiement automatisé Azure VPN Gateway + OVHCloud + Zerto

image: hashicorp/terraform:1.6

# Stages du pipeline
stages:
  - lint
  - validate
  - plan
  - deploy
  - test
  - destroy

# Variables globales
variables:
  TF_ROOT: "${CI_PROJECT_DIR}/terraform"
  TF_STATE_NAME: "${CI_ENVIRONMENT_NAME}-tfstate"
  TF_VAR_environment: "${CI_ENVIRONMENT_NAME}"
  TF_VAR_project_name: "pra"
  TF_VAR_azure_location: "francecentral"
  TF_VAR_enable_bgp: "true"
  TF_VAR_vpn_gateway_sku: "VpnGw1"
  # Ajoutez d'autres variables non-sensibles ici

# Cache Terraform
cache:
  key: "${CI_COMMIT_REF_SLUG}"
  paths:
    - ${TF_ROOT}/.terraform
    - ${TF_ROOT}/.terraform.lock.hcl

# Avant tous les jobs
before_script:
  - cd ${TF_ROOT}
  - export TF_CLI_ARGS_init="-backend-config=address=${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/terraform/state/${TF_STATE_NAME} -backend-config=lock_address=${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/terraform/state/${TF_STATE_NAME}/lock -backend-config=unlock_address=${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/terraform/state/${TF_STATE_NAME}/lock -backend-config=username=gitlab-ci-token -backend-config=password=${CI_JOB_TOKEN} -backend-config=lock_method=POST -backend-config=unlock_method=DELETE -backend-config=retry_wait_min=5"

### STAGE: LINT ###

# Vérification du formatage Terraform
terraform:fmt:
  stage: lint
  script:
    - terraform fmt -check -recursive -diff
  allow_failure: true
  only:
    - branches
    - merge_requests

# Vérification de sécurité avec tfsec
security:tfsec:
  stage: lint
  image: aquasec/tfsec:latest
  script:
    - tfsec ${TF_ROOT} --format=json --out=tfsec-report.json
    - tfsec ${TF_ROOT}
  artifacts:
    reports:
      json: tfsec-report.json
    paths:
      - tfsec-report.json
    expire_in: 1 week
  allow_failure: true
  only:
    - branches
    - merge_requests

### STAGE: VALIDATE ###

# Validation syntaxique Terraform
terraform:validate:
  stage: validate
  script:
    - terraform init -backend=false
    - terraform validate
  only:
    - branches
    - merge_requests

### STAGE: PLAN ###

# Plan Terraform pour l'environnement de développement
terraform:plan:dev:
  stage: plan
  environment:
    name: development
    action: prepare
  variables:
    TF_VAR_environment: "dev"
    TF_STATE_NAME: "dev"
  script:
    - terraform init
    - terraform plan -out=tfplan-dev
  artifacts:
    paths:
      - ${TF_ROOT}/tfplan-dev
    expire_in: 1 week
  only:
    - develop

# Plan Terraform pour l'environnement de production
terraform:plan:prod:
  stage: plan
  environment:
    name: production
    action: prepare
  variables:
    TF_VAR_environment: "production"
    TF_STATE_NAME: "prod"
  script:
    - terraform init
    - terraform plan -out=tfplan-prod
    - terraform show -json tfplan-prod > tfplan-prod.json
  artifacts:
    paths:
      - ${TF_ROOT}/tfplan-prod
      - ${TF_ROOT}/tfplan-prod.json
    reports:
      terraform: ${TF_ROOT}/tfplan-prod.json
    expire_in: 1 week
  only:
    - main

### STAGE: DEPLOY ###

# Déploiement automatique en développement
terraform:apply:dev:
  stage: deploy
  environment:
    name: development
    url: https://dev.pra.example.com
    auto_stop_in: 1 day
  variables:
    TF_VAR_environment: "dev"
    TF_STATE_NAME: "dev"
  script:
    - terraform init
    - terraform apply -auto-approve tfplan-dev
  dependencies:
    - terraform:plan:dev
  only:
    - develop
  when: on_success

# Déploiement manuel en production (nécessite approbation)
terraform:apply:prod:
  stage: deploy
  environment:
    name: production
    url: https://prod.pra.example.com
  variables:
    TF_VAR_environment: "production"
    TF_STATE_NAME: "prod"
  script:
    - terraform init
    - terraform apply -auto-approve tfplan-prod
    - terraform output -json > terraform-outputs.json
  dependencies:
    - terraform:plan:prod
  artifacts:
    paths:
      - ${TF_ROOT}/terraform-outputs.json
    expire_in: 30 days
  only:
    - main
  when: manual
  allow_failure: false

### STAGE: TEST ###

# Tests de connectivité IPsec
test:ipsec:connectivity:
  stage: test
  image: alpine:latest
  environment:
    name: production
  before_script:
    - apk add --no-cache curl jq bash
  script:
    - echo "🔍 Testing IPsec tunnel connectivity..."
    - echo "Testing Azure VPN Gateway..."
    # Ajoutez vos tests ici (ping, curl, etc.)
  dependencies:
    - terraform:apply:prod
  only:
    - main
  when: on_success

# Tests Zerto API
test:zerto:api:
  stage: test
  image: curlimages/curl:latest
  environment:
    name: production
  script:
    - echo "🔍 Testing Zerto API connectivity..."
    - |
      curl -X GET "${TF_VAR_zerto_api_endpoint:-https://zerto-api.ovh.net}/v1/vpgs" \
        -H "Authorization: Bearer ${TF_VAR_zerto_api_token}" \
        -o vpgs.json
    - cat vpgs.json
  dependencies:
    - terraform:apply:prod
  only:
    - main
  when: on_success
  allow_failure: true

### STAGE: DESTROY ###

# Destruction de l'environnement de développement
terraform:destroy:dev:
  stage: destroy
  environment:
    name: development
    action: stop
  variables:
    TF_VAR_environment: "dev"
    TF_STATE_NAME: "dev"
  script:
    - terraform init
    - terraform destroy -auto-approve
  only:
    - develop
  when: manual

# Destruction de l'environnement de production (protection maximale)
terraform:destroy:prod:
  stage: destroy
  environment:
    name: production
    action: stop
  variables:
    TF_VAR_environment: "production"
    TF_STATE_NAME: "prod"
  script:
    - echo "⚠️ ATTENTION: Destruction de l'environnement de PRODUCTION"
    - echo "Cette action est IRRÉVERSIBLE"
    - sleep 10
    - terraform init
    - terraform destroy -auto-approve
  only:
    - main
  when: manual
  allow_failure: false
```

---

### Étape 4 : Configuration des Environments GitLab

#### 4.1 Créer les environnements

```
Projet GitLab → Deployments → Environments → New environment
```

Créer deux environnements :

**1. Environment "development"** :
- External URL: `https://dev.pra.example.com`
- Protection: Non protégé

**2. Environment "production"** :
- External URL: `https://prod.pra.example.com`
- Protection: **Protected** (seuls les mainteneurs peuvent déployer)

#### 4.2 Configurer les Protected Environments

```
Projet GitLab → Settings → CI/CD → Protected environments
```

1. Ajouter `production` comme environnement protégé
2. Autoriser uniquement **Maintainers** à déployer
3. Optionnel : Ajouter **Approval rules** (nécessite GitLab Premium)

---

### Étape 5 : Configuration des Branches Protégées

```
Projet GitLab → Settings → Repository → Protected branches
```

Protéger les branches principales :

**Branch `main`** :
- Allowed to merge: Maintainers
- Allowed to push: No one (force merge request)
- Code owner approval: Required (si utilisé)

**Branch `develop`** :
- Allowed to merge: Developers + Maintainers
- Allowed to push: Developers + Maintainers

---

### Étape 6 : Configuration des Merge Request Approvals (Optionnel - GitLab Premium)

```
Projet GitLab → Settings → Merge requests → Approval rules
```

Créer une règle d'approbation :
- **Nom** : "Infrastructure Review"
- **Approvals required** : 1 (ou 2 pour plus de sécurité)
- **Eligible approvers** : Membres de l'équipe infrastructure
- **Target branch** : `main`

---

### Étape 7 : Configuration des GitLab Runners

#### Option A : Utiliser les Shared Runners GitLab.com

Si vous utilisez GitLab.com, les shared runners sont déjà configurés.

Vérifier dans `Settings → CI/CD → Runners` que les shared runners sont activés.

#### Option B : Configurer un Dedicated Runner

Pour plus de contrôle ou des besoins spécifiques :

1. **Installer GitLab Runner** sur une VM ou container :

```bash
# Sur Ubuntu/Debian
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
sudo apt-get install gitlab-runner

# Enregistrer le runner
sudo gitlab-runner register
```

2. **Configuration lors de l'enregistrement** :
   - GitLab instance URL: `https://gitlab.com/`
   - Registration token: Obtenir dans `Settings → CI/CD → Runners`
   - Description: `pra-terraform-runner`
   - Tags: `terraform,azure,pra`
   - Executor: `docker`
   - Default Docker image: `hashicorp/terraform:1.6`

3. **Modifier `.gitlab-ci.yml`** pour utiliser le runner dédié :

```yaml
# Au début du fichier
default:
  tags:
    - terraform
    - azure
```

---

### Étape 8 : Configuration du GitLab Container Registry (Optionnel)

Si vous souhaitez utiliser des images Docker personnalisées :

1. **Activer le Container Registry** :
```
Settings → General → Visibility → Container Registry → Enabled
```

2. **Build et push d'une image personnalisée** :

```dockerfile
# Dockerfile
FROM hashicorp/terraform:1.6

RUN apk add --no-cache \
    bash \
    curl \
    jq \
    python3 \
    py3-pip \
    ansible

RUN pip3 install azure-cli

ENTRYPOINT ["/bin/bash"]
```

```yaml
# Ajouter un stage dans .gitlab-ci.yml
docker:build:
  stage: .pre
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - docker build -t $CI_REGISTRY_IMAGE/terraform:latest .
    - docker push $CI_REGISTRY_IMAGE/terraform:latest
  only:
    changes:
      - Dockerfile
```

---

### Étape 9 : Monitoring et Notifications

#### 9.1 Configurer les notifications Slack/Teams

Ajouter un webhook dans `.gitlab-ci.yml` :

```yaml
# À la fin de chaque job critique
after_script:
  - |
    if [ "$CI_JOB_STATUS" == "success" ]; then
      EMOJI="✅"
      COLOR="good"
    else
      EMOJI="❌"
      COLOR="danger"
    fi

    curl -X POST $SLACK_WEBHOOK_URL \
      -H 'Content-Type: application/json' \
      -d "{
        \"attachments\": [{
          \"color\": \"$COLOR\",
          \"title\": \"$EMOJI GitLab CI/CD - $CI_JOB_NAME\",
          \"text\": \"Pipeline: $CI_PIPELINE_URL\",
          \"fields\": [
            {\"title\": \"Project\", \"value\": \"$CI_PROJECT_NAME\", \"short\": true},
            {\"title\": \"Branch\", \"value\": \"$CI_COMMIT_REF_NAME\", \"short\": true},
            {\"title\": \"Status\", \"value\": \"$CI_JOB_STATUS\", \"short\": true},
            {\"title\": \"Commit\", \"value\": \"$CI_COMMIT_SHORT_SHA\", \"short\": true}
          ]
        }]
      }"
```

**Variable à ajouter** :
- `SLACK_WEBHOOK_URL` : URL du webhook Slack (variable masked)

#### 9.2 Configurer les notifications par email

```
Settings → Integrations → Emails on push
```

Activer et configurer les emails pour :
- Pipeline success/failure
- Deployment status
- Security alerts

---

### Étape 10 : Workflow de Développement

#### Workflow standard

```
1. Développeur crée une feature branch depuis develop
   git checkout -b feature/new-tunnel develop

2. Développeur fait des modifications et commit
   git commit -m "feat: add new tunnel configuration"

3. Développeur push et crée une Merge Request
   git push origin feature/new-tunnel

   → GitLab CI déclenche :
     - terraform:fmt
     - security:tfsec
     - terraform:validate

4. Review et approbation de la MR par un mainteneur

5. Merge dans develop
   → GitLab CI déclenche :
     - terraform:plan:dev
     - terraform:apply:dev (automatique)
     - test:* (tests en dev)

6. Quand prêt pour production, créer une MR develop → main

7. Review et approbation (nécessite 1-2 approbations)

8. Merge dans main
   → GitLab CI déclenche :
     - terraform:plan:prod
     - PAUSE (déploiement manuel)

9. Mainteneur déclenche manuellement terraform:apply:prod

10. Tests post-déploiement automatiques
```

---

### Étape 11 : Gestion des Rollbacks

En cas de problème après déploiement :

#### Option 1 : Rollback automatique avec Terraform

Créer un job de rollback dans `.gitlab-ci.yml` :

```yaml
terraform:rollback:prod:
  stage: deploy
  environment:
    name: production
  variables:
    TF_VAR_environment: "production"
    TF_STATE_NAME: "prod"
    ROLLBACK_COMMIT: "${CI_COMMIT_BEFORE_SHA}"
  script:
    - echo "🔄 Rolling back to commit ${ROLLBACK_COMMIT}"
    - git checkout ${ROLLBACK_COMMIT}
    - cd ${TF_ROOT}
    - terraform init
    - terraform plan -out=tfplan-rollback
    - terraform apply -auto-approve tfplan-rollback
  only:
    - main
  when: manual
```

#### Option 2 : Rollback via GitLab Environments

```
Deployments → Environments → production → Rollback
```

GitLab redéploie automatiquement le dernier déploiement réussi.

---

### Étape 12 : Sécurité et Bonnes Pratiques

#### Checklist de sécurité

- [ ] Toutes les variables sensibles sont dans GitLab Variables (masked)
- [ ] Branches `main` et `develop` sont protégées
- [ ] Environment `production` est protégé
- [ ] MR approvals sont configurées
- [ ] tfsec est intégré dans le pipeline
- [ ] Le backend Terraform est sécurisé (GitLab Managed State ou Azure Storage)
- [ ] Les déploiements en production sont manuels
- [ ] Les notifications sont configurées
- [ ] Les logs ne contiennent pas de secrets
- [ ] Le Terraform state n'est jamais committé dans Git

#### Recommandations supplémentaires

1. **Utiliser SAST (Static Application Security Testing)** :

```yaml
include:
  - template: Security/SAST.gitlab-ci.yml
```

2. **Activer Dependency Scanning** :

```yaml
include:
  - template: Security/Dependency-Scanning.gitlab-ci.yml
```

3. **Activer Secret Detection** :

```yaml
include:
  - template: Security/Secret-Detection.gitlab-ci.yml
```

4. **Audit des accès** :
```
Settings → Audit Events
```

5. **Rotation régulière des secrets** :
   - Tous les 90 jours pour les PSK IPsec
   - Tous les 180 jours pour les API keys
   - Tous les 365 jours pour les mots de passe vCenter

---

### Étape 13 : Monitoring de la Pipeline

#### Métriques à surveiller

1. **Durée des pipelines** :
   - Objectif : < 15 minutes pour un plan
   - Objectif : < 30 minutes pour un apply complet

2. **Taux de succès** :
   - Objectif : > 95% de succès sur `main`
   - Objectif : > 90% de succès sur `develop`

3. **Fréquence des déploiements** :
   - Production : 1-2 fois par semaine (recommended)
   - Développement : Plusieurs fois par jour

#### Tableau de bord GitLab

```
Analytics → CI/CD Analytics
```

Surveiller :
- Pipeline success rate
- Deployment frequency
- Lead time for changes
- Time to restore service

---

### Étape 14 : Documentation et Formation

#### Documentation à créer

1. **README.md** : Guide de démarrage rapide
2. **CONTRIBUTING.md** : Guidelines pour les contributeurs
3. **RUNBOOK.md** : Procédures opérationnelles (déploiement, rollback, incidents)
4. **ARCHITECTURE.md** : Architecture de l'infrastructure
5. **CHANGELOG.md** : Historique des changements

#### Formation de l'équipe

1. **Session de formation GitLab CI/CD** :
   - Concepts de base (stages, jobs, artifacts)
   - Workflow de développement
   - Gestion des secrets
   - Résolution de problèmes

2. **Documentation interne** :
   - Vidéos de démonstration
   - Tutoriels step-by-step
   - FAQ

3. **Exercices pratiques** :
   - Déploiement en développement
   - Création d'une MR
   - Résolution d'un conflit
   - Rollback d'un déploiement

---

### Conclusion

L'implémentation complète de la CI/CD sur GitLab pour le projet POC PRA nécessite :

1. ✅ **Configuration du backend Terraform** (GitLab Managed State ou Azure Storage)
2. ✅ **Ajout de toutes les variables sensibles** dans GitLab CI/CD Variables
3. ✅ **Création du fichier `.gitlab-ci.yml`** avec les stages appropriés
4. ✅ **Configuration des environments** (development, production)
5. ✅ **Protection des branches** (main, develop)
6. ✅ **Configuration des GitLab Runners** (shared ou dedicated)
7. ✅ **Intégration des tests de sécurité** (tfsec, SAST)
8. ✅ **Configuration des notifications** (Slack/Teams, email)
9. ✅ **Documentation du workflow** pour l'équipe
10. ✅ **Formation et onboarding** des développeurs

**Temps estimé de mise en place** : 1-2 jours pour une équipe expérimentée

**Maintenance continue** :
- Review mensuelle des secrets
- Mise à jour trimestrielle des dépendances (Terraform, providers)
- Optimisation continue des pipelines
