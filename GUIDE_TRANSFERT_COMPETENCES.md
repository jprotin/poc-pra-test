# Guide de Transfert de Compétences - POC PRA

**Destinataire :** Responsable Technique
**Date :** 2025-12-29
**Version :** 1.0

---

## 📋 Vue d'Ensemble du Projet

### Objectif
Infrastructure hybride de Plan de Reprise d'Activité (PRA) entre **Azure** et **OVHCloud** avec :
- Tunnels VPN IPsec sécurisés
- Routage dynamique BGP pour failover automatique
- Réplication bi-directionnelle des VMs avec Zerto

### Périmètre Fonctionnel

**✅ Ce que fait le projet :**
- Déploie un VPN Gateway Azure avec support BGP
- Configure des tunnels IPsec vers 3 destinations (StrongSwan, FortiGate RBX, FortiGate SBG)
- Permet le failover automatique RBX ↔ SBG via BGP (RTO < 2 minutes)
- Réplique les VMs entre RBX et SBG avec Zerto (RPO 5 minutes)
- Automatise le déploiement via Terraform + Ansible

**❌ Ce que le projet NE fait PAS :**
- Pas de monitoring applicatif (uniquement infrastructure)
- Pas de backup automatique (sauf module Zerto emergency backup)
- Pas de gestion des secrets avec Key Vault (fichiers .env)
- Pas de haute disponibilité du VPN Gateway (mode Active-Passive uniquement)

---

## 🏗️ Architecture Technique

### Infrastructure Azure
```
Hub Azure (francecentral)
├── VPN Gateway (VpnGw1, BGP ASN 65515)
├── VNet 10.1.0.0/16
└── 3 Tunnels IPsec
    ├── Tunnel 1: StrongSwan (statique, test)
    ├── Tunnel 2: FortiGate RBX (BGP Primary, LOCAL_PREF 200)
    └── Tunnel 3: FortiGate SBG (BGP Backup, LOCAL_PREF 100)
```

**Mécanisme de Failover BGP :**
- **Normal :** Trafic → Fortigate RBX (Primary) → Azure
- **Si RBX tombe :** BGP retire les routes RBX, trafic bascule automatiquement sur SBG
- **Durée de convergence :** 60-90 secondes

### Infrastructure OVHCloud (VMware vSphere)
```
Site RBX (Roubaix)                    Site SBG (Strasbourg)
├── Application A (Production)        ├── Application B (Production)
├── Réplica B (DR)                    ├── Réplica A (DR)
├── FortiGate (Primary BGP)           └── FortiGate (Backup BGP)
└── vRack interconnexion ────────────────► vRack
```

**Zerto Réplication :**
- VPG-RBX-to-SBG : Protège Application A (RPO 5 min)
- VPG-SBG-to-RBX : Protège Application B (RPO 5 min)
- Mode : Active/Active bi-directionnel

---

## 📦 Fonctionnalités Détaillées

### 1. Déploiement Infrastructure Azure (Terraform)

**Fichiers :** `terraform/main.tf`, modules `01-azure-vpn-gateway/`

**Fonctionnalité :**
- Crée le Resource Group, VNet, Subnets
- Déploie le VPN Gateway Azure (durée : ~45 minutes)
- Configure le BGP avec ASN 65515
- Génère les IPs publiques pour les tunnels

**Commande :**
```bash
cd terraform
terraform init
terraform apply
```

**Documentation :** `Documentation/02-TECHNIQUE.md` (lignes 69-98)

---

### 2. Déploiement VM StrongSwan (Tunnel Statique)

**Fichiers :** Module `02-strongswan-vm/`, Playbook `ansible/playbooks/01-configure-strongswan.yml`

**Fonctionnalité :**
- Déploie une VM Ubuntu 22.04 (B1s, 1 vCPU, 1 GB RAM)
- Installe StrongSwan pour tunnel IPsec statique
- Simule un site on-premises
- Tunnel IKEv2 avec PSK, AES-256, SHA-256

**Commande :**
```bash
./deploy.sh --strongswan
```

**Configuration IPsec :** `/etc/ipsec.conf` sur la VM
- Left: VM StrongSwan (192.168.0.0/16)
- Right: Azure VPN Gateway (10.1.0.0/16)
- DPD : 30s, auto-restart

**Documentation :** `Documentation/02-TECHNIQUE.md` (lignes 186-224)

---

### 3. Tunnels BGP vers OVHCloud (RBX + SBG)

**Fichiers :** Modules `04-tunnel-ipsec-bgp-rbx/`, `05-tunnel-ipsec-bgp-sbg/`

**Fonctionnalité :**
- Configure les tunnels IPsec/BGP vers les FortiGates
- **RBX (Primary) :** LOCAL_PREF 200, ASN 65001
- **SBG (Backup) :** LOCAL_PREF 100, ASN 65002, AS-PATH prepending
- Adresses APIPA pour peering BGP (169.254.30.x, 169.254.31.x)

**Mécanisme de Failover :**
1. DPD détecte la panne RBX (~30s)
2. BGP retire les routes RBX (~90s Hold Time)
3. Route SBG devient best path
4. Convergence totale : 60-90 secondes

**Commande :**
```bash
./deploy.sh --ovh
```

**Documentation :** `Documentation/02-TECHNIQUE.md` (lignes 266-389)

---

### 4. Zerto Disaster Recovery (Réplication VMs)

**Fichiers :** `zerto/terraform/`, `zerto/scripts/`

**Fonctionnalité :**
- Réplication continue des VMs VMware entre RBX et SBG
- RPO : 5 minutes (configurable)
- RTO : 15 minutes (failover automatisé)
- Journal 24h pour point-in-time recovery

**Composants :**
- **VPG (Virtual Protection Group) :** Groupe de VMs protégées ensemble
- **VRA (Virtual Replication Appliance) :** Appliance de réplication (1 par ESXi)
- **Journal Zerto :** Historique des modifications (24h)

**Scripts de Failover :**
```bash
# Failover RBX → SBG
./zerto/scripts/failover-rbx-to-sbg.sh

# Failover SBG → RBX
./zerto/scripts/failover-sbg-to-rbx.sh

# Failback (retour à la normale)
./zerto/scripts/failback.sh --from sbg --to rbx
```

**Documentation :**
- Technique : `Documentation/zerto/01-implementation-technique.md`
- Opérationnel : `Documentation/zerto/02-guide-fonctionnel.md`

---

### 5. Monitoring et Vérification

**Fichiers :** `scripts/test/check-vpn-status.sh`, `zerto/scripts/check-vpg-status.sh`

**Fonctionnalité :**
- Vérification statut des tunnels VPN Azure
- Vérification état des VPGs Zerto (MeetingSLA / NotMeetingSLA)
- Dashboard Grafana pour métriques temps réel

**Commandes :**
```bash
# Vérifier tunnels VPN
./scripts/test/check-vpn-status.sh

# Vérifier VPGs Zerto
./zerto/scripts/check-vpg-status.sh --all --verbose

# Vérifier routes BGP
az network vnet-gateway list-learned-routes \
  --name vpngw-dev-pra \
  --resource-group rg-dev-pra-vpn
```

**Métriques surveillées :**
- VPN Connection Status (Connected / NotConnected)
- RPO Zerto (< 300 secondes)
- BGP Peering (Established)
- Utilisation Journal Zerto (< 85%)

**Documentation :** `Documentation/02-TECHNIQUE.md` (lignes 536-578)

---

### 6. Scripts de Déploiement

**Fichier :** `deploy.sh`

**Fonctionnalité :**
- Script orchestrateur principal
- Options de déploiement modulaire

**Commandes disponibles :**
```bash
# Déploiement complet (tout)
./deploy.sh --all

# VPN Gateway uniquement
./deploy.sh --vpn

# VPN + StrongSwan
./deploy.sh --strongswan

# VPN + Tunnels OVH
./deploy.sh --ovh

# Terraform seul (sans Ansible)
./deploy.sh --all --terraform-only
```

**Documentation :** `Documentation/03-DEPLOIEMENT.md`

---

### 7. Sécurité

**Fichiers :** `.env.dist`, `.env-protected.dist`, `VARIABLES_ENVIRONNEMENT.md`

**Fonctionnalité :**
- Chiffrement IPsec : AES-256-CBC + SHA-256
- Authentification : Pre-Shared Key (PSK) 32+ caractères
- NSG (Network Security Groups) pour restreindre SSH
- Ports autorisés : UDP 500, 4500, ESP (protocol 50)

**Recommandations :**
- Stocker les PSK dans Azure Key Vault (production)
- Rotation des PSK tous les 90 jours
- Restreindre SSH aux IPs de confiance
- Ne JAMAIS committer terraform.tfvars (contient secrets)

**Documentation :** `Documentation/04-SECURITE.md`

---

## 🚨 RETOUR À LA NORMALE APRÈS INCIDENT

### Scénario : Site RBX Indisponible

**Phase 1 : Incident Détecté (T+0 à T+15 min)**

1. **Détection automatique :**
   - Script monitoring détecte VPG-RBX-to-SBG en état "NotMeetingSLA"
   - Tunnel IPsec RBX → Azure tombe (DPD timeout 30s)
   - BGP retire les routes RBX de la table de routage Azure

2. **Impact immédiat :**
   - ✅ Application A (RBX) : Réplica disponible sur SBG
   - ⚠️ Application B (SBG) : Fonctionne MAIS non protégée (plus de réplication vers RBX)

**Phase 2 : Failover Application A (T+15 à T+30 min)**

3. **Lancer le failover :**
```bash
cd /home/user/poc-pra-test/zerto
./scripts/failover-rbx-to-sbg.sh --force --vpg VPG-RBX-to-SBG
```

4. **Actions automatiques du script :**
   - Démarre les VMs Application A sur SBG
   - Ajoute routes statiques sur Fortigate SBG pour IPs 10.1.x.x (VMs failovées)
   - Azure VPN Gateway bascule sur tunnel SBG (BGP backup)
   - Durée totale : 10-15 minutes

5. **Résultat :**
   - ✅ Application A disponible sur SBG (perte max 5 min de données)
   - ⚠️ Application B toujours non protégée

**Phase 3 : Protection Compensatoire Application B (T+30 à T+90 min)**

6. **Activation backup d'urgence (automatique si configuré) :**
```bash
ansible-playbook ansible/playbooks/activate-emergency-backup.yml \
  -e "app_name=Application-B" \
  -e "site=SBG"
```

7. **Actions :**
   - Création job Veeam Backup Local (toutes les 12h, rétention 7j)
   - Création job Veeam S3 Immuable (copie vers OVHcloud GRA, rétention 30j)
   - Lancement backup complet immédiat

8. **Résultat :**
   - ✅ Application A : Opérationnelle sur SBG
   - ✅ Application B : Protégée par backup (RPO 12h max)

### Retour du Site RBX (Retour à la Normale)

**Phase 4 : Site RBX Rétabli**

9. **Timeline de récupération :**
   - T+0 : Site RBX rétabli (infrastructure OK)
   - T+10m : VRAs Zerto RBX redémarrent
   - T+15m : Connectivité réseau RBX ↔ SBG validée
   - T+20m : Zerto détecte le retour de RBX
   - T+25m : VPG-SBG-to-RBX passe en "Syncing"
   - T+30m : **Début resynchronisation Delta Sync**

10. **Mécanisme Delta Sync (Zerto) :**

Zerto utilise le **Bitmap** accumulé pendant l'indisponibilité :
- Zerto a tracé tous les blocs modifiés sur App B pendant l'incident
- Il transfère UNIQUEMENT les différences (pas toute la VM)
- Avec compression WAN (ratio ~2:1)

**Exemple concret :**
```
VM Application B : 500 GB
Durée incident RBX : 7 jours
Taux modification : 5% par jour
Volume à transférer : 500 GB × 5% × 7 = 175 GB
Avec compression 2:1 : 87,5 GB net
Bande passante : 1 Gbps → Durée : ~15 minutes
```

11. **Formule de calcul :**
```
Durée Sync = (Taille VM × Taux Modif × Durée Incident) / (Bande Passante × Compression)
```

**Exemples :**
| Taille VM | Durée Incident | Taux Modif | Temps Sync (1Gbps) |
|-----------|----------------|------------|--------------------|
| 200 GB    | 1 jour         | 2%         | ~1 minute          |
| 500 GB    | 3 jours        | 5%         | ~10 minutes        |
| 1 TB      | 7 jours        | 10%        | ~90 minutes        |
| 2 TB      | 14 jours       | 15%        | ~8 heures          |

12. **Fin de resynchronisation :**
   - VPG-SBG-to-RBX repasse en "MeetingSLA"
   - RPO revient à < 5 minutes
   - Réplication continue reprend normalement

**Phase 5 : État Machines Après Retour RBX**

**IMPORTANT - Les VMs NE BASCULENT PAS AUTOMATIQUEMENT**

13. **État final après resynchronisation :**

```
Site RBX (Rétabli)              Site SBG (Actif)
├── Réplica A (DR, à jour)      ├── Application A (PRODUCTION) ← Basculée ici
├── Réplica B (DR, à jour)      └── Application B (PRODUCTION) ← Était déjà ici
└── Infrastructure OK
```

**Les VMs restent où elles sont tournées actuellement :**
- ✅ Application A : Reste sur SBG (a été basculée, fonctionne)
- ✅ Application B : Reste sur SBG (n'a jamais bougé)
- ✅ Réplication Zerto : Reprise dans les deux sens

14. **Décision de Failback (optionnelle) :**

**Si vous voulez ramener Application A sur RBX :**
```bash
cd /home/user/poc-pra-test/zerto
./scripts/failback.sh --from sbg --to rbx
```

**Durée failback :** 30-60 minutes (resynchronisation + redémarrage VMs)

**Si vous NE faites PAS de failback :**
- Application A continue sur SBG (stable, testé)
- Application B continue sur SBG
- Les deux sont protégées par réplication Zerto
- **Pas d'impact utilisateur**

15. **Désactivation backups d'urgence (optionnel) :**

**Option A (Recommandé) : Conserver les backups**
- Coût : ~50-100€/mois
- Avantage : Double protection (Zerto + Backup)

**Option B : Désactiver**
```bash
ansible-playbook deactivate-emergency-backup.yml \
  -e "app_name=Application-B" \
  -e "confirm=yes"
```

### Points Clés à Retenir

**✅ Comportement Zerto lors du retour RBX :**
1. **Détection automatique :** Zerto détecte le retour de RBX seul
2. **Resynchronisation Delta :** Transfère uniquement les changements (Bitmap)
3. **Durée variable :** Dépend du volume modifié pendant l'incident
4. **Pas de bascule auto :** Les VMs ne reviennent PAS automatiquement sur RBX
5. **Décision manuelle :** C'est vous qui décidez si/quand faire le failback

**⚠️ VMs ne tournent PAS sur la région de secours avant bascule :**
- Les VMs sont en mode **Réplica** (éteintes, données synchronisées)
- Au moment du failover, Zerto les **démarre** sur le site de secours
- Il n'y a PAS de "warm standby" (VMs allumées en attente)

**📊 Coûts :**
- VPN Gateway VpnGw1 : ~90-100€/mois
- VM StrongSwan B1s : ~8€/mois
- IPs publiques (3x) : ~9€/mois
- **Total infrastructure Azure : ~110-120€/mois**
- Zerto + OVHcloud : Selon contrat OVH

---

## 📚 Documentation Disponible

| Document | Chemin | Contenu |
|----------|--------|---------|
| **README principal** | `README.md` | Vue d'ensemble, démarrage rapide |
| **Fonctionnel** | `Documentation/01-FONCTIONNEL.md` | Objectifs, cas d'usage, bénéfices |
| **Technique** | `Documentation/02-TECHNIQUE.md` | Architecture détaillée, config IPsec/BGP |
| **Déploiement** | `Documentation/03-DEPLOIEMENT.md` | Guide pas à pas, troubleshooting |
| **Sécurité** | `Documentation/04-SECURITE.md` | Audit sécurité, recommandations |
| **Zerto Technique** | `Documentation/zerto/01-implementation-technique.md` | Implémentation Zerto (40+ pages) |
| **Zerto Opérationnel** | `Documentation/zerto/02-guide-fonctionnel.md` | Procédures failover/failback (40+ pages) |
| **Analyse Active/Active** | `Documentation/zerto/03-analyse-perte-site-active-active.md` | Comportement perte de site (50+ pages) |
| **Variables Env** | `VARIABLES_ENVIRONNEMENT.md` | Liste complète des variables |

---

## 🛠️ Commandes Essentielles

```bash
# Déploiement complet
./deploy.sh --all

# Vérifier statut VPN
./scripts/test/check-vpn-status.sh

# Vérifier statut Zerto
./zerto/scripts/check-vpg-status.sh --all --verbose

# Failover RBX → SBG
./zerto/scripts/failover-rbx-to-sbg.sh

# Failback SBG → RBX
./zerto/scripts/failback.sh --from sbg --to rbx

# Détruire infrastructure
cd terraform && terraform destroy
```

---

## ⚡ Prochaines Étapes Recommandées

1. **Lire les 3 documentations principales :**
   - `Documentation/02-TECHNIQUE.md` (architecture réseau détaillée)
   - `Documentation/zerto/02-guide-fonctionnel.md` (procédures opérationnelles)
   - `Documentation/zerto/03-analyse-perte-site-active-active.md` (comprendre Delta Sync)

2. **Tester en environnement de dev :**
   - Déployer avec `./deploy.sh --strongswan`
   - Simuler une panne : `./scripts/test/simulate-rbx-failure.sh`
   - Observer le failover BGP automatique

3. **Configurer le monitoring :**
   - Ajouter cron pour `check-vpg-status.sh --all --auto-remediate`
   - Configurer alertes email/Slack dans `terraform.tfvars`

4. **Planifier les tests mensuels :**
   - Test failover Zerto (environnement isolé)
   - Validation RTO/RPO réels
   - Documentation des résultats

---

**Document créé le :** 2025-12-29
**Auteur :** Claude Code
**Contact support :** Consulter `Documentation/` pour détails techniques
