# Roadmap et Améliorations - POC PRA

## 📋 Table des matières

1. [Vision et Roadmap](#vision-et-roadmap)
2. [CI/CD GitLab - Configuration complète](#cicd-gitlab---configuration-complète)
3. [Améliorations Infrastructure](#améliorations-infrastructure)
4. [Améliorations Sécurité](#améliorations-sécurité)
5. [Améliorations Monitoring](#améliorations-monitoring)
6. [Améliorations Code](#améliorations-code)
7. [Tests automatisés](#tests-automatisés)
8. [Documentation additionnelle](#documentation-additionnelle)
9. [Optimisations de coûts](#optimisations-de-coûts)
10. [Conformité et Gouvernance](#conformité-et-gouvernance)

---

## Vision et Roadmap

### Phase actuelle : POC (v1.0) ✅

**Ce qui est fait :**
- ✅ Infrastructure de base Azure + OVHCloud
- ✅ Tunnels IPsec avec chiffrement AES-256
- ✅ BGP avec failover automatique RBX ↔ SBG
- ✅ Infrastructure as Code (Terraform + Ansible)
- ✅ Documentation complète (7500+ lignes)
- ✅ Scripts de déploiement et test

**Limitations actuelles :**
- ⚠️ Secrets en clair dans terraform.tfvars
- ⚠️ Pas de CI/CD automatisé
- ⚠️ Monitoring basique
- ⚠️ Tests manuels
- ⚠️ Pas de disaster recovery automatisé

---

### Phase 2 : Production Ready (v2.0) 🎯

**Objectif :** Préparer le POC pour un environnement de production

**Délai estimé :** 3-4 semaines

**Composants à ajouter :**

#### 2.1 Gestion des Secrets Sécurisée
- [ ] Migration vers Azure Key Vault pour tous les secrets
- [ ] Rotation automatique des PSK (90 jours)
- [ ] Utilisation d'identités managées
- [ ] Chiffrement des variables Terraform avec SOPS
- [ ] Audit trail pour accès aux secrets

#### 2.2 CI/CD Complet
- [ ] Pipeline GitLab CI pour validation
- [ ] Tests automatisés (Terratest, InSpec)
- [ ] Déploiement automatique en dev/staging
- [ ] Validation manuelle pour prod
- [ ] Rollback automatique en cas d'échec

#### 2.3 Monitoring et Alerting
- [ ] Azure Monitor avec Log Analytics
- [ ] Dashboards pour tunnels VPN
- [ ] Alertes critiques (tunnel down, BGP down)
- [ ] Métriques de performance (latence, throughput)
- [ ] Logs centralisés avec retention 90 jours

#### 2.4 Sécurité Renforcée
- [ ] Azure Bastion pour accès SSH sécurisé
- [ ] NSG avec règles restrictives (IPs spécifiques)
- [ ] Activation Azure Defender
- [ ] Scan de vulnérabilités automatique
- [ ] Compliance checks automatisés

#### 2.5 Disaster Recovery
- [ ] Backups automatiques des configurations
- [ ] Plan de reprise documenté et testé
- [ ] Scripts de restauration automatique
- [ ] Tests DR trimestriels automatisés

**Coûts additionnels estimés :** +50-80€/mois
**ROI :** Réduction des incidents de 70%, temps de résolution -60%

---

### Phase 3 : Scalabilité et Optimisation (v3.0) 🚀

**Objectif :** Supporter plus de sites et améliorer les performances

**Délai estimé :** 2-3 mois après Phase 2

**Composants à ajouter :**

#### 3.1 Multi-région Azure
- [ ] Déploiement dans 2+ régions Azure
- [ ] Load balancing entre régions
- [ ] Geo-redundancy pour haute disponibilité
- [ ] Traffic Manager pour routage intelligent

#### 3.2 Expansion OVHCloud
- [ ] Ajout datacenters GRA (Gravelines)
- [ ] Ajout datacenters WAW (Varsovie)
- [ ] Mesh BGP complet entre tous les sites
- [ ] Routage optimal basé sur latence

#### 3.3 Performance
- [ ] Upgrade VPN Gateway vers VpnGw2 (1 Gbps)
- [ ] Mode Active-Active pour redondance
- [ ] Optimisations TCP (MSS clamping, window scaling)
- [ ] Utilisation d'ExpressRoute pour trafic critique

#### 3.4 Automatisation Avancée
- [ ] Auto-scaling basé sur métriques
- [ ] Self-healing automatique
- [ ] Drift detection et correction
- [ ] Chatops (déploiements via Slack/Teams)

**Coûts additionnels estimés :** +200-300€/mois
**ROI :** Support de 10x plus de trafic, latence -40%

---

### Phase 4 : Enterprise Grade (v4.0) 🏢

**Objectif :** Solution enterprise avec gouvernance complète

**Délai estimé :** 6 mois après Phase 3

**Composants à ajouter :**

#### 4.1 Gouvernance
- [ ] Azure Policy pour compliance automatique
- [ ] Tagging strategy imposée
- [ ] Budget alerts et cost management
- [ ] RBAC granulaire par équipe

#### 4.2 Sécurité Avancée
- [ ] Azure Sentinel (SIEM)
- [ ] Threat intelligence integration
- [ ] WAF pour applications exposées
- [ ] DDoS Protection Standard

#### 4.3 Observabilité
- [ ] APM (Application Performance Monitoring)
- [ ] Distributed tracing
- [ ] SLI/SLO/SLA tracking
- [ ] Chaos engineering pour tests de résilience

#### 4.4 Multi-Cloud
- [ ] Support AWS Transit Gateway
- [ ] Support GCP Cloud VPN
- [ ] Abstraction multi-cloud avec Terraform
- [ ] FinOps pour optimisation coûts multi-cloud

**Coûts additionnels estimés :** +500-800€/mois
**ROI :** Conformité réglementaire, réduction risques business

---

## CI/CD GitLab - Configuration complète

### Architecture CI/CD

```
┌─────────────────────────────────────────────────────────┐
│                    GitLab Repository                     │
└────────────┬────────────────────────────────────────────┘
             │
             │ Push / Merge Request
             │
┌────────────▼────────────────────────────────────────────┐
│                   GitLab CI Pipeline                     │
│                                                          │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  │
│  │ Validate│─>│  Test   │─>│ Plan    │─>│ Deploy  │  │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘  │
│       │            │             │            │         │
│   TFLint      Terratest     Terraform    Terraform     │
│   TFSec       InSpec        Plan         Apply         │
│   Ansible     Checkov                    Ansible       │
│   Lint                                                  │
└─────────────────────────────────────────────────────────┘
             │
             │ Artefacts, Logs, State
             │
┌────────────▼────────────────────────────────────────────┐
│            GitLab Container Registry                     │
│            Terraform State (S3/GitLab)                   │
│            Azure Monitor / Log Analytics                 │
└──────────────────────────────────────────────────────────┘
```

### Fichier `.gitlab-ci.yml` complet

```yaml
# ==============================================================================
# CI/CD Pipeline GitLab - POC PRA
# ==============================================================================
# Description : Pipeline complet de validation, test et déploiement
#               de l'infrastructure Azure + OVHCloud
# Version     : 1.0
# ==============================================================================

# Variables globales
variables:
  TF_VERSION: "1.6.5"
  ANSIBLE_VERSION: "2.15"
  TF_ROOT: "${CI_PROJECT_DIR}/terraform"
  TF_STATE_NAME: "poc-pra-${CI_ENVIRONMENT_NAME}"

  # Azure
  ARM_SKIP_PROVIDER_REGISTRATION: "true"

  # Terraform Backend (GitLab Managed State)
  TF_ADDRESS: "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/terraform/state/${TF_STATE_NAME}"
  TF_HTTP_USERNAME: "gitlab-ci-token"
  TF_HTTP_PASSWORD: "${CI_JOB_TOKEN}"
  TF_HTTP_LOCK_ADDRESS: "${TF_ADDRESS}/lock"
  TF_HTTP_LOCK_METHOD: "POST"
  TF_HTTP_UNLOCK_ADDRESS: "${TF_ADDRESS}/lock"
  TF_HTTP_UNLOCK_METHOD: "DELETE"
  TF_HTTP_RETRY_WAIT_MIN: "5"

# Images Docker
image:
  name: hashicorp/terraform:${TF_VERSION}
  entrypoint: [""]

# Stages du pipeline
stages:
  - validate      # Validation syntaxe et sécurité
  - test          # Tests automatisés
  - plan          # Planification Terraform
  - deploy        # Déploiement
  - verify        # Vérification post-déploiement
  - destroy       # Destruction (manuel)

# Cache pour accélérer les jobs
cache:
  key: "${CI_COMMIT_REF_SLUG}"
  paths:
    - ${TF_ROOT}/.terraform
    - ${TF_ROOT}/.terraform.lock.hcl

# ==============================================================================
# Templates réutilisables
# ==============================================================================

.terraform_base:
  before_script:
    - cd ${TF_ROOT}
    - terraform --version
    - terraform init -backend-config="address=${TF_ADDRESS}"

.ansible_base:
  image: cytopia/ansible:${ANSIBLE_VERSION}
  before_script:
    - ansible --version
    - ansible-lint --version

.azure_auth:
  before_script:
    - |
      # Authentification Azure avec Service Principal
      export ARM_CLIENT_ID="${AZURE_CLIENT_ID}"
      export ARM_CLIENT_SECRET="${AZURE_CLIENT_SECRET}"
      export ARM_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID}"
      export ARM_TENANT_ID="${AZURE_TENANT_ID}"

# ==============================================================================
# STAGE: VALIDATE
# ==============================================================================

validate:terraform:format:
  stage: validate
  extends: .terraform_base
  script:
    - terraform fmt -check -recursive
  allow_failure: false
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    - if: '$CI_COMMIT_BRANCH == "main"'
    - if: '$CI_COMMIT_BRANCH =~ /^claude\/.*/'

validate:terraform:lint:
  stage: validate
  image: ghcr.io/terraform-linters/tflint:latest
  script:
    - cd ${TF_ROOT}
    - tflint --init
    - tflint --recursive --format=compact
  allow_failure: true
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    - if: '$CI_COMMIT_BRANCH == "main"'

validate:terraform:security:
  stage: validate
  image: aquasec/tfsec:latest
  script:
    - tfsec ${TF_ROOT} --format=json --out=tfsec-report.json
    - tfsec ${TF_ROOT} --format=default
  artifacts:
    reports:
      sast: tfsec-report.json
    expire_in: 1 week
  allow_failure: true
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    - if: '$CI_COMMIT_BRANCH == "main"'

validate:terraform:checkov:
  stage: validate
  image: bridgecrew/checkov:latest
  script:
    - checkov --directory ${TF_ROOT} --output json --output-file-path . --framework terraform
    - checkov --directory ${TF_ROOT} --framework terraform
  artifacts:
    reports:
      sast: results_json.json
    expire_in: 1 week
  allow_failure: true
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    - if: '$CI_COMMIT_BRANCH == "main"'

validate:ansible:lint:
  stage: validate
  extends: .ansible_base
  script:
    - ansible-lint ansible/playbooks/*.yml
    - ansible-lint ansible/roles/*/tasks/*.yml
  allow_failure: true
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    - if: '$CI_COMMIT_BRANCH == "main"'

validate:scripts:shellcheck:
  stage: validate
  image: koalaman/shellcheck-alpine:latest
  script:
    - find scripts/ -type f -name "*.sh" -exec shellcheck {} +
    - find . -maxdepth 1 -type f -name "*.sh" -exec shellcheck {} +
  allow_failure: true
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    - if: '$CI_COMMIT_BRANCH == "main"'

# ==============================================================================
# STAGE: TEST
# ==============================================================================

test:terraform:validate:
  stage: test
  extends:
    - .terraform_base
    - .azure_auth
  script:
    - terraform validate
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    - if: '$CI_COMMIT_BRANCH == "main"'

test:unit:terratest:
  stage: test
  image: golang:1.21
  before_script:
    - cd tests/terraform
    - go mod download
  script:
    - go test -v -timeout 30m
  allow_failure: true
  only:
    - merge_requests
    - main
  when: manual

test:ansible:syntax:
  stage: test
  extends: .ansible_base
  script:
    - ansible-playbook ansible/playbooks/01-configure-strongswan.yml --syntax-check
    - ansible-playbook ansible/playbooks/02-configure-fortigates.yml --syntax-check
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    - if: '$CI_COMMIT_BRANCH == "main"'

test:documentation:links:
  stage: test
  image: node:18-alpine
  before_script:
    - npm install -g markdown-link-check
  script:
    - find Documentation/ -name "*.md" -exec markdown-link-check {} \;
    - markdown-link-check README.md
  allow_failure: true
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    - if: '$CI_COMMIT_BRANCH == "main"'

# ==============================================================================
# STAGE: PLAN
# ==============================================================================

plan:dev:
  stage: plan
  extends:
    - .terraform_base
    - .azure_auth
  environment:
    name: dev
    action: prepare
  script:
    - terraform plan -out=tfplan -var-file=environments/dev.tfvars
    - terraform show -json tfplan > tfplan.json
  artifacts:
    paths:
      - ${TF_ROOT}/tfplan
      - ${TF_ROOT}/tfplan.json
    reports:
      terraform: ${TF_ROOT}/tfplan.json
    expire_in: 1 week
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    - if: '$CI_COMMIT_BRANCH =~ /^claude\/.*/'

plan:staging:
  stage: plan
  extends:
    - .terraform_base
    - .azure_auth
  environment:
    name: staging
    action: prepare
  script:
    - terraform plan -out=tfplan -var-file=environments/staging.tfvars
    - terraform show -json tfplan > tfplan.json
  artifacts:
    paths:
      - ${TF_ROOT}/tfplan
      - ${TF_ROOT}/tfplan.json
    expire_in: 1 week
  rules:
    - if: '$CI_COMMIT_BRANCH == "staging"'
  when: manual

plan:prod:
  stage: plan
  extends:
    - .terraform_base
    - .azure_auth
  environment:
    name: production
    action: prepare
  script:
    - terraform plan -out=tfplan -var-file=environments/prod.tfvars
    - terraform show -json tfplan > tfplan.json
  artifacts:
    paths:
      - ${TF_ROOT}/tfplan
      - ${TF_ROOT}/tfplan.json
    expire_in: 1 week
  rules:
    - if: '$CI_COMMIT_BRANCH == "production"'
  when: manual

# ==============================================================================
# STAGE: DEPLOY
# ==============================================================================

deploy:dev:terraform:
  stage: deploy
  extends:
    - .terraform_base
    - .azure_auth
  environment:
    name: dev
    url: https://portal.azure.com
    on_stop: destroy:dev
  dependencies:
    - plan:dev
  script:
    - terraform apply -auto-approve tfplan
    - terraform output -json > terraform-outputs.json
  artifacts:
    paths:
      - ${TF_ROOT}/terraform-outputs.json
    expire_in: 1 month
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
      when: manual
    - if: '$CI_COMMIT_BRANCH =~ /^claude\/.*/'
      when: manual

deploy:dev:ansible:
  stage: deploy
  extends: .ansible_base
  environment:
    name: dev
  dependencies:
    - deploy:dev:terraform
  before_script:
    - cd ansible
    - ansible --version
  script:
    - |
      # Attendre que les VMs soient prêtes
      sleep 60

      # Déployer StrongSwan si activé
      if [ -f "inventories/dev/strongswan.ini" ]; then
        ansible-playbook -i inventories/dev/strongswan.ini playbooks/01-configure-strongswan.yml
      fi

      # Déployer FortiGates si activés
      if [ -f "inventories/dev/fortigates.ini" ]; then
        ansible-playbook -i inventories/dev/fortigates.ini playbooks/02-configure-fortigates.yml
      fi
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
      when: manual
  needs:
    - deploy:dev:terraform

deploy:staging:
  stage: deploy
  extends:
    - .terraform_base
    - .azure_auth
  environment:
    name: staging
    url: https://portal.azure.com
    on_stop: destroy:staging
  dependencies:
    - plan:staging
  script:
    - terraform apply -auto-approve tfplan
  rules:
    - if: '$CI_COMMIT_BRANCH == "staging"'
      when: manual

deploy:prod:
  stage: deploy
  extends:
    - .terraform_base
    - .azure_auth
  environment:
    name: production
    url: https://portal.azure.com
    on_stop: destroy:prod
  dependencies:
    - plan:prod
  script:
    - terraform apply -auto-approve tfplan
  rules:
    - if: '$CI_COMMIT_BRANCH == "production"'
      when: manual
  only:
    - production

# ==============================================================================
# STAGE: VERIFY
# ==============================================================================

verify:connectivity:
  stage: verify
  image: mcr.microsoft.com/azure-cli:latest
  environment:
    name: dev
  dependencies:
    - deploy:dev:terraform
  before_script:
    - az login --service-principal -u ${AZURE_CLIENT_ID} -p ${AZURE_CLIENT_SECRET} --tenant ${AZURE_TENANT_ID}
    - az account set --subscription ${AZURE_SUBSCRIPTION_ID}
  script:
    - |
      echo "Vérification du statut des tunnels VPN..."

      # Récupérer le resource group
      RG=$(cat ${TF_ROOT}/terraform-outputs.json | jq -r '.deployment_summary.value.resource_group_name')

      # Vérifier les connexions VPN
      az network vpn-connection list --resource-group ${RG} --output table

      # Vérifier le statut de chaque connexion
      for conn in $(az network vpn-connection list --resource-group ${RG} --query "[].name" -o tsv); do
        STATUS=$(az network vpn-connection show --name ${conn} --resource-group ${RG} --query connectionStatus -o tsv)
        echo "Connexion ${conn}: ${STATUS}"

        if [ "${STATUS}" != "Connected" ]; then
          echo "⚠️  ATTENTION: Connexion ${conn} n'est pas connectée"
          exit 1
        fi
      done

      echo "✅ Tous les tunnels sont connectés"
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
      when: on_success
  needs:
    - deploy:dev:ansible

verify:bgp:routes:
  stage: verify
  image: mcr.microsoft.com/azure-cli:latest
  environment:
    name: dev
  dependencies:
    - deploy:dev:terraform
  before_script:
    - az login --service-principal -u ${AZURE_CLIENT_ID} -p ${AZURE_CLIENT_SECRET} --tenant ${AZURE_TENANT_ID}
    - az account set --subscription ${AZURE_SUBSCRIPTION_ID}
  script:
    - |
      echo "Vérification des routes BGP apprises..."

      RG=$(cat ${TF_ROOT}/terraform-outputs.json | jq -r '.deployment_summary.value.resource_group_name')
      VPN_GW=$(cat ${TF_ROOT}/terraform-outputs.json | jq -r '.azure_vpn_gateway_name.value')

      # Lister les routes BGP
      az network vnet-gateway list-learned-routes \
        --name ${VPN_GW} \
        --resource-group ${RG} \
        --output table
  allow_failure: true
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
      when: on_success
  needs:
    - deploy:dev:ansible

verify:security:scan:
  stage: verify
  image: aquasec/trivy:latest
  script:
    - trivy config ${TF_ROOT} --severity HIGH,CRITICAL --exit-code 1
  allow_failure: true
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
      when: always

# ==============================================================================
# STAGE: DESTROY (Manuel uniquement)
# ==============================================================================

destroy:dev:
  stage: destroy
  extends:
    - .terraform_base
    - .azure_auth
  environment:
    name: dev
    action: stop
  script:
    - terraform destroy -auto-approve -var-file=environments/dev.tfvars
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
      when: manual
    - if: '$CI_COMMIT_BRANCH =~ /^claude\/.*/'
      when: manual

destroy:staging:
  stage: destroy
  extends:
    - .terraform_base
    - .azure_auth
  environment:
    name: staging
    action: stop
  script:
    - terraform destroy -auto-approve -var-file=environments/staging.tfvars
  rules:
    - if: '$CI_COMMIT_BRANCH == "staging"'
      when: manual

destroy:prod:
  stage: destroy
  extends:
    - .terraform_base
    - .azure_auth
  environment:
    name: production
    action: stop
  script:
    - echo "⚠️  DESTRUCTION DE LA PRODUCTION"
    - echo "Cette action nécessite une double validation"
    - terraform destroy -auto-approve -var-file=environments/prod.tfvars
  rules:
    - if: '$CI_COMMIT_BRANCH == "production"'
      when: manual
  only:
    - production

# ==============================================================================
# Jobs planifiés (Scheduled Pipelines)
# ==============================================================================

scheduled:drift:detection:
  stage: plan
  extends:
    - .terraform_base
    - .azure_auth
  script:
    - terraform plan -detailed-exitcode
  rules:
    - if: '$CI_PIPELINE_SOURCE == "schedule"'
  allow_failure: true

scheduled:cost:report:
  stage: verify
  image: infracost/infracost:latest
  script:
    - infracost breakdown --path ${TF_ROOT} --format table
    - infracost breakdown --path ${TF_ROOT} --format json --out-file infracost-report.json
  artifacts:
    paths:
      - infracost-report.json
    expire_in: 1 month
  rules:
    - if: '$CI_PIPELINE_SOURCE == "schedule"'
```

### Fichiers de configuration additionnels

#### `terraform/environments/dev.tfvars`

```hcl
# Configuration pour l'environnement DEV
environment  = "dev"
project_name = "pra"
owner        = "team-devops@company.com"

# Azure
azure_location = "francecentral"
vpn_gateway_sku = "VpnGw1"

# StrongSwan (actif en dev)
deploy_strongswan = true
strongswan_vm_size = "Standard_B1s"

# OVH (désactivé en dev pour réduire coûts)
deploy_ovh_rbx = false
deploy_ovh_sbg = false

# SSH (restreint en dev)
ssh_source_address_prefix = "10.0.0.0/8"  # Réseau entreprise
```

#### `terraform/environments/staging.tfvars`

```hcl
# Configuration pour l'environnement STAGING
environment  = "staging"
project_name = "pra"
owner        = "team-devops@company.com"

# Azure
azure_location = "francecentral"
vpn_gateway_sku = "VpnGw1"

# StrongSwan
deploy_strongswan = true
strongswan_vm_size = "Standard_B1s"

# OVH (activé pour tests réalistes)
deploy_ovh_rbx = true
deploy_ovh_sbg = true

# SSH
ssh_source_address_prefix = "10.0.0.0/8"
```

#### `terraform/environments/prod.tfvars`

```hcl
# Configuration pour l'environnement PRODUCTION
environment  = "prod"
project_name = "pra"
owner        = "team-devops@company.com"

# Azure (SKU supérieur en prod)
azure_location = "francecentral"
vpn_gateway_sku = "VpnGw2"  # 1 Gbps

# StrongSwan (désactivé en prod)
deploy_strongswan = false

# OVH (activé en prod)
deploy_ovh_rbx = true
deploy_ovh_sbg = true

# SSH (très restreint)
ssh_source_address_prefix = "203.0.113.0/24"  # IP bastion uniquement
```

### Variables GitLab CI/CD à configurer

Dans **Settings → CI/CD → Variables** :

| Variable | Type | Protected | Masked | Value |
|----------|------|-----------|--------|-------|
| `AZURE_CLIENT_ID` | Variable | ✅ | ✅ | `xxx-xxx-xxx` |
| `AZURE_CLIENT_SECRET` | Variable | ✅ | ✅ | `xxx` |
| `AZURE_SUBSCRIPTION_ID` | Variable | ✅ | ❌ | `xxx-xxx-xxx` |
| `AZURE_TENANT_ID` | Variable | ✅ | ❌ | `xxx-xxx-xxx` |
| `IPSEC_PSK_STRONGSWAN` | File | ✅ | ✅ | `xxx` |
| `IPSEC_PSK_RBX` | File | ✅ | ✅ | `xxx` |
| `IPSEC_PSK_SBG` | File | ✅ | ✅ | `xxx` |

### Scheduled Pipelines à configurer

Dans **CI/CD → Schedules** :

1. **Drift Detection Quotidien**
   - Description : "Détection de drift Terraform"
   - Interval : Tous les jours à 8h00
   - Cron : `0 8 * * *`
   - Branch : `main`
   - Variables : Aucune

2. **Cost Report Hebdomadaire**
   - Description : "Rapport de coûts Infracost"
   - Interval : Tous les lundis à 9h00
   - Cron : `0 9 * * 1`
   - Branch : `main`
   - Variables : Aucune

3. **Security Scan Hebdomadaire**
   - Description : "Scan de sécurité complet"
   - Interval : Tous les vendredis à 18h00
   - Cron : `0 18 * * 5`
   - Branch : `main`
   - Variables : `FULL_SCAN=true`

---

## Améliorations Infrastructure

### 1. Azure Key Vault Integration

**Objectif :** Stocker tous les secrets de manière sécurisée

**Implémentation :**

```hcl
# modules/00-azure-key-vault/main.tf
resource "azurerm_key_vault" "main" {
  name                = "kv-${var.environment}-${var.project_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Soft delete activé (requis Azure)
  soft_delete_retention_days = 90
  purge_protection_enabled   = true

  # Network ACLs
  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    ip_rules                   = var.allowed_ips
    virtual_network_subnet_ids = var.allowed_subnets
  }

  # Audit logs
  enable_rbac_authorization = true
}

# Secrets
resource "azurerm_key_vault_secret" "ipsec_psk_strongswan" {
  name         = "ipsec-psk-strongswan"
  value        = var.ipsec_psk_strongswan
  key_vault_id = azurerm_key_vault.main.id

  # Rotation automatique tous les 90 jours
  expiration_date = timeadd(timestamp(), "2160h") # 90 jours
}

# Accès pour Terraform
resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
  ]
}

# Accès pour VMs avec managed identity
resource "azurerm_key_vault_access_policy" "vms" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = var.vm_identity_principal_id

  secret_permissions = [
    "Get",
    "List",
  ]
}
```

**Utilisation dans Terraform :**

```hcl
# Récupérer le secret depuis Key Vault
data "azurerm_key_vault_secret" "ipsec_psk" {
  name         = "ipsec-psk-strongswan"
  key_vault_id = data.azurerm_key_vault.main.id
}

# Utiliser dans le module
module "tunnel_ipsec_static" {
  source = "./modules/03-tunnel-ipsec-static"

  ipsec_psk = data.azurerm_key_vault_secret.ipsec_psk.value
  # ...
}
```

**Bénéfices :**
- ✅ Secrets jamais en clair dans le code
- ✅ Rotation automatique
- ✅ Audit trail complet
- ✅ Accès granulaire avec RBAC

**Effort :** 1-2 jours
**Priorité :** 🔴 Critique

---

### 2. Azure Bastion

**Objectif :** Accès SSH sécurisé sans exposer les VMs

**Implémentation :**

```hcl
# modules/07-azure-bastion/main.tf
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"  # Nom obligatoire
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.vnet_name
  address_prefixes     = [var.bastion_subnet_cidr]
}

resource "azurerm_public_ip" "bastion" {
  name                = "pip-${var.environment}-bastion"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "main" {
  name                = "bastion-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }

  # Features
  copy_paste_enabled     = true
  file_copy_enabled      = true
  shareable_link_enabled = false
  tunneling_enabled      = true
  sku                    = "Standard"
}
```

**Utilisation :**

```bash
# Connexion via Azure CLI
az network bastion ssh \
  --name bastion-dev \
  --resource-group rg-dev-pra-vpn \
  --target-resource-id /subscriptions/.../vm-dev-pra-strongswan \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa
```

**Modifier les NSG :**

```hcl
# Supprimer la règle SSH publique
# security_rule {
#   name = "Allow-SSH"
#   ...
# }

# Ajouter règle pour Bastion uniquement
security_rule {
  name                       = "Allow-SSH-from-Bastion"
  priority                   = 130
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "22"
  source_address_prefix      = var.bastion_subnet_cidr
  destination_address_prefix = "*"
}
```

**Bénéfices :**
- ✅ Aucune exposition SSH publique
- ✅ Logs centralisés des connexions
- ✅ MFA supporté
- ✅ Session recording

**Coûts :** ~40€/mois
**Effort :** 1 jour
**Priorité :** 🟡 Moyen

---

### 3. Azure Monitor + Log Analytics

**Objectif :** Monitoring et alerting complets

**Implémentation :**

```hcl
# modules/08-monitoring/main.tf
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${var.environment}-${var.project_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 90

  daily_quota_gb = 1  # Limite pour contrôler les coûts
}

# Diagnostics pour VPN Gateway
resource "azurerm_monitor_diagnostic_setting" "vpn_gateway" {
  name                       = "vpn-gateway-diagnostics"
  target_resource_id         = var.vpn_gateway_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  # Tous les logs
  enabled_log {
    category = "GatewayDiagnosticLog"
  }
  enabled_log {
    category = "TunnelDiagnosticLog"
  }
  enabled_log {
    category = "RouteDiagnosticLog"
  }
  enabled_log {
    category = "IKEDiagnosticLog"
  }

  # Métriques
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Alerte : Tunnel VPN Down
resource "azurerm_monitor_metric_alert" "tunnel_down" {
  name                = "alert-tunnel-down"
  resource_group_name = var.resource_group_name
  scopes              = [var.vpn_gateway_id]
  description         = "Alerte si un tunnel VPN tombe"
  severity            = 0  # Critical

  criteria {
    metric_namespace = "Microsoft.Network/vpnGateways"
    metric_name      = "TunnelIngressBytes"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1
  }

  window_size        = "PT5M"
  frequency          = "PT1M"
  auto_mitigate      = true

  action {
    action_group_id = azurerm_monitor_action_group.critical.id
  }
}

# Alerte : BGP Peer Down
resource "azurerm_monitor_metric_alert" "bgp_peer_down" {
  name                = "alert-bgp-peer-down"
  resource_group_name = var.resource_group_name
  scopes              = [var.vpn_gateway_id]
  description         = "Alerte si un peer BGP tombe"
  severity            = 1  # Error

  criteria {
    metric_namespace = "Microsoft.Network/vpnGateways"
    metric_name      = "BgpPeerStatus"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1
  }

  window_size   = "PT5M"
  frequency     = "PT1M"
  auto_mitigate = true

  action {
    action_group_id = azurerm_monitor_action_group.critical.id
  }
}

# Action Group pour notifications
resource "azurerm_monitor_action_group" "critical" {
  name                = "ag-critical-${var.environment}"
  resource_group_name = var.resource_group_name
  short_name          = "critical"

  # Email
  email_receiver {
    name          = "DevOps Team"
    email_address = "devops@company.com"
  }

  # SMS
  sms_receiver {
    name         = "On-Call"
    country_code = "33"
    phone_number = "612345678"
  }

  # Webhook (Slack, Teams, PagerDuty)
  webhook_receiver {
    name        = "Slack"
    service_uri = var.slack_webhook_url
  }
}

# Dashboard personnalisé
resource "azurerm_portal_dashboard" "vpn" {
  name                = "dashboard-vpn-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location

  dashboard_properties = templatefile("${path.module}/templates/dashboard.json", {
    vpn_gateway_id = var.vpn_gateway_id
    workspace_id   = azurerm_log_analytics_workspace.main.id
  })
}
```

**Queries Log Analytics utiles :**

```kusto
// Tunnels DOWN dans les dernières 24h
AzureDiagnostics
| where ResourceType == "VPNGATEWAYS"
| where Category == "TunnelDiagnosticLog"
| where status_s == "Disconnected"
| where TimeGenerated > ago(24h)
| summarize Count = count() by remoteIP_s, bin(TimeGenerated, 1h)
| render timechart

// Trafic par tunnel
AzureDiagnostics
| where ResourceType == "VPNGATEWAYS"
| where Category == "GatewayDiagnosticLog"
| summarize IngressMB = sum(ingressBytes_d)/1024/1024,
            EgressMB = sum(egressBytes_d)/1024/1024
  by remoteIP_s, bin(TimeGenerated, 5m)
| render timechart

// Erreurs IKE
AzureDiagnostics
| where ResourceType == "VPNGATEWAYS"
| where Category == "IKEDiagnosticLog"
| where Level == "Error"
| project TimeGenerated, remoteIP_s, Message
| order by TimeGenerated desc
```

**Bénéfices :**
- ✅ Visibilité complète sur les tunnels
- ✅ Alertes en temps réel
- ✅ Historique 90 jours
- ✅ Dashboards personnalisés

**Coûts :** ~10-20€/mois (1 GB/jour)
**Effort :** 2-3 jours
**Priorité :** 🔴 Critique

---

### 4. Backup et Disaster Recovery

**Objectif :** Capacité à restaurer rapidement l'infrastructure

**Implémentation :**

```bash
# scripts/backup/backup-terraform-state.sh
#!/bin/bash
# ==============================================================================
# Backup du state Terraform
# ==============================================================================

set -e

BACKUP_DIR="/backups/terraform"
DATE=$(date +%Y%m%d-%H%M%S)
ENVIRONMENT=${1:-dev}

echo "Backup du state Terraform pour ${ENVIRONMENT}..."

# Créer le répertoire de backup
mkdir -p ${BACKUP_DIR}/${ENVIRONMENT}

# Backup du state
cd terraform
terraform state pull > ${BACKUP_DIR}/${ENVIRONMENT}/terraform-${DATE}.tfstate

# Backup des fichiers tfvars
cp environments/${ENVIRONMENT}.tfvars ${BACKUP_DIR}/${ENVIRONMENT}/tfvars-${DATE}.tfvars

# Chiffrer les backups
gpg --symmetric --cipher-algo AES256 \
  ${BACKUP_DIR}/${ENVIRONMENT}/terraform-${DATE}.tfstate

gpg --symmetric --cipher-algo AES256 \
  ${BACKUP_DIR}/${ENVIRONMENT}/tfvars-${DATE}.tfvars

# Supprimer les versions non chiffrées
rm ${BACKUP_DIR}/${ENVIRONMENT}/terraform-${DATE}.tfstate
rm ${BACKUP_DIR}/${ENVIRONMENT}/tfvars-${DATE}.tfvars

# Upload vers Azure Blob Storage
az storage blob upload-batch \
  --account-name <storage-account> \
  --destination backups \
  --source ${BACKUP_DIR}/${ENVIRONMENT} \
  --pattern "*.gpg"

# Rétention : garder 30 derniers jours
find ${BACKUP_DIR}/${ENVIRONMENT} -name "*.gpg" -mtime +30 -delete

echo "✅ Backup terminé : ${BACKUP_DIR}/${ENVIRONMENT}/terraform-${DATE}.tfstate.gpg"
```

```bash
# scripts/backup/restore-terraform-state.sh
#!/bin/bash
# ==============================================================================
# Restauration du state Terraform
# ==============================================================================

set -e

BACKUP_FILE=$1
ENVIRONMENT=${2:-dev}

if [ -z "$BACKUP_FILE" ]; then
  echo "Usage: $0 <backup-file> [environment]"
  exit 1
fi

echo "⚠️  ATTENTION : Restauration du state Terraform"
echo "Fichier : ${BACKUP_FILE}"
echo "Environment : ${ENVIRONMENT}"
read -p "Confirmer (oui/non) : " confirm

if [ "$confirm" != "oui" ]; then
  echo "Annulé"
  exit 0
fi

# Déchiffrer le backup
gpg --decrypt ${BACKUP_FILE} > /tmp/terraform-restore.tfstate

# Backup du state actuel (sécurité)
cd terraform
terraform state pull > /tmp/terraform-current-backup.tfstate

# Restaurer le state
terraform state push /tmp/terraform-restore.tfstate

# Vérifier la cohérence
terraform plan -var-file=environments/${ENVIRONMENT}.tfvars

echo "✅ State restauré"
echo "Backup du state actuel : /tmp/terraform-current-backup.tfstate"
```

**Automatisation avec GitLab CI :**

```yaml
# Ajout au .gitlab-ci.yml
scheduled:backup:state:
  stage: verify
  extends: .terraform_base
  script:
    - ./scripts/backup/backup-terraform-state.sh ${CI_ENVIRONMENT_NAME}
  rules:
    - if: '$CI_PIPELINE_SOURCE == "schedule"'
  only:
    variables:
      - $BACKUP_JOB == "true"
```

**Bénéfices :**
- ✅ Recovery en cas de corruption du state
- ✅ Backups chiffrés
- ✅ Rétention 30 jours
- ✅ Automatisé quotidiennement

**Effort :** 1 jour
**Priorité :** 🟡 Moyen

---

## Améliorations Sécurité

### 1. Azure Defender + Security Center

```hcl
# modules/09-security/main.tf
resource "azurerm_security_center_subscription_pricing" "main" {
  tier          = "Standard"
  resource_type = "VirtualMachines"
}

resource "azurerm_security_center_subscription_pricing" "keyvault" {
  tier          = "Standard"
  resource_type = "KeyVaults"
}

resource "azurerm_security_center_auto_provisioning" "main" {
  auto_provision = "On"
}

# Alertes de sécurité
resource "azurerm_security_center_contact" "main" {
  email = "security@company.com"
  phone = "+33612345678"

  alert_notifications = true
  alerts_to_admins    = true
}
```

**Coûts :** ~15€/VM/mois
**Priorité :** 🔴 Critique pour production

---

### 2. Rotation automatique des PSK

```bash
# scripts/security/rotate-psk.sh
#!/bin/bash
# ==============================================================================
# Rotation automatique des PSK (tous les 90 jours)
# ==============================================================================

set -e

echo "Rotation des Pre-Shared Keys..."

# Générer nouveaux PSK
NEW_PSK_STRONGSWAN=$(openssl rand -base64 32)
NEW_PSK_RBX=$(openssl rand -base64 32)
NEW_PSK_SBG=$(openssl rand -base64 32)

# Mettre à jour Azure Key Vault
az keyvault secret set \
  --vault-name kv-prod-pra \
  --name ipsec-psk-strongswan \
  --value "$NEW_PSK_STRONGSWAN"

az keyvault secret set \
  --vault-name kv-prod-pra \
  --name ipsec-psk-rbx \
  --value "$NEW_PSK_RBX"

az keyvault secret set \
  --vault-name kv-prod-pra \
  --name ipsec-psk-sbg \
  --value "$NEW_PSK_SBG"

# Re-déployer avec Terraform (récupère les nouveaux secrets)
cd terraform
terraform apply -auto-approve -target=module.tunnel_ipsec_static
terraform apply -auto-approve -target=module.tunnel_ipsec_bgp_rbx
terraform apply -auto-approve -target=module.tunnel_ipsec_bgp_sbg

# Re-configurer avec Ansible
cd ../ansible
ansible-playbook -i inventories/prod/strongswan.ini playbooks/01-configure-strongswan.yml
ansible-playbook -i inventories/prod/fortigates.ini playbooks/02-configure-fortigates.yml

echo "✅ PSK rotés avec succès"
```

**Automatisation :** Scheduled pipeline tous les 90 jours
**Priorité :** 🟡 Moyen

---

### 3. Scan de vulnérabilités automatique

```yaml
# Ajout au .gitlab-ci.yml
security:vulnerability:scan:
  stage: verify
  image: aquasec/trivy:latest
  script:
    # Scan des images Docker (si utilisées)
    - trivy image --severity HIGH,CRITICAL <image>

    # Scan des configurations IaC
    - trivy config --severity HIGH,CRITICAL terraform/

    # Scan des dépendances Ansible
    - trivy fs --severity HIGH,CRITICAL ansible/
  artifacts:
    reports:
      container_scanning: trivy-report.json
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    - if: '$CI_COMMIT_BRANCH == "main"'
```

**Priorité :** 🟡 Moyen

---

## Améliorations Monitoring

### 1. Grafana Dashboards

**Objectif :** Dashboards riches pour visualisation

**Stack :** Azure Monitor → Prometheus → Grafana

```yaml
# docker-compose.yml pour stack monitoring
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana:latest
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/dashboards:/etc/grafana/provisioning/dashboards
      - ./grafana/datasources:/etc/grafana/provisioning/datasources
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=<secure-password>

  azure-exporter:
    image: quay.io/prometheuscommunity/azure-metrics-exporter:latest
    environment:
      - AZURE_TENANT_ID=${AZURE_TENANT_ID}
      - AZURE_CLIENT_ID=${AZURE_CLIENT_ID}
      - AZURE_CLIENT_SECRET=${AZURE_CLIENT_SECRET}
      - AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}
    ports:
      - "9276:9276"

volumes:
  prometheus-data:
  grafana-data:
```

**Dashboards à créer :**
1. VPN Gateway Overview
2. Tunnel Status & Traffic
3. BGP Routes & Convergence
4. Security Events
5. Cost Tracking

**Effort :** 3-4 jours
**Priorité :** 🟢 Nice to have

---

### 2. Synthetic Monitoring

**Objectif :** Tests de connectivité en continu

```bash
# scripts/monitoring/synthetic-test.sh
#!/bin/bash
# ==============================================================================
# Tests synthétiques de connectivité (exécuté toutes les 5 minutes)
# ==============================================================================

AZURE_TEST_IP="10.1.1.10"
RBX_TEST_IP="192.168.10.10"
SBG_TEST_IP="192.168.20.10"

# Fonction de test avec retry
test_connectivity() {
  local target=$1
  local name=$2
  local retries=3

  for i in $(seq 1 $retries); do
    if ping -c 3 -W 2 $target > /dev/null 2>&1; then
      echo "✅ ${name} : OK"
      return 0
    fi
    sleep 2
  done

  echo "❌ ${name} : FAILED"
  # Envoyer alerte
  curl -X POST $SLACK_WEBHOOK \
    -H 'Content-Type: application/json' \
    -d "{\"text\":\"❌ Connectivity test failed: ${name}\"}"

  return 1
}

# Tests
test_connectivity $AZURE_TEST_IP "Azure"
test_connectivity $RBX_TEST_IP "OVH RBX"
test_connectivity $SBG_TEST_IP "OVH SBG"
```

**Automatisation :** Cron toutes les 5 minutes
**Priorité :** 🟡 Moyen

---

## Améliorations Code

### 1. Tests unitaires Terraform (Terratest)

```go
// tests/terraform/vpn_gateway_test.go
package test

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestVPNGateway(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../../terraform",
        VarFiles:     []string{"environments/test.tfvars"},
        NoColor:      true,
    })

    defer terraform.Destroy(t, terraformOptions)

    // Init et Apply
    terraform.InitAndApply(t, terraformOptions)

    // Tests
    vpnGatewayIP := terraform.Output(t, terraformOptions, "azure_vpn_gateway_public_ip")
    assert.NotEmpty(t, vpnGatewayIP, "VPN Gateway IP should not be empty")

    bgpEnabled := terraform.Output(t, terraformOptions, "azure_bgp_enabled")
    assert.Equal(t, "true", bgpEnabled, "BGP should be enabled")
}
```

**Effort :** 1-2 semaines
**Priorité :** 🟡 Moyen

---

### 2. Pre-commit hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.83.5
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_tflint
      - id: terraform_tfsec

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files

  - repo: https://github.com/ansible/ansible-lint
    rev: v6.22.0
    hooks:
      - id: ansible-lint
```

**Installation :**
```bash
pip install pre-commit
pre-commit install
```

**Priorité :** 🟢 Nice to have

---

## Tests automatisés

### Tests Infrastructure (InSpec)

```ruby
# tests/inspec/vpn_gateway_spec.rb
describe azure_virtual_network_gateway_connection(
  resource_group: 'rg-dev-pra-vpn',
  name: 'conn-dev-pra-s2s-onprem'
) do
  it { should exist }
  its('connection_status') { should eq 'Connected' }
  its('connection_type') { should eq 'IPsec' }
  its('enable_bgp') { should be true }
end

describe azure_virtual_network_gateway(
  resource_group: 'rg-dev-pra-vpn',
  name: 'vpngw-dev-pra'
) do
  it { should exist }
  its('gateway_type') { should eq 'Vpn' }
  its('vpn_type') { should eq 'RouteBased' }
  its('enable_bgp') { should be true }
  its('sku') { should eq 'VpnGw1' }
end
```

**Exécution :**
```bash
inspec exec tests/inspec/vpn_gateway_spec.rb -t azure://
```

---

## Documentation additionnelle

### À créer :

1. **05-OPERATIONS.md** (300+ lignes)
   - Runbook pour incidents
   - Procédures de maintenance
   - Escalation matrix
   - Contacts

2. **06-TROUBLESHOOTING.md** (400+ lignes)
   - Guide complet de dépannage
   - Arbres de décision
   - Commandes de diagnostic
   - FAQ

3. **07-ARCHITECTURE-DECISIONS.md** (ADR)
   - Décisions d'architecture documentées
   - Contexte et alternatives
   - Conséquences

4. **08-PLAYBOOKS.md** (250+ lignes)
   - Playbook : Tunnel VPN Down
   - Playbook : BGP Peer Down
   - Playbook : Performance Degradation
   - Playbook : Security Incident

**Effort total :** 3-4 jours
**Priorité :** 🟡 Moyen

---

## Optimisations de coûts

### 1. Azure Cost Management

```hcl
# Budgets et alertes
resource "azurerm_consumption_budget_resource_group" "main" {
  name              = "budget-${var.environment}"
  resource_group_id = azurerm_resource_group.vpn.id

  amount     = 150  # €150/mois
  time_grain = "Monthly"

  time_period {
    start_date = "2025-01-01T00:00:00Z"
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    contact_emails = ["finance@company.com"]
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    contact_emails = ["finance@company.com", "devops@company.com"]
  }
}
```

### 2. Optimisations

**Recommandations :**

1. **Auto-shutdown VMs non-prod**
   - StrongSwan en dev : arrêt 19h-8h
   - Économie : ~40% des coûts VM

2. **Reserved Instances pour VPN Gateway**
   - Commitment 1 an : -25%
   - Commitment 3 ans : -40%
   - Économie : 360€/an (VpnGw1)

3. **Spot Instances pour tests**
   - VMs de test éphémères
   - Économie : -70-90%

4. **Storage lifecycle**
   - Logs > 90 jours → Cool tier
   - Logs > 1 an → Archive tier
   - Économie : -50% storage

**Effort :** 2-3 jours
**ROI :** -30-40% coûts infra

---

## Conformité et Gouvernance

### 1. Azure Policy

```hcl
# Politique : Tags obligatoires
resource "azurerm_policy_definition" "required_tags" {
  name         = "required-tags"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Require specific tags on resources"

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Network/vpnGateways"
        },
        {
          anyOf = [
            {
              field  = "tags.Environment"
              exists = "false"
            },
            {
              field  = "tags.Owner"
              exists = "false"
            }
          ]
        }
      ]
    }
    then = {
      effect = "deny"
    }
  })
}

# Assignment
resource "azurerm_policy_assignment" "required_tags" {
  name                 = "required-tags-assignment"
  scope                = azurerm_resource_group.vpn.id
  policy_definition_id = azurerm_policy_definition.required_tags.id
}
```

### 2. Compliance Checks

```yaml
# .gitlab-ci.yml - Compliance
compliance:azure:policy:
  stage: verify
  image: mcr.microsoft.com/azure-cli:latest
  script:
    - az policy state list --resource-group rg-${CI_ENVIRONMENT_NAME}-pra-vpn
    - |
      NON_COMPLIANT=$(az policy state list --resource-group rg-${CI_ENVIRONMENT_NAME}-pra-vpn --query "[?complianceState=='NonCompliant'] | length(@)")
      if [ "$NON_COMPLIANT" -gt 0 ]; then
        echo "❌ $NON_COMPLIANT ressources non-conformes"
        exit 1
      fi
  rules:
    - if: '$CI_PIPELINE_SOURCE == "schedule"'
```

---

## Résumé et Priorités

### Matrice Effort/Impact

| Amélioration | Effort | Impact | Priorité | ROI |
|-------------|--------|--------|----------|-----|
| **Azure Key Vault** | 🟢 Faible | 🔴 Critique | 1 | Excellent |
| **CI/CD GitLab** | 🟡 Moyen | 🔴 Critique | 1 | Excellent |
| **Azure Monitor** | 🟡 Moyen | 🔴 Critique | 1 | Excellent |
| **Backup/DR** | 🟢 Faible | 🟡 Important | 2 | Bon |
| **Azure Bastion** | 🟢 Faible | 🟡 Important | 2 | Bon |
| **Tests automatisés** | 🔴 Élevé | 🟡 Important | 3 | Moyen |
| **Grafana** | 🟡 Moyen | 🟢 Nice to have | 4 | Moyen |
| **Multi-région** | 🔴 Élevé | 🟡 Important | 5 | Moyen |

### Roadmap recommandée (6 mois)

**Mois 1-2 : Production Ready**
- ✅ Azure Key Vault
- ✅ CI/CD GitLab complet
- ✅ Azure Monitor + Alerting
- ✅ Azure Bastion

**Mois 3-4 : Stabilisation**
- ✅ Backup/DR automatisé
- ✅ Tests automatisés
- ✅ Documentation Operations
- ✅ Optimisations coûts

**Mois 5-6 : Scalabilité**
- ✅ Grafana Dashboards
- ✅ Multi-région (si besoin)
- ✅ Compliance automatique
- ✅ Chaos Engineering

---

**Budget estimé total :** 15-25K€ (développement) + 200-300€/mois (infra)
**Équipe recommandée :** 1 DevOps + 1 SRE (50% temps)
**Durée :** 6 mois

---

**Version :** 1.0
**Dernière mise à jour :** 2025-01-16
**Auteurs :** Équipe POC PRA
