# Guide de Configuration des Variables d'Environnement

## Vue d'ensemble

Ce projet utilise un système de gestion des variables d'environnement séparant les **variables publiques** (configuration générale) des **variables sensibles** (secrets, credentials).

## Architecture des Fichiers

```
poc-pra-test/
├── .env.dist                    # Template des variables NON sensibles (🟢 🟠)
├── .env-protected.dist          # Template des variables SENSIBLES (🔴)
├── .env                         # Variables réelles NON sensibles (local, non committé)
├── .env-protected               # Variables réelles SENSIBLES (local, non committé)
├── scripts/utils/load-env.sh    # Script helper pour charger les variables
└── VARIABLES_ENVIRONNEMENT.md   # Documentation complète des variables
```

## 🎯 Démarrage Rapide

### Étape 1 : Initialiser les Fichiers

```bash
# Copier les templates
cp .env.dist .env
cp .env-protected.dist .env-protected
```

### Étape 2 : Configurer les Variables

```bash
# Éditer le fichier des variables publiques
nano .env

# Éditer le fichier des variables sensibles
nano .env-protected
```

**Variables à configurer en priorité :**

#### Dans `.env` :
- `ENVIRONMENT` : dev, test, staging, ou prod
- `AZURE_LOCATION` : Région Azure (ex: francecentral)
- `DEPLOY_STRONGSWAN` : true/false
- `DEPLOY_OVH_RBX` : true/false
- `DEPLOY_OVH_SBG` : true/false

#### Dans `.env-protected` :
- `ARM_SUBSCRIPTION_ID` : ID de votre souscription Azure
- `ARM_CLIENT_ID` : ID du Service Principal
- `ARM_CLIENT_SECRET` : Secret du Service Principal
- `ARM_TENANT_ID` : ID du tenant Azure AD
- `IPSEC_PSK_STRONGSWAN` : Pre-Shared Key pour StrongSwan
- (Autres secrets selon votre déploiement)

### Étape 3 : Charger les Variables

```bash
# Charger toutes les variables (publiques + sensibles)
source scripts/utils/load-env.sh --with-protected --export-terraform

# Vérifier que tout est configuré
source scripts/utils/load-env.sh --check
```

### Étape 4 : Déployer

```bash
# Les variables sont maintenant chargées, vous pouvez déployer
cd terraform
terraform init
terraform plan
terraform apply
```

## 🔐 Gestion des Secrets en Production

### Option 1 : Azure Key Vault (Recommandé)

```bash
# 1. Créer un Azure Key Vault
az keyvault create \
  --name poc-pra-vault \
  --resource-group rg-poc-pra-secrets \
  --location francecentral

# 2. Ajouter les secrets
az keyvault secret set --vault-name poc-pra-vault \
  --name ARM-SUBSCRIPTION-ID --value "12345678-1234-..."

az keyvault secret set --vault-name poc-pra-vault \
  --name IPSEC-PSK-STRONGSWAN --value "MyStr0ng!PSK..."

# 3. Charger les secrets dans votre session
export AZURE_KEYVAULT_NAME=poc-pra-vault
source scripts/utils/load-env.sh --from-vault azure-keyvault --export-terraform
```

### Option 2 : GitLab CI/CD Variables

```
Projet GitLab → Settings → CI/CD → Variables
```

Ajouter chaque variable sensible avec les options :
- **Type** : Variable
- **Protégée** : ✅ (uniquement sur branches protégées)
- **Masquée** : ✅ (cachée dans les logs)

Préfixer avec `TF_VAR_` pour Terraform :
- `TF_VAR_ipsec_psk_strongswan`
- `TF_VAR_vcenter_rbx_password`
- etc.

### Option 3 : GitHub Actions Secrets

```
Repository → Settings → Secrets and variables → Actions → New repository secret
```

Ajouter chaque variable sensible en MAJUSCULES :
- `TF_VAR_IPSEC_PSK_STRONGSWAN`
- `ARM_CLIENT_SECRET`
- etc.

## 📋 Commandes Utiles

### Charger uniquement les variables publiques

```bash
source scripts/utils/load-env.sh
```

### Charger variables publiques + sensibles

```bash
source scripts/utils/load-env.sh --with-protected
```

### Charger et exporter pour Terraform

```bash
source scripts/utils/load-env.sh --with-protected --export-terraform
```

### Charger depuis Azure Key Vault

```bash
export AZURE_KEYVAULT_NAME=poc-pra-vault
source scripts/utils/load-env.sh --from-vault azure-keyvault
```

### Vérifier les variables requises

```bash
source scripts/utils/load-env.sh --with-protected --check
```

### Afficher l'aide

```bash
source scripts/utils/load-env.sh --help
```

## 🔒 Bonnes Pratiques de Sécurité

### 1. Protection des Fichiers Locaux

```bash
# S'assurer que les fichiers .env ne sont pas committés
git status
# .env et .env-protected ne doivent PAS apparaître

# Vérifier le .gitignore
cat .gitignore | grep -E "^\.env$"
```

### 2. Génération de Secrets Forts

```bash
# Générer un PSK IPsec (64 caractères)
openssl rand -base64 48

# Générer un token API (32 caractères hex)
openssl rand -hex 32

# Générer un mot de passe complexe (24 caractères)
openssl rand -base64 18 | tr -d "=+/" | cut -c1-24
```

### 3. Rotation des Secrets

**Calendrier recommandé :**
- 🔴 PSK IPsec : **tous les 90 jours**
- 🔴 API Keys (FortiGate, Zerto, Veeam) : **tous les 180 jours**
- 🔴 Mots de passe vCenter : **tous les 365 jours**
- 🔴 Azure Service Principal : **tous les 365 jours**

```bash
# Script de rotation automatique (à créer)
./scripts/security/rotate-secrets.sh --type ipsec-psk
```

### 4. Audit des Accès

```bash
# Vérifier qui a accès aux secrets
az keyvault show --name poc-pra-vault --query properties.accessPolicies

# Logs d'accès
az monitor activity-log list --resource-group rg-poc-pra-secrets
```

## 🧪 Tests et Validation

### Tester en Local (Environnement Dev)

```bash
# 1. Configurer pour dev
echo "ENVIRONMENT=dev" > .env
echo "DEPLOY_STRONGSWAN=true" >> .env

# 2. Charger les variables
source scripts/utils/load-env.sh --with-protected --export-terraform

# 3. Vérifier
env | grep -E "^(ENVIRONMENT|TF_VAR_)" | sort
```

### Tester en Staging

```bash
# 1. Changer l'environnement
export ENVIRONMENT=staging

# 2. Charger les variables du bon environnement
source scripts/utils/load-env.sh --env staging --with-protected
```

## 🐛 Dépannage

### Problème : Variables non chargées

```bash
# Vérifier que le script est sourcé (et non exécuté)
# ❌ INCORRECT
./scripts/utils/load-env.sh

# ✅ CORRECT
source scripts/utils/load-env.sh
```

### Problème : Secret manquant dans Azure Key Vault

```bash
# Lister tous les secrets
az keyvault secret list --vault-name poc-pra-vault --query "[].name" -o table

# Ajouter un secret manquant
az keyvault secret set --vault-name poc-pra-vault \
  --name NOM-DU-SECRET --value "valeur"
```

### Problème : Permission refusée sur Azure Key Vault

```bash
# Vérifier vos permissions
az keyvault show --name poc-pra-vault --query properties.accessPolicies

# Ajouter des permissions
az keyvault set-policy --name poc-pra-vault \
  --upn user@example.com \
  --secret-permissions get list
```

## 📚 Ressources

- [Documentation complète des variables](./VARIABLES_ENVIRONNEMENT.md)
- [Guide de déploiement](./Documentation/03-DEPLOIEMENT.md)
- [Azure Key Vault Documentation](https://docs.microsoft.com/azure/key-vault/)
- [Terraform Environment Variables](https://www.terraform.io/cli/config/environment-variables)

## 📞 Support

En cas de problème :
1. Vérifier la documentation : `./VARIABLES_ENVIRONNEMENT.md`
2. Consulter les logs : `cat /tmp/load-env.log`
3. Contacter l'équipe : poc-pra-team@example.com
