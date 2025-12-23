# POC PRA - Infrastructure Hybride Azure + OVHCloud

## 📋 Vue d'ensemble

Ce projet déploie une infrastructure hybride complète avec VPN IPsec/BGP entre Azure et OVHCloud, incluant :

- **Hub Azure** : VPN Gateway avec support BGP
- **VM StrongSwan** : Simulation d'un site on-premises avec tunnel IPsec statique
- **Tunnels OVHCloud** : Connexions IPsec/BGP vers RBX (Primary) et SBG (Backup)
- **Failover automatique** : Basculement RBX ↔ SBG via BGP
- **Zerto Disaster Recovery** : Solution PRA/PRI bi-directionnelle RBX ⟷ SBG avec RPO 5 minutes
- **Infrastructure as Code** : Terraform, Ansible, Shell scripts

## 🏗️ Architecture

```
┌─────────────── HUB AZURE ────────────────┐
│                                          │
│     VPN Gateway (BGP enabled)            │
│     IP: [Azure Public IP]                │
│     ASN: 65515                           │
│                                          │
└──────┬────────────┬────────────┬─────────┘
       │            │            │
       │ Tunnel 1   │ Tunnel 2   │ Tunnel 3
       │ (Statique) │ (BGP RBX)  │ (BGP SBG)
       │            │            │
       ▼            ▼            ▼
┌────────────┐ ┌──────────┐ ┌──────────┐
│ StrongSwan │ │ FortiGate│ │ FortiGate│
│ VM         │ │ RBX      │ │ SBG      │
│ 192.168.x  │ │ PRIMARY  │ │ BACKUP   │
└────────────┘ └──────────┘ └──────────┘
                    │             │
                    ▼             ▼
              ┌─────────┐   ┌─────────┐
              │ vRack   │   │ vRack   │
              │ OVH RBX │   │ OVH SBG │
              └─────────┘   └─────────┘
```

## 🚀 Démarrage Rapide

### Prérequis

```bash
# Outils requis
terraform --version   # >= 1.5.0
ansible --version     # >= 2.14
az login             # Azure CLI authentifié
```

### Installation en 3 étapes

```bash
# 1. Cloner et configurer
git clone <repository-url>
cd poc-pra-test
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
nano terraform/terraform.tfvars

# 2. Déployer (option au choix)
./deploy.sh --all           # Déploiement complet
./deploy.sh --strongswan    # VPN + StrongSwan uniquement
./deploy.sh --vpn           # VPN Gateway uniquement

# 3. Vérifier
./scripts/test/check-vpn-status.sh
```

## 📁 Structure du Projet

```
poc-pra-test/
├── README.md                          # ⭐ Ce fichier
├── deploy.sh                          # 🚀 Script de déploiement global
│
├── Documentation/                     # 📚 Toute la documentation
│   ├── 01-FONCTIONNEL.md             # Vue fonctionnelle du POC
│   ├── 02-TECHNIQUE.md               # Détails techniques
│   ├── 03-DEPLOIEMENT.md             # Guide de déploiement complet
│   └── 04-SECURITE.md                # Audit de sécurité
│
├── terraform/                         # 🏗️ Infrastructure as Code
│   ├── main.tf                        # Configuration principale
│   ├── variables.tf                   # Variables globales
│   ├── outputs.tf                     # Sorties Terraform
│   └── terraform.tfvars.example       # Exemple de configuration
│
├── modules/                           # 📦 Modules Terraform par brique
│   ├── 01-azure-vpn-gateway/         # VPN Gateway Azure
│   ├── 02-strongswan-vm/             # VM StrongSwan
│   ├── 03-tunnel-ipsec-static/       # Tunnel statique
│   ├── 04-tunnel-ipsec-bgp-rbx/      # Tunnel BGP RBX
│   ├── 05-tunnel-ipsec-bgp-sbg/      # Tunnel BGP SBG
│   └── 06-ovh-vmware-infrastructure/  # Infrastructure OVH (optionnel)
│
├── ansible/                           # ⚙️ Provisioning et configuration
│   ├── playbooks/                     # Playbooks par brique
│   ├── roles/                         # Rôles Ansible réutilisables
│   ├── inventories/                   # Inventaires par environnement
│   └── group_vars/                    # Variables par groupe
│
├── scripts/                           # 📜 Scripts utilitaires
│   ├── deploy/                        # Scripts de déploiement
│   ├── destroy/                       # Scripts de destruction
│   ├── test/                          # Scripts de test
│   └── utils/                         # Utilitaires divers
│
└── zerto/                             # 🔄 Solution Zerto PRA/PRI
    ├── terraform/                     # Infrastructure Zerto
    ├── ansible/                       # Configuration Zerto
    ├── scripts/                       # Failover/Failback scripts
    ├── config/                        # Configuration
    └── README.md                      # Documentation Zerto
```

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [01-FONCTIONNEL.md](Documentation/01-FONCTIONNEL.md) | 🎯 Vue d'ensemble fonctionnelle du POC |
| [02-TECHNIQUE.md](Documentation/02-TECHNIQUE.md) | 🔧 Architecture technique détaillée |
| [03-DEPLOIEMENT.md](Documentation/03-DEPLOIEMENT.md) | 📖 Guide de déploiement pas à pas |
| [04-SECURITE.md](Documentation/04-SECURITE.md) | 🔒 Audit de sécurité et recommandations |
| **Zerto PRA/PRI** | |
| [zerto/README.md](zerto/README.md) | 🔄 Solution Zerto - Vue d'ensemble |
| [zerto/01-implementation-technique.md](Documentation/zerto/01-implementation-technique.md) | 🛠️ Zerto - Implémentation technique |
| [zerto/02-guide-fonctionnel.md](Documentation/zerto/02-guide-fonctionnel.md) | 📋 Zerto - Guide fonctionnel et opérations |

## 🎯 Cas d'usage

### 1. Déploiement complet (VPN + StrongSwan + OVH)

```bash
./deploy.sh --all
```

**Composants déployés :**
- VPN Gateway Azure avec BGP
- VM StrongSwan + tunnel statique
- 2 tunnels BGP vers OVH (RBX + SBG)
- Configuration automatique via Ansible

**Durée :** ~45-50 minutes (création VPN Gateway)

### 2. Test du failover RBX → SBG

```bash
# Simuler une panne RBX
./scripts/test/simulate-rbx-failure.sh

# Vérifier que le trafic bascule sur SBG
./scripts/test/check-vpn-status.sh

# Restaurer RBX
./scripts/test/restore-rbx.sh
```

### 3. Déploiement StrongSwan uniquement

```bash
./deploy.sh --strongswan
```

Idéal pour tester le tunnel IPsec statique sans les complexités de BGP.

### 4. Déploiement par étapes

```bash
# Étape 1 : Terraform uniquement
./deploy.sh --all --terraform-only

# Étape 2 : Ansible uniquement (après vérifications)
./deploy.sh --all --ansible-only
```

## 🔧 Configuration

### Configuration minimale (terraform.tfvars)

```hcl
environment  = "dev"
project_name = "pra"

# Azure
azure_location = "francecentral"
vpn_gateway_sku = "VpnGw1"
enable_bgp = true

# StrongSwan
deploy_strongswan = true
ipsec_psk_strongswan = "VOTRE_PSK_32_CARACTERES_MINIMUM"

# OVH (optionnel)
deploy_ovh_rbx = false
deploy_ovh_sbg = false
```

### Générer un PSK sécurisé

```bash
openssl rand -base64 32
```

## 🧪 Tests et Validation

### Vérifier le statut des tunnels

```bash
./scripts/test/check-vpn-status.sh
```

**Sortie attendue :**
```
Tunnel StrongSwan : Connected ✅
Tunnel RBX        : Connected ✅ (PRIMARY)
Tunnel SBG        : Connected ✅ (BACKUP)
```

### Tester la connectivité

```bash
./scripts/test/test-connectivity.sh
```

### Vérifier les routes BGP

```bash
cd terraform
terraform output check_bgp_routes_command | sh
```

## 💰 Coûts Estimés (France Central)

| Ressource | SKU | Coût/mois |
|-----------|-----|-----------|
| VPN Gateway | VpnGw1 | ~90-100€ |
| VM StrongSwan | Standard_B1s | ~8€ |
| IPs publiques (3x) | Standard | ~9€ |
| Bande passante | Variable | ~5-20€ |
| **TOTAL** | | **~115-140€/mois** |

> 💡 Pour réduire les coûts en dev, utiliser `deploy_strongswan = true` et `deploy_ovh_* = false`

## 🗑️ Destruction de l'infrastructure

### Destruction complète

```bash
cd terraform
terraform destroy
```

### Destruction par brique

```bash
./scripts/destroy/destroy-strongswan.sh
./scripts/destroy/destroy-ovh.sh
```

## 🔒 Sécurité

### ⚠️ Points d'attention

1. **PSK (Pre-Shared Keys)** :
   - Minimum 32 caractères
   - Stocker dans Azure Key Vault en production
   - Ne jamais committer dans Git

2. **SSH** :
   - Restreindre `ssh_source_address_prefix` à votre IP
   - Utiliser des clés SSH uniquement (pas de mot de passe)

3. **NSG (Network Security Groups)** :
   - Les NSG sont configurés pour IPsec (UDP 500, 4500, ESP)
   - En production, restreindre les sources

4. **BGP** :
   - Utiliser des adresses APIPA (169.254.x.x)
   - Séparer les peerings BGP par tunnel

Consulter [Documentation/04-SECURITE.md](Documentation/04-SECURITE.md) pour l'audit complet.

## 📊 Monitoring

### Métriques Azure

```bash
# Statut des connexions
az network vpn-connection show --name <connection-name> \
  --resource-group <rg-name> --query connectionStatus

# Bande passante utilisée
az monitor metrics list --resource <vpn-gateway-id> \
  --metric "BitsPerSecond"
```

### Logs IPsec (StrongSwan)

```bash
ssh azureuser@<strongswan-ip>
sudo ipsec status
sudo journalctl -u strongswan -f
```

### Logs BGP (FortiGate)

```bash
get router info bgp summary
get router info bgp neighbors <peer-ip> advertised-routes
```

## 🤝 Contribution

Ce projet est un POC. Les contributions sont bienvenues :

1. Fork le projet
2. Créer une branche (`git checkout -b feature/amelioration`)
3. Committer les changements (`git commit -am 'Ajout fonctionnalité'`)
4. Pusher (`git push origin feature/amelioration`)
5. Créer une Pull Request

## 📝 Notes de version

### Version 1.0 (Actuelle)

- ✅ Infrastructure Azure (VPN Gateway + VM StrongSwan)
- ✅ Tunnels IPsec statiques et BGP
- ✅ Failover automatique RBX ↔ SBG
- ✅ Provisioning Ansible complet
- ✅ Scripts de déploiement et test
- ✅ Documentation complète

### Roadmap

- 🔄 Support Terraform Cloud
- 🔄 Intégration Azure Key Vault pour les secrets
- 🔄 Monitoring avec Azure Monitor
- 🔄 Déploiement multi-région
- 🔄 Support vWAN Azure

## 🆘 Support et Dépannage

### Problèmes courants

| Problème | Solution |
|----------|----------|
| VPN Gateway ne se crée pas | Vérifier les quotas Azure, patienter 45 min |
| Tunnel ne s'établit pas | Vérifier PSK identiques des deux côtés |
| BGP ne converge pas | Vérifier adresses APIPA et ASN |
| SSH refuse connexion | Vérifier NSG et clé SSH |

### Obtenir de l'aide

1. Consulter [Documentation/03-DEPLOIEMENT.md](Documentation/03-DEPLOIEMENT.md)
2. Vérifier les logs : `terraform output` et `ansible-playbook -vvv`
3. Ouvrir une issue sur GitHub

## 📜 Licence

Ce projet est fourni à des fins éducatives et de démonstration.

## 👥 Auteurs

- Équipe POC PRA

## 🙏 Remerciements

- Microsoft Azure Documentation
- OVHCloud Documentation
- StrongSwan Project
- FortiGate Documentation
- Communauté Terraform & Ansible

---

**📖 Pour démarrer :** Consulter [Documentation/03-DEPLOIEMENT.md](Documentation/03-DEPLOIEMENT.md)

**🔧 Questions techniques :** [Documentation/02-TECHNIQUE.md](Documentation/02-TECHNIQUE.md)

**🔒 Sécurité :** [Documentation/04-SECURITE.md](Documentation/04-SECURITE.md)
