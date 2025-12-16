# Extension VPN Gateway Azure - OVHcloud Multi-Region BGP

## 🎯 Vue d'ensemble

**Ce package ÉTEND votre VPN Gateway Azure existant** (créé avec le package StrongSwan précédent) en ajoutant :
- ✅ **2 nouveaux tunnels IPsec** vers OVHcloud (RBX et SBG)
- ✅ **BGP dynamique** pour failover automatique RBX → SBG
- ✅ **Pas de recréation** du VPN Gateway existant
- ✅ **Coexistence** avec le tunnel StrongSwan existant
- ✅ **FortiGate** sur OVHcloud Hosted Private Cloud

## ⚠️ Prérequis Critiques

### 1. Infrastructure Azure existante

Vous devez avoir **déjà déployé** le package précédent avec :
- ✅ VPN Gateway Azure créé
- ✅ VNet Azure configuré
- ✅ Tunnel StrongSwan fonctionnel (optionnel, peut coexister)

### 2. BGP activé sur le VPN Gateway

**CRITIQUE** : Votre VPN Gateway doit avoir BGP activé. Vérifiez avec :

```bash
az network vnet-gateway show \
  --name <VOTRE_VPN_GATEWAY> \
  --resource-group <VOTRE_RG> \
  --query "bgpSettings"
```

Si `bgpSettings` est vide ou `null`, vous devez :

**Option A - Activer BGP (si gateway supporte):**
```bash
# ⚠️ Peut nécessiter une recréation du gateway
az network vnet-gateway update \
  --name <VOTRE_VPN_GATEWAY> \
  --resource-group <VOTRE_RG> \
  --set "bgpSettings.asn=65515"
```

**Option B - Recréer le gateway avec BGP:**
Si l'option A ne fonctionne pas, il faut utiliser le premier package (ovh-azure-vpn) qui crée un nouveau VPN Gateway avec BGP dès le départ.

### 3. Infrastructure OVHcloud

Vous devez avoir **déjà déployé** :
- ✅ FortiGate VM sur OVHcloud RBX (Hosted Private Cloud VMware)
- ✅ FortiGate VM sur OVHcloud SBG (Hosted Private Cloud VMware)
- ✅ IPs publiques configurées avec routage internet
- ✅ Accès HTTPS aux FortiGates

## 📁 Structure du projet

```
ovh-azure-vpn-extend/
├── terraform/
│   ├── main.tf                      # EXTENSION du VPN Gateway existant
│   ├── variables.tf                 # Variables (infra existante + OVH)
│   ├── outputs.tf                   # Vérifications et commandes
│   ├── terraform.tfvars.example     # Configuration exemple
│   ├── templates/                   # Templates Ansible
│   └── ansible/
│       ├── playbook-fortigate.yml   # Configuration FortiGates
│       └── roles/fortigate-ipsec-bgp/
├── scripts/
│   ├── simulate-rbx-failure.sh      # Test failover RBX → SBG
│   └── restore-rbx.sh               # Restauration RBX
└── README.md                        # Ce fichier
```

## 🚀 Déploiement

### Étape 1 : Récupérer les informations de l'infrastructure existante

```bash
# Lister vos VPN Gateways
az network vnet-gateway list --output table

# Récupérer les détails
az network vnet-gateway show \
  --name <VOTRE_VPN_GATEWAY> \
  --resource-group <VOTRE_RG>

# Vérifier BGP
az network vnet-gateway show \
  --name <VOTRE_VPN_GATEWAY> \
  --resource-group <VOTRE_RG> \
  --query "bgpSettings"
```

### Étape 2 : Configuration

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

**Configuration obligatoire :**

```hcl
# === Infrastructure Azure Existante ===
existing_resource_group_name = "rg-dev-onprem"       # VOTRE RG
existing_vpn_gateway_name    = "vpngw-dev-azure"     # VOTRE VPN Gateway
existing_vnet_name           = "vnet-dev-azure"      # VOTRE VNet
existing_vnet_cidr           = "10.1.0.0/16"         # VOTRE CIDR

# === BGP Azure (vérifier l'ASN existant) ===
azure_bgp_asn = 65515  # Vérifier avec: az network vnet-gateway show ...

# === Nouvelles adresses APIPA pour OVH ===
# ⚠️ DIFFÉRENTES de celles utilisées pour StrongSwan
azure_bgp_apipa_primary   = "169.254.30.1"
azure_bgp_apipa_secondary = "169.254.31.1"

# === OVHcloud RBX ===
ovh_rbx_public_ip    = "X.X.X.X"                # IP publique FortiGate
rbx_bgp_peer_ip      = "169.254.30.2"           # Peer dans même subnet
ipsec_psk_rbx        = "PSK_FORT_RBX"           # openssl rand -base64 32

# === OVHcloud SBG ===
ovh_sbg_public_ip    = "Y.Y.Y.Y"                # IP publique FortiGate
sbg_bgp_peer_ip      = "169.254.31.2"           # Peer dans même subnet
ipsec_psk_sbg        = "PSK_FORT_SBG"           # openssl rand -base64 32

# === FortiGate Access ===
fortigate_rbx_mgmt_ip    = "Z.Z.Z.Z"
fortigate_sbg_mgmt_ip    = "W.W.W.W"
fortigate_admin_password = "PASSWORD"
```

### Étape 3 : Déploiement Terraform

```bash
terraform init
terraform plan
terraform apply
```

**Terraform va :**
- ✅ Utiliser le VPN Gateway existant (data source)
- ✅ Créer 2 Local Network Gateways (RBX, SBG)
- ✅ Créer 2 VPN Connections avec BGP
- ✅ Ajouter des routes vers OVH (si route table spécifiée)
- ✅ Générer l'inventaire Ansible

**Durée :** 5-10 minutes (pas de création de VPN Gateway)

### Étape 4 : Vérification

```bash
# Vérifier que BGP est bien activé
terraform output bgp_status_check

# Vérifier les nouvelles connexions
terraform output vpn_connections_status_commands

# Attendre 5-10 minutes que les tunnels s'établissent
```

### Étape 5 : Configuration FortiGates

```bash
cd ansible
ansible-playbook -i inventory.ini playbook-fortigate.yml
```

**Ansible configure :**
- IPsec Phase 1 et 2 vers Azure
- BGP avec Azure (ASN, peers, route-maps)
- Priorités : RBX LOCAL_PREF 200, SBG LOCAL_PREF 100
- AS-PATH prepend x3 sur SBG
- Firewall policies

### Étape 6 : Tests

```bash
# Vérifier les routes BGP apprises
az network vnet-gateway list-learned-routes \
  --name <VOTRE_VPN_GATEWAY> \
  --resource-group <VOTRE_RG> \
  --output table

# Tester connectivité
ping 192.168.10.10  # Vers RBX
ping 192.168.20.10  # Vers SBG

# Simuler panne RBX
cd ../scripts
./simulate-rbx-failure.sh

# Restaurer RBX
./restore-rbx.sh
```

## 🏗️ Architecture après déploiement

```
┌────────────────────────────────────────────────┐
│         Azure VPN Gateway (Existant)           │
│         ASN 65515                              │
│         IP: X.X.X.X                            │
│         BGP Enabled: true                      │
└─────┬──────────────┬───────────────┬───────────┘
      │              │               │
      │ StrongSwan   │ OVH RBX       │ OVH SBG
      │ (Existant)   │ (NOUVEAU)     │ (NOUVEAU)
      │              │ PRIMARY       │ BACKUP
      │              │ PREF 200      │ PREF 100
      ▼              ▼               ▼
┌─────────────┐ ┌──────────────┐ ┌──────────────┐
│ StrongSwan  │ │ FortiGate    │ │ FortiGate    │
│ VM          │ │ RBX          │ │ SBG          │
│ 192.168.x.x │ │ 192.168.10.x │ │ 192.168.20.x │
└─────────────┘ └──────────────┘ └──────────────┘
```

### Tunnels IPsec actifs

| Tunnel | Destination | Protocole | Priorité | Status |
|--------|-------------|-----------|----------|--------|
| 1 | StrongSwan | IPsec (peut avoir BGP) | Existant | Actif |
| 2 | OVH RBX | IPsec + BGP | PRIMARY (200) | Actif |
| 3 | OVH SBG | IPsec + BGP | BACKUP (100) | Actif |

## 📊 Configuration BGP

### Mécanisme de Failover

1. **RBX actif** (normal)
   - LOCAL_PREF: 200 → Route préférée
   - AS-PATH: Normal (65001)
   - Azure route tout le trafic vers RBX

2. **RBX tombe** (panne)
   - Détection: ~30s (DPD + BGP Hold Time)
   - Azure retire les routes RBX
   - Azure utilise automatiquement SBG (seule route disponible)
   - Convergence: ~60-90s total

3. **RBX revient** (restauration)
   - BGP re-établit le peering
   - LOCAL_PREF 200 > LOCAL_PREF 100
   - Azure rebascule automatiquement vers RBX
   - Convergence: ~90s

### Isolation des tunnels

Les adresses APIPA BGP sont séparées par tunnel :

| Tunnel | Azure BGP | Peer BGP | Subnet APIPA |
|--------|-----------|----------|--------------|
| StrongSwan | 169.254.21.1 | 169.254.21.2 | 169.254.21.0/30 |
| OVH RBX | 169.254.30.1 | 169.254.30.2 | 169.254.30.0/30 |
| OVH SBG | 169.254.31.1 | 169.254.31.2 | 169.254.31.0/30 |

Pas de conflit, chaque tunnel a son propre peering BGP.

## 🧪 Tests de Failover

### Simulation de panne RBX

```bash
./scripts/simulate-rbx-failure.sh
```

**Résultat attendu :**
```
RBX (Primary):  NotConnected (simulé en panne)
SBG (Backup):   Connected (actif)

Routes BGP:
Network             Origin    AS-Path           LocalPref
192.168.20.0/24     EBgp      65002-65002-65002 100
```

### Restauration

```bash
./scripts/restore-rbx.sh
```

**Résultat attendu :**
```
RBX (Primary):  Connected (restauré)
SBG (Backup):   Connected (actif en backup)

Routes BGP:
Network             Origin    AS-Path    LocalPref
192.168.10.0/24     EBgp      65001      200    ← Route préférée
192.168.20.0/24     EBgp      65002      100
```

## 💰 Coûts

**Coûts additionnels** (par rapport au package précédent) :

| Ressource | Coût/mois |
|-----------|-----------|
| VPN Gateway | €0 (réutilisé) |
| 2x VPN Connections | €0 (inclus) |
| **Total additionnel** | **€0** |

Les seuls coûts sont côté OVHcloud (FortiGates, Hosted Private Cloud).

## ⚠️ Points d'attention

### 1. BGP doit être activé
Le VPN Gateway **doit** avoir BGP activé. Sinon, les tunnels IPsec fonctionneront mais sans routage dynamique ni failover automatique.

### 2. Adresses APIPA séparées
Les nouvelles adresses APIPA (169.254.30.x, 169.254.31.x) sont différentes de celles du tunnel StrongSwan (169.254.21.x, 169.254.22.x) pour éviter les conflits.

### 3. Coexistence des tunnels
Les 3 tunnels (StrongSwan + RBX + SBG) fonctionnent en parallèle. BGP gère automatiquement les priorités de routage.

### 4. Limites du VPN Gateway
- VpnGw1: 30 tunnels max
- VpnGw2: 30 tunnels max
- Vous utilisez actuellement 3 tunnels

## 🔄 Migration vers HA Active-Active

Si votre VPN Gateway est déjà VpnGw2 ou supérieur et en mode Active-Active, ce package le détectera automatiquement et créera les configurations appropriées.

## 🛠️ Troubleshooting

### BGP non activé

**Symptôme :** `terraform output bgp_status_check` retourne une erreur

**Solution :**
```bash
# Essayer d'activer BGP
az network vnet-gateway update \
  --name <VPN_GATEWAY> \
  --resource-group <RG> \
  --set "bgpSettings.asn=65515"

# Si erreur, il faut recréer le gateway avec le package complet
```

### Tunnels ne s'établissent pas

**Vérifications :**
1. PSK identiques des deux côtés
2. IPs publiques correctes
3. Ports UDP 500, 4500, ESP ouverts
4. Configuration FortiGate appliquée

### BGP peering ne s'établit pas

**Vérifications :**
1. Tunnels IPsec UP
2. Adresses APIPA correctes
3. ASN configurés
4. `get router info bgp neighbors` sur FortiGate

## 📚 Documentation

La documentation technique complète (DOCUMENTATION.md) du package principal s'applique aussi à cette extension.

## 🆘 Support

1. Vérifier les outputs Terraform
2. Consulter les logs Azure et FortiGate
3. Utiliser les scripts de diagnostic

---

**Version:** 1.0 - Extension  
**Utilise:** Infrastructure Azure existante  
**Ajoute:** 2 tunnels OVH avec BGP failover  
**Compatible avec:** Package StrongSwan précédent
