# Guide de Déploiement - POC PRA

## 📋 Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Prérequis](#prérequis)
3. [Configuration initiale](#configuration-initiale)
4. [Déploiement par scénarios](#déploiement-par-scénarios)
5. [Vérification et tests](#vérification-et-tests)
6. [Dépannage](#dépannage)
7. [Destruction de l'infrastructure](#destruction-de-linfrastructure)

---

## Vue d'ensemble

Ce guide détaille le déploiement de l'infrastructure hybride Azure + OVHCloud.

### Durées estimées

| Composant | Durée |
|-----------|-------|
| VPN Gateway Azure | 30-45 minutes |
| VM StrongSwan | 3-5 minutes |
| Configuration Ansible | 5-10 minutes |
| **Total** | **40-60 minutes** |

### Coûts estimés (France Central)

- VPN Gateway VpnGw1 : ~90-100€/mois
- VM StrongSwan B1s : ~8€/mois
- IPs publiques (3x) : ~9€/mois
- **Total : ~110-120€/mois**

---

## Prérequis

### 1. Outils requis

```bash
# Vérifier Terraform
terraform version
# Requis: >= 1.5.0

# Vérifier Ansible
ansible --version
# Requis: >= 2.14

# Vérifier Azure CLI
az version
# Requis: >= 2.50

# Installer jq (optionnel mais recommandé)
sudo apt install jq  # Debian/Ubuntu
brew install jq      # macOS
```

### 2. Authentification Azure

```bash
# Se connecter à Azure
az login

# Vérifier la souscription active
az account show

# Changer de souscription si nécessaire
az account list --output table
az account set --subscription "Nom ou ID de la souscription"
```

### 3. Clé SSH

```bash
# Vérifier l'existence de votre clé SSH
ls ~/.ssh/id_rsa.pub

# Si elle n'existe pas, la créer
ssh-keygen -t rsa -b 4096 -C "votre-email@example.com"
```

### 4. Accès OVHCloud (optionnel)

Si vous déployez les tunnels OVH :

- Accès à l'interface OVHCloud
- FortiGates déjà déployés sur RBX et SBG
- IPs publiques des FortiGates
- Accès HTTPS aux interfaces de management

---

## Configuration initiale

### Étape 1 : Cloner le repository

```bash
git clone <repository-url>
cd poc-pra-test
```

### Étape 2 : Configurer Terraform

```bash
# Copier l'exemple de configuration
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# Éditer la configuration
nano terraform/terraform.tfvars
```

### Étape 3 : Configuration minimale

Éditer `terraform/terraform.tfvars` avec vos valeurs :

```hcl
# ==============================================================================
# CONFIGURATION MINIMALE POUR DÉMARRER
# ==============================================================================

# Général
environment  = "dev"
project_name = "pra"
owner        = "votre-email@example.com"

# Azure
azure_location = "francecentral"
enable_bgp     = true
azure_bgp_asn  = 65515

# StrongSwan (pour commencer)
deploy_strongswan    = true
ipsec_psk_strongswan = "GENERER_UN_PSK_32_CARACTERES"

# SSH
admin_username = "azureuser"
ssh_public_key_path = "~/.ssh/id_rsa.pub"

# OVH (désactiver pour commencer)
deploy_ovh_rbx = false
deploy_ovh_sbg = false
```

### Étape 4 : Générer un PSK sécurisé

```bash
# Générer un PSK de 32 caractères
openssl rand -base64 32

# Copier le résultat dans terraform.tfvars
# Exemple: ipsec_psk_strongswan = "xK7mP9qR3tY8nV2bC5wL1fG4hJ6dS0aZ"
```

---

## Déploiement par scénarios

### Scénario 1 : Déploiement complet automatique

**Le plus simple - Recommandé pour commencer**

```bash
# Déployer toute l'infrastructure
./deploy.sh --all
```

**Ce qui est fait automatiquement :**
1. ✅ Vérification des prérequis
2. ✅ Initialisation Terraform
3. ✅ Déploiement de l'infrastructure Azure
4. ✅ Configuration StrongSwan avec Ansible
5. ✅ Tests de connectivité

**Durée :** 45-50 minutes

---

### Scénario 2 : Déploiement VPN Gateway uniquement

**Utile pour préparer l'infrastructure Azure d'abord**

```bash
./deploy.sh --vpn
```

**Ce qui est déployé :**
- VPN Gateway Azure
- Virtual Network
- Subnets
- IP publique

**Durée :** 35-45 minutes

---

### Scénario 3 : Déploiement StrongSwan

**Déploie VPN Gateway + VM StrongSwan + Tunnel statique**

```bash
./deploy.sh --strongswan
```

**Ce qui est déployé :**
- Tout du scénario 1 (VPN Gateway)
- VM Ubuntu avec StrongSwan
- Tunnel IPsec statique configuré
- Scripts de test installés

**Durée :** 45-50 minutes

---

### Scénario 4 : Ajout des tunnels OVH

**Prérequis :** VPN Gateway déjà déployé

#### 4.1 Activer OVH dans la configuration

Éditer `terraform/terraform.tfvars` :

```hcl
# OVH RBX (Primary)
deploy_ovh_rbx       = true
ovh_rbx_public_ip    = "1.2.3.4"         # IP publique FortiGate RBX
ovh_rbx_mgmt_ip      = "10.0.0.10"       # IP management FortiGate
ovh_rbx_bgp_asn      = 65001
ovh_rbx_bgp_peer_ip  = "169.254.30.2"
ipsec_psk_rbx        = "PSK_32_CARACTERES_RBX"

# OVH SBG (Backup)
deploy_ovh_sbg       = true
ovh_sbg_public_ip    = "5.6.7.8"         # IP publique FortiGate SBG
ovh_sbg_mgmt_ip      = "10.0.0.20"       # IP management FortiGate
ovh_sbg_bgp_asn      = 65002
ovh_sbg_bgp_peer_ip  = "169.254.31.2"
ipsec_psk_sbg        = "PSK_32_CARACTERES_SBG"
```

#### 4.2 Déployer les tunnels OVH

```bash
./deploy.sh --ovh
```

**Ce qui est déployé :**
- 2 Local Network Gateways (RBX, SBG)
- 2 VPN Connections avec BGP
- Configuration FortiGates via Ansible

**Durée :** 10-15 minutes

---

### Scénario 5 : Déploiement manuel pas à pas

**Pour un contrôle total**

#### 5.1 Terraform uniquement

```bash
cd terraform

# Initialiser Terraform
terraform init

# Valider la configuration
terraform validate

# Voir le plan de déploiement
terraform plan

# Appliquer (création infrastructure)
terraform apply

# Voir les outputs
terraform output
```

#### 5.2 Attendre la disponibilité

```bash
# Le VPN Gateway prend 30-45 minutes
# Vérifier via le portail Azure ou :
az network vnet-gateway show \
  --name vpngw-dev-pra \
  --resource-group rg-dev-pra-vpn \
  --query provisioningState
```

#### 5.3 Ansible - Configuration StrongSwan

```bash
cd ../ansible

# Vérifier l'inventaire généré par Terraform
cat inventories/dev/strongswan.ini

# Tester la connectivité SSH
ansible -i inventories/dev/strongswan.ini strongswan -m ping

# Exécuter le playbook
ansible-playbook -i inventories/dev/strongswan.ini \
  playbooks/01-configure-strongswan.yml
```

#### 5.4 Ansible - Configuration FortiGates (optionnel)

```bash
# Vérifier l'inventaire
cat inventories/dev/fortigates.ini

# Exécuter le playbook
ansible-playbook -i inventories/dev/fortigates.ini \
  playbooks/02-configure-fortigates.yml
```

---

## Vérification et tests

### 1. Vérifier le déploiement Terraform

```bash
cd terraform
terraform output

# Vérifier les IPs
terraform output azure_vpn_gateway_public_ip
terraform output strongswan_public_ip
```

### 2. Vérifier le statut des tunnels VPN

```bash
# Script automatique
./scripts/test/check-vpn-status.sh

# Ou manuellement
az network vpn-connection show \
  --name conn-dev-pra-s2s-onprem \
  --resource-group rg-dev-pra-vpn \
  --query connectionStatus -o tsv
# Résultat attendu: Connected
```

### 3. Se connecter à StrongSwan

```bash
# Récupérer l'IP publique
STRONGSWAN_IP=$(cd terraform && terraform output -raw strongswan_public_ip)

# SSH
ssh azureuser@${STRONGSWAN_IP}

# Vérifier IPsec
sudo ipsec status

# Sortie attendue:
# Security Associations (1 up, 0 connecting):
# azure-tunnel[1]: ESTABLISHED 5 minutes ago
```

### 4. Tester la connectivité

```bash
# Sur la VM StrongSwan
sudo /usr/local/bin/test-ipsec.sh

# Sortie attendue:
# ✅ Tunnel IPsec UP
# ✅ Ping vers Azure : OK
# ✅ Traceroute utilise le tunnel
```

### 5. Vérifier les routes BGP (si activé)

```bash
az network vnet-gateway list-learned-routes \
  --name vpngw-dev-pra \
  --resource-group rg-dev-pra-vpn \
  --output table

# Sortie attendue (si OVH déployé):
# Network            Origin    AsPath    LocalAddress
# -----------------------------------------------------
# 192.168.10.0/24    EBgp      65001     10.1.255.4
# 192.168.20.0/24    EBgp      65002     10.1.255.4
```

### 6. Tester le failover RBX → SBG (si OVH déployé)

```bash
# Simuler panne RBX
./scripts/test/simulate-rbx-failure.sh

# Vérifier le basculement vers SBG
./scripts/test/check-vpn-status.sh

# Résultat attendu:
# RBX : NotConnected ❌
# SBG : Connected ✅ (actif en backup)

# Restaurer RBX
./scripts/test/restore-rbx.sh

# Vérifier le retour sur RBX
./scripts/test/check-vpn-status.sh

# Résultat attendu:
# RBX : Connected ✅ (redevient primary)
# SBG : Connected ✅ (redevient backup)
```

---

## Dépannage

### Problème 1 : VPN Gateway ne se crée pas

**Symptômes :**
- Erreur de timeout Terraform
- Provisioning state = "Failed"

**Solutions :**

```bash
# Vérifier les quotas Azure
az network vnet-gateway list --output table

# Vérifier les limites de la souscription
az vm list-usage --location francecentral -o table

# Si échec, détruire et recréer
terraform destroy -target=module.azure_vpn_gateway
terraform apply
```

### Problème 2 : Tunnel ne s'établit pas

**Symptômes :**
- `connectionStatus: NotConnected`
- Logs StrongSwan : "no IKE proposal"

**Solutions :**

```bash
# 1. Vérifier que les PSK sont identiques
cd terraform
terraform output -json | jq -r '.deployment_summary.value'

# 2. Vérifier les NSG (ports UDP 500, 4500, ESP)
az network nsg show -name nsg-dev-pra-strongswan \
  -g rg-dev-pra-onprem --query "securityRules[*].[name,destinationPortRange]"

# 3. Vérifier les logs StrongSwan
ssh azureuser@<strongswan-ip>
sudo journalctl -u strongswan -n 100 --no-pager

# 4. Redémarrer StrongSwan
sudo systemctl restart strongswan
sudo ipsec restart
```

### Problème 3 : BGP ne converge pas

**Symptômes :**
- Pas de routes BGP apprises
- `get router info bgp summary` montre "Idle"

**Solutions :**

```bash
# 1. Vérifier les adresses APIPA
az network vnet-gateway show \
  --name vpngw-dev-pra \
  --resource-group rg-dev-pra-vpn \
  --query "bgpSettings"

# 2. Vérifier la configuration FortiGate
# Sur le FortiGate :
get router info bgp summary
get router info bgp neighbors <azure-bgp-ip> advertised-routes

# 3. Vérifier que le tunnel IPsec est UP
get vpn ipsec tunnel summary

# 4. Restart BGP sur FortiGate
execute router clear bgp all soft
```

### Problème 4 : Ansible échoue

**Symptômes :**
- Erreur SSH lors du playbook
- "Host key verification failed"

**Solutions :**

```bash
# 1. Vérifier la connectivité SSH
STRONGSWAN_IP=$(cd terraform && terraform output -raw strongswan_public_ip)
ssh -v azureuser@${STRONGSWAN_IP}

# 2. Ajouter la clé SSH à known_hosts
ssh-keyscan -H ${STRONGSWAN_IP} >> ~/.ssh/known_hosts

# 3. Vérifier l'inventaire Ansible
cat ansible/inventories/dev/strongswan.ini

# 4. Tester avec verbose
ansible-playbook -i ansible/inventories/dev/strongswan.ini \
  ansible/playbooks/01-configure-strongswan.yml -vvv

# 5. Attendre plus longtemps après création VM
sleep 120  # Attendre 2 minutes
```

### Problème 5 : Terraform state corrompu

**Symptômes :**
- "Error: resource already exists"
- State incohérent avec Azure

**Solutions :**

```bash
# 1. Importer une ressource existante
terraform import module.azure_vpn_gateway.azurerm_resource_group.vpn \
  /subscriptions/<sub-id>/resourceGroups/rg-dev-pra-vpn

# 2. Récupérer depuis un backup
ls terraform.tfstate.backup*
cp terraform.tfstate.backup.YYYYMMDD terraform.tfstate

# 3. En dernier recours, recréer le state
terraform state rm <resource-address>
terraform import <resource-address> <azure-resource-id>
```

---

## Destruction de l'infrastructure

### ⚠️ ATTENTION

La destruction supprime **DÉFINITIVEMENT** toutes les ressources. Cette action est **IRRÉVERSIBLE**.

### Destruction complète

```bash
cd terraform

# Voir ce qui sera détruit
terraform plan -destroy

# Confirmer et détruire
terraform destroy

# Répondre "yes" pour confirmer
```

### Destruction sélective

#### Détruire uniquement StrongSwan

```bash
cd terraform
terraform destroy -target=module.strongswan_vm
terraform destroy -target=module.tunnel_ipsec_static
```

#### Détruire uniquement les tunnels OVH

```bash
terraform destroy -target=module.tunnel_ipsec_bgp_rbx
terraform destroy -target=module.tunnel_ipsec_bgp_sbg
```

#### Détruire le VPN Gateway

```bash
# ⚠️  Cela détruira TOUS les tunnels
terraform destroy -target=module.azure_vpn_gateway
```

### Scripts de destruction

```bash
# Destruction par composant
./scripts/destroy/destroy-strongswan.sh
./scripts/destroy/destroy-ovh.sh

# Destruction complète
./scripts/destroy/destroy-all.sh
```

### Vérification post-destruction

```bash
# Vérifier qu'il ne reste aucun resource group
az group list --output table | grep "pra"

# Si des ressources persistent, les supprimer manuellement
az group delete --name rg-dev-pra-vpn --yes --no-wait
az group delete --name rg-dev-pra-onprem --yes --no-wait
```

---

## Checklist de déploiement

### Avant de commencer

- [ ] Terraform >= 1.5.0 installé
- [ ] Ansible >= 2.14 installé
- [ ] Azure CLI authentifié (`az login`)
- [ ] Clé SSH créée (`~/.ssh/id_rsa.pub`)
- [ ] Fichier `terraform.tfvars` configuré
- [ ] PSK générés (32 caractères minimum)
- [ ] Budget Azure suffisant (~110€/mois)

### Pendant le déploiement

- [ ] `terraform init` réussi
- [ ] `terraform validate` sans erreur
- [ ] `terraform plan` vérifié
- [ ] VPN Gateway créé (30-45 min)
- [ ] VM StrongSwan accessible en SSH
- [ ] Playbook Ansible réussi

### Après le déploiement

- [ ] Tunnels VPN status = "Connected"
- [ ] Ping réussi depuis StrongSwan vers Azure
- [ ] Routes BGP apprises (si OVH déployé)
- [ ] Failover RBX→SBG testé (si OVH déployé)
- [ ] Documentation consultée

---

## Prochaines étapes

Après un déploiement réussi :

1. **Consulter la documentation technique** : [02-TECHNIQUE.md](02-TECHNIQUE.md)
2. **Lire l'audit de sécurité** : [04-SECURITE.md](04-SECURITE.md)
3. **Explorer les scripts de test** : `scripts/test/`
4. **Configurer le monitoring** : Azure Monitor, Log Analytics
5. **Planifier les sauvegardes** : Terraform state, configurations

---

## Support

Pour toute question ou problème :

1. Consulter cette documentation
2. Vérifier les logs (`terraform output`, `ansible-playbook -vvv`)
3. Consulter [02-TECHNIQUE.md](02-TECHNIQUE.md) pour les détails
4. Ouvrir une issue sur GitHub

---

**Bon déploiement ! 🚀**
