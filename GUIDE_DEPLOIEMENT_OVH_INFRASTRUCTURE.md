# Guide d'Utilisation - Déploiement Unifié POC PRA

## 🚀 Déploiement de l'Infrastructure OVH VMware

L'infrastructure OVH VMware (Docker + MySQL + Zerto PRA) est maintenant intégrée au script de déploiement principal `deploy.sh`.

### Option 1 : Déploiement Infrastructure OVH uniquement

```bash
# 1. Configurer les variables Terraform
cd terraform/ovh-infrastructure
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Configurer vos valeurs

# 2. Lancer le déploiement
cd ../..
./deploy.sh --ovh-infra
```

### Option 2 : Déploiement complet (VPN + OVH + Infrastructure VMware)

```bash
# Déploie TOUTE l'infrastructure :
# • VPN Gateway Azure avec BGP
# • VM StrongSwan + Tunnels IPsec
# • Tunnels FortiGate vers OVH (RBX + SBG)
# • Infrastructure applicative OVH VMware (4 VMs)
# • Virtual Protection Groups Zerto

./deploy.sh --all
```

### Option 3 : Déploiement par étapes

```bash
# Étape 1 : Déployer le VPN Gateway Azure
./deploy.sh --vpn

# Étape 2 : Déployer les tunnels vers OVH
./deploy.sh --ovh

# Étape 3 : Déployer l'infrastructure applicative OVH
./deploy.sh --ovh-infra
```

## 📋 Prérequis

### Outils requis

- **Terraform** >= 1.5.0
- **Ansible** >= 2.14
- **Azure CLI** (si déploiement VPN Azure)
- **jq** (optionnel mais recommandé)

```bash
# Vérifier les versions
terraform --version
ansible --version
az --version
jq --version
```

### Configuration OVH VMware

Avant de déployer `--ovh-infra`, assurez-vous d'avoir :

1. **Templates Ubuntu 22.04** créés dans vCenter RBX et SBG
2. **vRack OVH configuré** avec VLANs 100, 200, 900 (via OVH Manager)
3. **Distributed Switches vSphere** créés et attachés au vRack
4. **API Tokens FortiGate** générés (RBX + SBG)
5. **IDs Sites Zerto** récupérés (via Zerto UI)
6. **Clé SSH** générée : `ssh-keygen -t rsa -b 4096`

### Fichiers de configuration requis

#### Pour VPN Azure (--vpn, --strongswan, --ovh, --all)
```bash
terraform/terraform.tfvars
```

#### Pour Infrastructure OVH (--ovh-infra, --all)
```bash
terraform/ovh-infrastructure/terraform.tfvars
```

## 🎯 Modes de Déploiement

| Mode | Description | Durée | Coût |
|------|-------------|-------|------|
| `--vpn` | VPN Gateway Azure uniquement | ~45 min | ~90€/mois |
| `--strongswan` | VPN + StrongSwan + Tunnel statique | ~50 min | ~100€/mois |
| `--ovh` | VPN + Tunnels FortiGate (RBX + SBG) | ~50 min | ~100€/mois |
| `--ovh-infra` | Infrastructure OVH VMware (4 VMs) | ~30 min | ~170€/mois |
| `--all` | Toute l'infrastructure | ~60-90 min | ~270€/mois |

## 🔧 Options Avancées

### Déploiement Terraform uniquement (sans Ansible)

```bash
./deploy.sh --ovh-infra --terraform-only
```

### Exécuter Ansible uniquement (Terraform déjà fait)

```bash
./deploy.sh --ovh-infra --ansible-only
```

### Ignorer les vérifications de prérequis

```bash
./deploy.sh --ovh-infra --skip-checks
```

## 📊 Résumé Post-Déploiement

Après un déploiement `--ovh-infra` réussi, vous verrez :

```
🐳 VMs Docker déployées :
  • RBX: VM-DOCKER-APP-A-RBX (10.100.0.10)
  • SBG: VM-DOCKER-APP-B-SBG (10.200.0.10)

🐬 VMs MySQL déployées :
  • RBX: VM-MYSQL-APP-A-RBX (10.100.0.11) - DB: app_rbx_db
  • SBG: VM-MYSQL-APP-B-SBG (10.200.0.11) - DB: app_sbg_db

🔒 Virtual Protection Groups (VPG) Zerto :
  • RBX → SBG: VPG-RBX-to-SBG-prod (2 VMs)
  • SBG → RBX: VPG-SBG-to-RBX-prod (2 VMs)
```

## 🧪 Tests de Validation

### Vérifier connectivité SSH

```bash
# Récupérer les IPs
cd terraform/ovh-infrastructure
terraform output

# Tester SSH
ssh vmadmin@10.100.0.10  # Docker RBX
ssh vmadmin@10.100.0.11  # MySQL RBX
ssh vmadmin@10.200.0.10  # Docker SBG
ssh vmadmin@10.200.0.11  # MySQL SBG
```

### Vérifier MySQL

```bash
# Depuis VM Docker RBX, tester connexion MySQL
ssh vmadmin@10.100.0.10
docker run --rm mysql:8.0 mysql -h 10.100.0.11 -u appuser -p -e "SHOW DATABASES;"
```

### Vérifier Docker

```bash
ssh vmadmin@10.100.0.10
docker --version
docker-compose --version
docker ps
```

### Vérifier Zerto VPG

- Ouvrir Zerto UI : https://zerto-ui.ovh.net (URL de votre Zerto)
- Vérifier que les 2 VPG sont en statut **"Meeting SLA"**
- RPO actuel doit être < 300 secondes

## 🗑️ Destruction de l'Infrastructure

### Détruire uniquement l'infrastructure OVH VMware

```bash
./scripts/destroy-ovh-infrastructure.sh
```

**⚠️ ATTENTION** : Cette commande supprimera définitivement :
- Toutes les VMs (données comprises)
- Les configurations réseau
- Les règles FortiGate
- Les VPG Zerto

Vous devrez taper `DESTROY` (en majuscules) pour confirmer.

### Destruction avec auto-approve (CI/CD uniquement)

```bash
./scripts/destroy-ovh-infrastructure.sh --auto-approve
```

## 📚 Documentation Complète

### ADR (Architecture Decision Records)
- `Documentation/adr/2025-12-30-infrastructure-applicative-ovh-vmware.md`

### Documentation Fonctionnelle
- `Documentation/features/ovh-vmware-infrastructure/functional.md`
  - Cas d'usage
  - Règles métier
  - Acteurs et contraintes

### Documentation Technique
- `Documentation/features/ovh-vmware-infrastructure/technical.md`
  - Architecture détaillée (diagrammes Mermaid)
  - Spécifications modules Terraform
  - Configuration réseau et FortiGate
  - Troubleshooting

### Variables d'Environnement
- `VARIABLES_ENVIRONNEMENT_OVH_INFRASTRUCTURE.md`
  - Documentation des 60+ variables
  - Niveaux de sensibilité (🟢 🟠 🔴)
  - Exemples et recommandations

## 🆘 Troubleshooting

### Erreur : "terraform.tfvars not found"

```bash
cd terraform/ovh-infrastructure
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Configurer vos valeurs
```

### Erreur : "VMs not responding to SSH"

```bash
# Attendre 2-3 minutes après le déploiement (cloud-init en cours)
# Vérifier depuis vCenter que les VMs sont démarrées
# Consulter les logs cloud-init :
ssh vmadmin@<vm-ip>
sudo tail -f /var/log/cloud-init-output.log
```

### Erreur : "FortiGate API connection failed"

```bash
# Vérifier connectivité FortiGate
curl -k https://<fortigate-ip>/api/v2/cmdb/system/admin

# Vérifier token API (doit être valide)
# Régénérer si nécessaire via FortiGate UI :
# System > Administrators > Create New > REST API Admin
```

### Erreur : "Zerto VPG creation failed"

- Vérifier que les IDs sites Zerto sont corrects (Zerto UI → Sites)
- S'assurer que Zerto Virtual Manager est actif sur les deux sites
- Vérifier connectivité réseau entre RBX et SBG (ports 4007-4008)

## 🔗 Liens Utiles

- [Documentation OVH Private Cloud VMware](https://docs.ovh.com/fr/private-cloud/)
- [Terraform Provider vSphere](https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs)
- [Terraform Provider FortiOS](https://registry.terraform.io/providers/fortinetdev/fortios/latest/docs)
- [Zerto Virtual Replication](https://www.zerto.com/myzerto/knowledge-base/)
- [MySQL 8.0 Documentation](https://dev.mysql.com/doc/refman/8.0/en/)

## 📞 Support

Pour toute question ou problème :
1. Consulter la documentation dans `Documentation/`
2. Vérifier les logs Terraform : `terraform/ovh-infrastructure/terraform.log`
3. Vérifier les logs Ansible : `ansible/playbooks/ovh-infrastructure/ansible.log`
4. Créer une issue GitHub avec logs et détails de l'erreur
