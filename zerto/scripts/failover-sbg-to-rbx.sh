#!/bin/bash
###############################################################################
# SCRIPT DE FAILOVER SBG -> RBX
###############################################################################
# Description: Bascule les VMs de SBG vers RBX en cas d'incident sur SBG
# Usage: ./failover-sbg-to-rbx.sh [--test] [--commit]
###############################################################################

set -euo pipefail

# Répertoire de base
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "${SCRIPT_DIR}")"

# Configuration
ZERTO_API_ENDPOINT="${ZERTO_API_ENDPOINT:-https://zerto-api.ovh.net}"
VPG_NAME="${VPG_NAME_SBG_TO_RBX:-VPG-SBG-to-RBX-production}"
TEST_MODE=false
AUTO_COMMIT=false
LOG_FILE="${BASE_DIR}/logs/failover-sbg-to-rbx-$(date +%Y%m%d-%H%M%S).log"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

###############################################################################
# FONCTIONS UTILITAIRES
###############################################################################

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "${LOG_FILE}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR]${NC} $*" | tee -a "${LOG_FILE}" >&2
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING]${NC} $*" | tee -a "${LOG_FILE}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [INFO]${NC} $*" | tee -a "${LOG_FILE}"
}

banner() {
    echo "" | tee -a "${LOG_FILE}"
    echo "============================================================================" | tee -a "${LOG_FILE}"
    echo "$*" | tee -a "${LOG_FILE}"
    echo "============================================================================" | tee -a "${LOG_FILE}"
    echo "" | tee -a "${LOG_FILE}"
}

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
    --test          Mode test (ne bascule pas réellement)
    --commit        Commit automatique
    -h, --help      Affiche cette aide

Description:
    Bascule les VMs protégées de SBG vers RBX en cas d'incident sur SBG.

EOF
    exit 0
}

###############################################################################
# PARSING DES ARGUMENTS
###############################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        --test) TEST_MODE=true; shift ;;
        --commit) AUTO_COMMIT=true; shift ;;
        -h|--help) usage ;;
        *) error "Option inconnue: $1"; usage ;;
    esac
done

###############################################################################
# FONCTION: Obtenir le token
###############################################################################

get_zerto_token() {
    info "Authentification à l'API Zerto..."

    if [[ -n "${ZERTO_API_TOKEN:-}" ]]; then
        echo "${ZERTO_API_TOKEN}"
        return 0
    fi

    if [[ -z "${ZERTO_USERNAME:-}" ]] || [[ -z "${ZERTO_PASSWORD:-}" ]]; then
        error "Credentials Zerto manquants"
        return 1
    fi

    curl -s -X POST "${ZERTO_API_ENDPOINT}/v1/session/add" \
        -H "Content-Type: application/json" \
        --user "${ZERTO_USERNAME}:${ZERTO_PASSWORD}"
}

###############################################################################
# FONCTION: Vérifier l'état du VPG
###############################################################################

check_vpg_status() {
    local token=$1
    info "Vérification de l'état du VPG: ${VPG_NAME}"

    local response
    response=$(curl -s "${ZERTO_API_ENDPOINT}/v1/vpgs" \
        -H "Authorization: Bearer ${token}")

    local vpg_info
    vpg_info=$(echo "${response}" | jq -r ".[] | select(.VpgName == \"${VPG_NAME}\")")

    if [[ -z "${vpg_info}" ]]; then
        error "VPG ${VPG_NAME} introuvable"
        return 1
    fi

    local status
    status=$(echo "${vpg_info}" | jq -r '.Status')
    local rpo
    rpo=$(echo "${vpg_info}" | jq -r '.ActualRPO')

    info "État: ${status}, RPO: ${rpo}s"
    echo "${vpg_info}"
}

###############################################################################
# FONCTION: Lancer le failover
###############################################################################

initiate_failover() {
    local token=$1
    local vpg_id=$2

    local failover_type="live"
    [[ "${TEST_MODE}" == "true" ]] && failover_type="test"

    if [[ "${AUTO_COMMIT}" == "false" ]] && [[ "${TEST_MODE}" == "false" ]]; then
        read -p "Confirmez le failover (tapez 'FAILOVER'): " confirm
        [[ "${confirm}" != "FAILOVER" ]] && { error "Annulé"; exit 1; }
    fi

    log "Lancement du failover ${failover_type}..."

    local response
    response=$(curl -s -w "\n%{http_code}" -X POST \
        "${ZERTO_API_ENDPOINT}/v1/failover" \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json" \
        -d "{\"VpgIdentifier\": \"${vpg_id}\", \"FailoverType\": \"${failover_type}\"}")

    local http_code
    http_code=$(echo "${response}" | tail -n1)

    if [[ "${http_code}" -eq 200 ]]; then
        log "Failover lancé avec succès"
        return 0
    else
        error "Échec (HTTP ${http_code})"
        return 1
    fi
}

###############################################################################
# FONCTION: Attendre la fin
###############################################################################

wait_for_completion() {
    local token=$1
    local vpg_id=$2
    local max_wait=1800
    local elapsed=0

    info "Attente de la fin du failover..."

    while [[ ${elapsed} -lt ${max_wait} ]]; do
        local status
        status=$(curl -s "${ZERTO_API_ENDPOINT}/v1/vpgs/${vpg_id}" \
            -H "Authorization: Bearer ${token}" | jq -r '.Status')

        info "État: ${status}"

        [[ "${status}" == "MeetingSLA" ]] || [[ "${status}" == "FailedOver" ]] && { log "Terminé"; return 0; }
        [[ "${status}" == "Error" ]] && { error "Échec"; return 1; }

        sleep 30
        elapsed=$((elapsed + 30))
    done

    error "Timeout"
    return 1
}

###############################################################################
# FONCTION: Reconfigurer réseau
###############################################################################

reconfigure_network() {
    info "Reconfiguration réseau RBX..."

    ansible-playbook -i "${BASE_DIR}/../ansible/inventory/zerto_hosts.yml" \
        "${BASE_DIR}/../ansible/playbooks/failover-network-reconfigure.yml" \
        -e "target_site=rbx" -e "source_site=sbg"

    [[ $? -eq 0 ]] && log "Réseau reconfiguré" || error "Échec reconfiguration"
}

###############################################################################
# MAIN
###############################################################################

main() {
    mkdir -p "$(dirname "${LOG_FILE}")"
    banner "FAILOVER SBG -> RBX"

    [[ "${TEST_MODE}" == "true" ]] && warning "MODE TEST"

    log "Début du failover SBG -> RBX"

    local token
    token=$(get_zerto_token) || { error "Auth failed"; exit 1; }

    local vpg_info
    vpg_info=$(check_vpg_status "${token}") || { error "VPG check failed"; exit 1; }

    local vpg_id
    vpg_id=$(echo "${vpg_info}" | jq -r '.VpgIdentifier')

    initiate_failover "${token}" "${vpg_id}" || { error "Failover failed"; exit 1; }
    wait_for_completion "${token}" "${vpg_id}" || { error "Completion failed"; exit 1; }
    reconfigure_network

    banner "FAILOVER TERMINÉ"
    log "VMs opérationnelles sur RBX"
    log "Log: ${LOG_FILE}"

    [[ "${TEST_MODE}" == "false" ]] && info "Failback: ./failback.sh --from rbx --to sbg"
}

trap 'error "Interrompu"; exit 130' INT TERM
main "$@"
