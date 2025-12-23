#!/bin/bash
###############################################################################
# SCRIPT DE CHARGEMENT DES VARIABLES D'ENVIRONNEMENT
###############################################################################
# Description: Charge les variables d'environnement depuis les fichiers .env
# Usage: source scripts/utils/load-env.sh [--env <environment>]
# Exemples:
#   source scripts/utils/load-env.sh
#   source scripts/utils/load-env.sh --env production
#   source scripts/utils/load-env.sh --with-protected
###############################################################################

set -euo pipefail

# Répertoire racine du projet
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables par défaut
LOAD_PROTECTED=false
TARGET_ENV="${ENVIRONMENT:-dev}"

###############################################################################
# FONCTIONS UTILITAIRES
###############################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[✗]${NC} $*" >&2
}

show_usage() {
    cat <<EOF
Usage: source $(basename "${BASH_SOURCE[0]}") [OPTIONS]

Options:
    --env <environment>     Spécifier l'environnement (dev, test, staging, prod)
    --with-protected        Charger également les variables du fichier .env-protected
    --from-vault <vault>    Charger les secrets depuis un vault (azure-keyvault, hashicorp-vault)
    --check                 Vérifier que toutes les variables requises sont définies
    --export-terraform      Exporter les variables pour Terraform (préfixe TF_VAR_)
    --help                  Afficher cette aide

Exemples:
    source $(basename "${BASH_SOURCE[0]}")
    source $(basename "${BASH_SOURCE[0]}") --env production --with-protected
    source $(basename "${BASH_SOURCE[0]}") --from-vault azure-keyvault
    source $(basename "${BASH_SOURCE[0]}") --export-terraform

Fichiers utilisés:
    .env                    Variables d'environnement courantes (créé depuis .env.dist)
    .env-protected          Variables sensibles (créé depuis .env-protected.dist)

IMPORTANT:
    - Ce script doit être sourcé (source ou .) et non exécuté directement
    - Les fichiers .env et .env-protected ne doivent JAMAIS être committés
    - En production, utiliser un gestionnaire de secrets (--from-vault)

EOF
}

###############################################################################
# FONCTION: Charger un fichier .env
###############################################################################

load_env_file() {
    local env_file="$1"
    local file_type="${2:-standard}"

    if [[ ! -f "${env_file}" ]]; then
        if [[ "${file_type}" == "protected" ]]; then
            log_warning "Fichier protégé non trouvé: ${env_file}"
            log_warning "Créez-le depuis le template: cp .env-protected.dist .env-protected"
        else
            log_error "Fichier introuvable: ${env_file}"
            log_info "Créez-le depuis le template: cp .env.dist .env"
            return 1
        fi
        return 1
    fi

    log_info "Chargement de ${env_file}..."

    # Compter le nombre de variables chargées
    local count=0

    # Lire le fichier ligne par ligne
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Ignorer les commentaires et lignes vides
        if [[ -z "$line" ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi

        # Exporter la variable
        if [[ "$line" =~ ^[A-Z_][A-Z0-9_]*= ]]; then
            export "$line"
            ((count++))
        fi
    done < "${env_file}"

    log_success "Chargé ${count} variables depuis ${env_file}"
    return 0
}

###############################################################################
# FONCTION: Charger depuis Azure Key Vault
###############################################################################

load_from_azure_keyvault() {
    local vault_name="$1"

    log_info "Chargement des secrets depuis Azure Key Vault: ${vault_name}"

    # Vérifier que Azure CLI est installé
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI non installé"
        return 1
    fi

    # Vérifier la connexion Azure
    if ! az account show &> /dev/null; then
        log_error "Non connecté à Azure. Exécutez: az login"
        return 1
    fi

    # Liste des secrets à charger
    local secrets=(
        "ARM-SUBSCRIPTION-ID:ARM_SUBSCRIPTION_ID"
        "ARM-CLIENT-ID:ARM_CLIENT_ID"
        "ARM-CLIENT-SECRET:ARM_CLIENT_SECRET"
        "ARM-TENANT-ID:ARM_TENANT_ID"
        "IPSEC-PSK-STRONGSWAN:IPSEC_PSK_STRONGSWAN"
        "IPSEC-PSK-RBX:IPSEC_PSK_RBX"
        "IPSEC-PSK-SBG:IPSEC_PSK_SBG"
        "VCENTER-RBX-PASSWORD:VCENTER_RBX_PASSWORD"
        "VCENTER-SBG-PASSWORD:VCENTER_SBG_PASSWORD"
        "ZERTO-API-TOKEN:ZERTO_API_TOKEN"
        "RBX-FORTIGATE-API-KEY:RBX_FORTIGATE_API_KEY"
        "SBG-FORTIGATE-API-KEY:SBG_FORTIGATE_API_KEY"
        "VEEAM-API-TOKEN:VEEAM_API_TOKEN"
    )

    local count=0
    for secret_mapping in "${secrets[@]}"; do
        local vault_secret_name="${secret_mapping%%:*}"
        local env_var_name="${secret_mapping##*:}"

        local secret_value
        if secret_value=$(az keyvault secret show --vault-name "${vault_name}" --name "${vault_secret_name}" --query value -o tsv 2>/dev/null); then
            export "${env_var_name}=${secret_value}"
            ((count++))
            log_success "Chargé: ${env_var_name}"
        else
            log_warning "Secret introuvable: ${vault_secret_name} (${env_var_name})"
        fi
    done

    log_success "Chargé ${count} secrets depuis Azure Key Vault"
    return 0
}

###############################################################################
# FONCTION: Exporter pour Terraform
###############################################################################

export_for_terraform() {
    log_info "Export des variables pour Terraform (préfixe TF_VAR_)..."

    # Mapping des variables d'environnement vers Terraform
    local terraform_vars=(
        "IPSEC_PSK_STRONGSWAN:ipsec_psk_strongswan"
        "IPSEC_PSK_RBX:ipsec_psk_rbx"
        "IPSEC_PSK_SBG:ipsec_psk_sbg"
        "VCENTER_RBX_PASSWORD:vcenter_rbx_password"
        "VCENTER_SBG_PASSWORD:vcenter_sbg_password"
        "SSH_PUBLIC_KEY:ssh_public_key"
    )

    local count=0
    for var_mapping in "${terraform_vars[@]}"; do
        local env_var="${var_mapping%%:*}"
        local tf_var="${var_mapping##*:}"

        if [[ -n "${!env_var:-}" ]]; then
            export "TF_VAR_${tf_var}=${!env_var}"
            ((count++))
        fi
    done

    log_success "Exporté ${count} variables pour Terraform"
}

###############################################################################
# FONCTION: Vérifier les variables requises
###############################################################################

check_required_variables() {
    log_info "Vérification des variables requises..."

    local missing=()

    # Variables Azure requises
    local azure_vars=(
        "ARM_SUBSCRIPTION_ID"
        "ARM_CLIENT_ID"
        "ARM_CLIENT_SECRET"
        "ARM_TENANT_ID"
    )

    for var in "${azure_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing+=("${var}")
        fi
    done

    # Variables IPsec requises (selon déploiement)
    if [[ "${DEPLOY_STRONGSWAN:-true}" == "true" ]]; then
        if [[ -z "${IPSEC_PSK_STRONGSWAN:-}" ]]; then
            missing+=("IPSEC_PSK_STRONGSWAN")
        fi
    fi

    if [[ "${DEPLOY_OVH_RBX:-false}" == "true" ]]; then
        if [[ -z "${IPSEC_PSK_RBX:-}" ]]; then
            missing+=("IPSEC_PSK_RBX")
        fi
    fi

    if [[ "${DEPLOY_OVH_SBG:-false}" == "true" ]]; then
        if [[ -z "${IPSEC_PSK_SBG:-}" ]]; then
            missing+=("IPSEC_PSK_SBG")
        fi
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Variables manquantes:"
        for var in "${missing[@]}"; do
            echo "  - ${var}" >&2
        done
        return 1
    else
        log_success "Toutes les variables requises sont définies"
        return 0
    fi
}

###############################################################################
# PARSING DES ARGUMENTS
###############################################################################

EXPORT_TERRAFORM=false
CHECK_VARS=false
FROM_VAULT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --env)
            TARGET_ENV="$2"
            shift 2
            ;;
        --with-protected)
            LOAD_PROTECTED=true
            shift
            ;;
        --from-vault)
            FROM_VAULT="$2"
            shift 2
            ;;
        --export-terraform)
            EXPORT_TERRAFORM=true
            shift
            ;;
        --check)
            CHECK_VARS=true
            shift
            ;;
        --help|-h)
            show_usage
            return 0
            ;;
        *)
            log_error "Option inconnue: $1"
            show_usage
            return 1
            ;;
    esac
done

###############################################################################
# MAIN
###############################################################################

main() {
    log_info "Chargement des variables d'environnement pour: ${TARGET_ENV}"

    cd "${PROJECT_ROOT}"

    # Charger le fichier .env principal
    if load_env_file "${PROJECT_ROOT}/.env"; then
        :
    else
        log_error "Impossible de charger le fichier .env"
        log_info "Créez-le depuis le template: cp .env.dist .env"
        return 1
    fi

    # Charger le fichier .env-protected si demandé
    if [[ "${LOAD_PROTECTED}" == "true" ]]; then
        load_env_file "${PROJECT_ROOT}/.env-protected" "protected" || true
    fi

    # Charger depuis un vault si spécifié
    if [[ -n "${FROM_VAULT}" ]]; then
        case "${FROM_VAULT}" in
            azure-keyvault)
                local vault_name="${AZURE_KEYVAULT_NAME:-poc-pra-vault}"
                load_from_azure_keyvault "${vault_name}"
                ;;
            hashicorp-vault)
                log_error "HashiCorp Vault non encore implémenté"
                return 1
                ;;
            *)
                log_error "Vault inconnu: ${FROM_VAULT}"
                return 1
                ;;
        esac
    fi

    # Exporter pour Terraform si demandé
    if [[ "${EXPORT_TERRAFORM}" == "true" ]]; then
        export_for_terraform
    fi

    # Vérifier les variables requises si demandé
    if [[ "${CHECK_VARS}" == "true" ]]; then
        check_required_variables
    fi

    log_success "Variables d'environnement chargées avec succès!"
    log_info "Environnement: ${TARGET_ENV}"

    return 0
}

# Exécuter uniquement si sourcé
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_error "Ce script doit être sourcé, pas exécuté directement"
    log_info "Utilisez: source ${BASH_SOURCE[0]}"
    exit 1
fi

main "$@"
