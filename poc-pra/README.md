# Solution IPsec S2S : Terraform + Ansible + StrongSwan vers Azure VPN Gateway

## 🎯 Vue d'ensemble

Cette solution déploie une infrastructure complète IPsec Site-to-Site avec :
- **Terraform** pour l'infrastructure (VM StrongSwan + Azure VPN Gateway)
- **Ansible** pour le provisioning et la configuration de StrongSwan
- **Scripts de test** automatisés pour valider la connectivité

## 📁 Structure du projet

```
.
├── terraform/
│   ├── main.tf                      # Infrastructure principale
│   ├── variables.tf                 # Variables Terraform
│   ├── outputs.tf                   # Sorties Terraform
│   ├── terraform.tfvars.example     # Exemple de configuration
│   ├── templates/
│   │   ├── cloud-init-base.yaml     # Cloud-init minimal
│   │   ├── inventory.tpl            # Template inventaire Ansible
│   │   └── ansible_vars.tpl         # Template variables Ansible
│   └── ansible/                     # Répertoire Ansible (généré)
│       ├── playbook.yml
│       ├── inventory.ini            # Généré par Terraform
│       ├── group_vars/
│       │   └── strongswan.yml       # Généré par Terraform
│       └── roles/
│           ├── strongswan/          # Installation StrongSwan
│           ├── ipsec-config/        # Configuration IPsec
│           └── test-scripts/        # Scripts de test
├── deploy.sh                        # Script de déploiement automatique
└── README.md                        # Ce fichier
```

## 🚀 Démarrage rapide (3 étapes)

### 1. Configuration

```bash
# Copier et éditer le fichier de variables
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

Configurer au minimum :
```hcl
ipsec_psk = "VOTRE_PSK_TRES_SECURISE"  # Générer avec: openssl rand -base64 32
ssh_public_key_path = "~/.ssh/id_rsa.pub"
```

### 2. Déploiement de l'infrastructure

```bash
# Initialiser Terraform
terraform init

# Planifier le déploiement (vérifier ce qui sera créé)
terraform plan

# Déployer (⚠️ le VPN Gateway prend 30-45 minutes)
terraform apply
```

### 3. Provisioning avec Ansible

Une fois Terraform terminé :

```bash
# Attendre que la VM soit prête
sleep 60

# Exécuter Ansible
cd ansible
ansible-playbook -i inventory.ini playbook.yml
```

## 🎬 Script de déploiement automatique

Un script complet est fourni pour automatiser tout le processus :

```bash
# Déployer tout automatiquement
./deploy.sh
```

Le script :
1. Vérifie les prérequis (Terraform, Ansible, Azure CLI)
2. Déploie l'infrastructure avec Terraform
3. Attend que le VPN Gateway soit prêt
4. Exécute le provisioning Ansible
5. Lance un test de connectivité

## 📋 Prérequis

### Outils nécessaires

```bash
# Terraform
terraform version  # >= 1.5.0

# Ansible
ansible --version  # >= 2.14

# Azure CLI (authentifié)
az login
az account show

# SSH key
ls ~/.ssh/id_rsa.pub
```

## 🧪 Tests et validation

### Après le déploiement Ansible

```bash
# SSH vers la VM StrongSwan
ssh azureuser@<IP_STRONGSWAN>

# Vérifier le statut IPsec
sudo ipsec status

# Lancer le test complet
sudo /usr/local/bin/test-ipsec.sh

# Générer du trafic continu
sudo /usr/local/bin/continuous-traffic.sh
```

### Vérifier côté Azure

```bash
# Status de la connexion VPN
az network vpn-connection show \
  --name conn-dev-s2s-onprem \
  --resource-group rg-dev-azure-vpn \
  --query connectionStatus -o tsv

# Devrait retourner: Connected
```

## 💰 Coûts Azure estimés

| Ressource | SKU | Coût/mois (France Central) |
|-----------|-----|----------------------------|
| VPN Gateway | VpnGw1 | ~90-100€ |
| VM StrongSwan | B1s | ~8€ |
| Public IPs (2x) | Standard | ~6€ |
| **Total** | | **~105€/mois** |

## 🧹 Nettoyage

```bash
cd terraform
terraform destroy
```

## 📖 Documentation complète

Voir le README complet dans le dossier terraform/ pour :
- Configuration détaillée
- Troubleshooting
- Architecture
- Sécurité
