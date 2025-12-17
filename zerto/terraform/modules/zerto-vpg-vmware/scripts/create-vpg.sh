#!/bin/bash
###############################################################################
# SCRIPT DE CRÉATION VPG ZERTO
###############################################################################
# Description: Crée un Virtual Protection Group via l'API Zerto
# Usage: Appelé automatiquement par Terraform
###############################################################################

set -euo pipefail

# Variables d'environnement requises (fournies par Terraform)
: "${VPG_NAME:?Variable VPG_NAME requise}"
: "${SOURCE_SITE_ID:?Variable SOURCE_SITE_ID requise}"
: "${TARGET_SITE_ID:?Variable TARGET_SITE_ID requise}"

# Variables optionnelles avec valeurs par défaut
VPG_DESCRIPTION="${VPG_DESCRIPTION:-VPG créé via Terraform}"
RPO_SECONDS="${RPO_SECONDS:-300}"
JOURNAL_HOURS="${JOURNAL_HOURS:-24}"
PRIORITY="${PRIORITY:-High}"
ENABLE_COMPRESSION="${ENABLE_COMPRESSION:-true}"
ENABLE_ENCRYPTION="${ENABLE_ENCRYPTION:-true}"
WAN_ACCELERATION="${WAN_ACCELERATION:-true}"

# Configuration API Zerto
ZERTO_API_ENDPOINT="${ZERTO_API_ENDPOINT:-https://zerto-api.ovh.net}"
ZERTO_API_TOKEN="${ZERTO_API_TOKEN:-}"

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction de logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

###############################################################################
# FONCTION: Obtenir le token API Zerto
###############################################################################
get_zerto_token() {
    log "Obtention du token API Zerto..."

    # Si un token est déjà fourni, l'utiliser
    if [[ -n "${ZERTO_API_TOKEN}" ]]; then
        log "Utilisation du token API fourni"
        echo "${ZERTO_API_TOKEN}"
        return 0
    fi

    # Sinon, authentification via credentials
    if [[ -z "${ZERTO_USERNAME:-}" ]] || [[ -z "${ZERTO_PASSWORD:-}" ]]; then
        error "ZERTO_API_TOKEN ou ZERTO_USERNAME/ZERTO_PASSWORD requis"
        return 1
    fi

    local response
    response=$(curl -s -X POST "${ZERTO_API_ENDPOINT}/v1/session/add" \
        -H "Content-Type: application/json" \
        -d "{\"AuthenticationMethod\": 1}" \
        --user "${ZERTO_USERNAME}:${ZERTO_PASSWORD}")

    if [[ $? -eq 0 ]]; then
        echo "${response}"
    else
        error "Échec de l'authentification Zerto"
        return 1
    fi
}

###############################################################################
# FONCTION: Vérifier si le VPG existe déjà
###############################################################################
check_vpg_exists() {
    local token=$1
    local vpg_name=$2

    log "Vérification de l'existence du VPG: ${vpg_name}"

    local response
    response=$(curl -s -X GET "${ZERTO_API_ENDPOINT}/v1/vpgs" \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json")

    if echo "${response}" | jq -e ".[] | select(.VpgName == \"${vpg_name}\")" > /dev/null 2>&1; then
        log "VPG ${vpg_name} existe déjà"
        return 0
    else
        log "VPG ${vpg_name} n'existe pas"
        return 1
    fi
}

###############################################################################
# FONCTION: Créer le VPG
###############################################################################
create_vpg() {
    local token=$1

    log "Création du VPG: ${VPG_NAME}"

    # Construction du payload JSON
    local payload
    payload=$(cat <<EOF
{
  "VpgName": "${VPG_NAME}",
  "VpgDescription": "${VPG_DESCRIPTION}",
  "SourceSiteIdentifier": "${SOURCE_SITE_ID}",
  "TargetSiteIdentifier": "${TARGET_SITE_ID}",
  "RpoInSeconds": ${RPO_SECONDS},
  "JournalHistoryInHours": ${JOURNAL_HOURS},
  "Priority": "${PRIORITY}",
  "UseWanCompression": ${ENABLE_COMPRESSION},
  "Encryption": ${ENABLE_ENCRYPTION},
  "WanAcceleration": ${WAN_ACCELERATION},
  "ProtectedVms": ${PROTECTED_VMS_JSON:-[]},
  "TargetNetwork": {
    "NetworkIdentifier": "${TARGET_NETWORK_ID}",
    "SubnetIdentifier": "${TARGET_SUBNET_ID}"
  },
  "NetworkConfiguration": ${NETWORK_CONFIG_JSON:-{}}
}
EOF
)

    # Création du VPG via API
    local response
    response=$(curl -s -w "\n%{http_code}" -X POST "${ZERTO_API_ENDPOINT}/v1/vpgSettings" \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json" \
        -d "${payload}")

    local http_code
    http_code=$(echo "${response}" | tail -n1)
    local body
    body=$(echo "${response}" | sed '$d')

    if [[ "${http_code}" -eq 200 ]] || [[ "${http_code}" -eq 201 ]]; then
        log "VPG créé avec succès"
        echo "${body}" | jq '.'
        return 0
    else
        error "Échec de la création du VPG (HTTP ${http_code})"
        echo "${body}" | jq '.' >&2
        return 1
    fi
}

###############################################################################
# FONCTION: Commiter les settings du VPG
###############################################################################
commit_vpg_settings() {
    local token=$1
    local vpg_settings_id=$2

    log "Validation des paramètres du VPG..."

    local response
    response=$(curl -s -w "\n%{http_code}" -X POST \
        "${ZERTO_API_ENDPOINT}/v1/vpgSettings/${vpg_settings_id}/commit" \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json")

    local http_code
    http_code=$(echo "${response}" | tail -n1)

    if [[ "${http_code}" -eq 200 ]]; then
        log "Paramètres du VPG validés"
        return 0
    else
        error "Échec de la validation des paramètres (HTTP ${http_code})"
        return 1
    fi
}

###############################################################################
# MAIN
###############################################################################
main() {
    log "=========================================="
    log "Création du VPG Zerto: ${VPG_NAME}"
    log "=========================================="

    # Obtention du token
    local token
    if ! token=$(get_zerto_token); then
        error "Impossible d'obtenir le token API"
        exit 1
    fi

    # Vérification si le VPG existe
    if check_vpg_exists "${token}" "${VPG_NAME}"; then
        warning "Le VPG existe déjà, mise à jour non implémentée"
        log "Vous pouvez supprimer le VPG manuellement et relancer"
        exit 0
    fi

    # Création du VPG
    local vpg_response
    if ! vpg_response=$(create_vpg "${token}"); then
        error "Échec de la création du VPG"
        exit 1
    fi

    # Extraction de l'ID des settings
    local vpg_settings_id
    vpg_settings_id=$(echo "${vpg_response}" | jq -r '.VpgSettingsIdentifier')

    if [[ -z "${vpg_settings_id}" ]] || [[ "${vpg_settings_id}" == "null" ]]; then
        error "ID des settings VPG introuvable"
        exit 1
    fi

    # Validation des settings
    if ! commit_vpg_settings "${token}" "${vpg_settings_id}"; then
        error "Échec de la validation du VPG"
        exit 1
    fi

    log "=========================================="
    log "VPG ${VPG_NAME} créé avec succès!"
    log "=========================================="
}

# Exécution du script
main "$@"
