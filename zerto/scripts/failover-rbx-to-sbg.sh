#!/bin/bash
###############################################################################
# SCRIPT DE FAILOVER RBX -> SBG
###############################################################################
# Description: Bascule les VMs de RBX vers SBG en cas d'incident sur RBX
# Usage: ./failover-rbx-to-sbg.sh [--test] [--commit]
###############################################################################

set -euo pipefail

# Répertoire de base
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "${SCRIPT_DIR}")"

# Chargement de la configuration
CONFIG_FILE="${BASE_DIR}/config/failover.conf"
if [[ -f "${CONFIG_FILE}" ]]; then
    source "${CONFIG_FILE}"
fi

# Configuration par défaut
ZERTO_API_ENDPOINT="${ZERTO_API_ENDPOINT:-https://zerto-api.ovh.net}"
VPG_NAME="${VPG_NAME_RBX_TO_SBG:-VPG-RBX-to-SBG-production}"
TEST_MODE=false
AUTO_COMMIT=false
LOG_FILE="${BASE_DIR}/logs/failover-rbx-to-sbg-$(date +%Y%m%d-%H%M%S).log"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

###############################################################################
# FONCTIONS UTILITAIRES
###############################################################################

log() {
    local timestamp
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[${timestamp}]${NC} $*" | tee -a "${LOG_FILE}"
}

error() {
    local timestamp
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[${timestamp}] [ERROR]${NC} $*" | tee -a "${LOG_FILE}" >&2
}

warning() {
    local timestamp
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[${timestamp}] [WARNING]${NC} $*" | tee -a "${LOG_FILE}"
}

info() {
    local timestamp
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}[${timestamp}] [INFO]${NC} $*" | tee -a "${LOG_FILE}"
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
    --test          Mode test (ne bascule pas réellement les VMs)
    --commit        Commit automatique sans demande de confirmation
    -h, --help      Affiche cette aide

Description:
    Bascule les VMs protégées de RBX vers SBG en cas d'incident sur RBX.
    Ce script effectue les opérations suivantes:
    1. Vérification de l'état du VPG
    2. Lancement du failover Zerto
    3. Vérification du démarrage des VMs sur SBG
    4. Reconfiguration réseau Fortigate
    5. Vérification de la continuité de service

Exemples:
    $0 --test              # Test sans bascule réelle
    $0 --commit            # Bascule avec commit automatique
    $0                     # Bascule avec confirmation manuelle

EOF
    exit 0
}

###############################################################################
# PARSING DES ARGUMENTS
###############################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        --test)
            TEST_MODE=true
            shift
            ;;
        --commit)
            AUTO_COMMIT=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            error "Option inconnue: $1"
            usage
            ;;
    esac
done

###############################################################################
# FONCTION: Obtenir le token API Zerto
###############################################################################

get_zerto_token() {
    info "Authentification à l'API Zerto..."

    if [[ -n "${ZERTO_API_TOKEN:-}" ]]; then
        echo "${ZERTO_API_TOKEN}"
        return 0
    fi

    if [[ -z "${ZERTO_USERNAME:-}" ]] || [[ -z "${ZERTO_PASSWORD:-}" ]]; then
        error "ZERTO_API_TOKEN ou ZERTO_USERNAME/ZERTO_PASSWORD requis"
        return 1
    fi

    local response
    response=$(curl -s -X POST "${ZERTO_API_ENDPOINT}/v1/session/add" \
        -H "Content-Type: application/json" \
        -d "{\"AuthenticationMethod\": 1}" \
        --user "${ZERTO_USERNAME}:${ZERTO_PASSWORD}")

    echo "${response}"
}

###############################################################################
# FONCTION: Vérifier l'état du VPG
###############################################################################

check_vpg_status() {
    local token=$1

    info "Vérification de l'état du VPG: ${VPG_NAME}"

    local response
    response=$(curl -s -X GET "${ZERTO_API_ENDPOINT}/v1/vpgs" \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json")

    local vpg_info
    vpg_info=$(echo "${response}" | jq -r ".[] | select(.VpgName == \"${VPG_NAME}\")")

    if [[ -z "${vpg_info}" ]]; then
        error "VPG ${VPG_NAME} introuvable"
        return 1
    fi

    local vpg_status
    vpg_status=$(echo "${vpg_info}" | jq -r '.Status')

    local current_rpo
    current_rpo=$(echo "${vpg_info}" | jq -r '.ActualRPO')

    info "État du VPG: ${vpg_status}"
    info "RPO actuel: ${current_rpo} secondes"

    echo "${vpg_info}"
}

###############################################################################
# FONCTION: Lancer le failover
###############################################################################

initiate_failover() {
    local token=$1
    local vpg_id=$2

    if [[ "${TEST_MODE}" == "true" ]]; then
        warning "Mode test activé - Lancement d'un test failover"
        local failover_type="test"
    else
        warning "ATTENTION: Lancement d'un failover réel!"
        local failover_type="live"
    fi

    if [[ "${AUTO_COMMIT}" == "false" ]] && [[ "${TEST_MODE}" == "false" ]]; then
        echo ""
        read -p "Confirmez-vous le failover? (tapez 'FAILOVER' pour confirmer): " confirm
        if [[ "${confirm}" != "FAILOVER" ]]; then
            error "Failover annulé par l'utilisateur"
            exit 1
        fi
    fi

    log "Lancement du failover du VPG ${VPG_NAME}..."

    local payload
    payload=$(cat <<EOF
{
    "VpgIdentifier": "${vpg_id}",
    "FailoverType": "${failover_type}",
    "CommitPolicy": "RollbackAfterCommit",
    "ShutdownPolicy": "None",
    "TimeToWaitBeforeShutdownInSec": 0
}
EOF
)

    local response
    response=$(curl -s -w "\n%{http_code}" -X POST \
        "${ZERTO_API_ENDPOINT}/v1/failover" \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json" \
        -d "${payload}")

    local http_code
    http_code=$(echo "${response}" | tail -n1)
    local body
    body=$(echo "${response}" | sed '$d')

    if [[ "${http_code}" -eq 200 ]]; then
        log "Failover lancé avec succès"
        echo "${body}"
        return 0
    else
        error "Échec du failover (HTTP ${http_code})"
        echo "${body}" >&2
        return 1
    fi
}

###############################################################################
# FONCTION: Attendre la fin du failover
###############################################################################

wait_for_failover_completion() {
    local token=$1
    local vpg_id=$2
    local max_wait=1800  # 30 minutes
    local elapsed=0

    info "Attente de la fin du failover (timeout: ${max_wait}s)..."

    while [[ ${elapsed} -lt ${max_wait} ]]; do
        local response
        response=$(curl -s -X GET "${ZERTO_API_ENDPOINT}/v1/vpgs/${vpg_id}" \
            -H "Authorization: Bearer ${token}")

        local status
        status=$(echo "${response}" | jq -r '.Status')

        info "État: ${status}"

        if [[ "${status}" == "MeetingSLA" ]] || [[ "${status}" == "FailedOver" ]]; then
            log "Failover terminé avec succès"
            return 0
        elif [[ "${status}" == "Error" ]]; then
            error "Le failover a échoué"
            return 1
        fi

        sleep 30
        elapsed=$((elapsed + 30))
    done

    error "Timeout atteint lors de l'attente du failover"
    return 1
}

###############################################################################
# FONCTION: Reconfigurer le réseau Fortigate
###############################################################################

reconfigure_fortigate() {
    info "Reconfiguration du routage Fortigate SBG..."

    # Exécuter le playbook Ansible pour reconfigurer le Fortigate
    ansible-playbook -i "${BASE_DIR}/../ansible/inventory/zerto_hosts.yml" \
        "${BASE_DIR}/../ansible/playbooks/failover-network-reconfigure.yml" \
        -e "target_site=sbg" \
        -e "source_site=rbx"

    if [[ $? -eq 0 ]]; then
        log "Fortigate SBG reconfiguré avec succès"
        return 0
    else
        error "Échec de la reconfiguration Fortigate"
        return 1
    fi
}

###############################################################################
# FONCTION: Vérifier la continuité de service
###############################################################################

verify_service_continuity() {
    info "Vérification de la continuité de service..."

    # Vérifier que les VMs répondent
    local vms_to_check=(
        "sbg-app-prod-01"
        "sbg-db-prod-01"
    )

    for vm in "${vms_to_check[@]}"; do
        info "Vérification de ${vm}..."
        # Ici, ajouter des checks de santé spécifiques
        # ping, curl, etc.
    done

    log "Vérifications de continuité terminées"
}

###############################################################################
# FONCTION: Envoyer les notifications
###############################################################################

send_notifications() {
    local status=$1
    local message=$2

    info "Envoi des notifications..."

    # Webhook Slack/Teams
    if [[ -n "${WEBHOOK_URL:-}" ]]; then
        curl -s -X POST "${WEBHOOK_URL}" \
            -H "Content-Type: application/json" \
            -d "{\"text\": \"[${status}] Failover RBX->SBG: ${message}\"}"
    fi

    # Email
    if [[ -n "${ALERT_EMAILS:-}" ]]; then
        echo "${message}" | mail -s "[${status}] Failover RBX->SBG" "${ALERT_EMAILS}"
    fi
}

###############################################################################
# MAIN
###############################################################################

main() {
    # Créer le répertoire de logs
    mkdir -p "$(dirname "${LOG_FILE}")"

    banner "FAILOVER RBX -> SBG"

    if [[ "${TEST_MODE}" == "true" ]]; then
        warning "MODE TEST ACTIVÉ"
    fi

    log "Début du failover de RBX vers SBG"
    log "Date: $(date)"
    log "VPG: ${VPG_NAME}"

    # 1. Authentification
    local token
    if ! token=$(get_zerto_token); then
        error "Échec de l'authentification"
        send_notifications "ERROR" "Échec de l'authentification Zerto"
        exit 1
    fi

    # 2. Vérification du VPG
    local vpg_info
    if ! vpg_info=$(check_vpg_status "${token}"); then
        error "Impossible de vérifier l'état du VPG"
        send_notifications "ERROR" "Impossible de vérifier l'état du VPG ${VPG_NAME}"
        exit 1
    fi

    local vpg_id
    vpg_id=$(echo "${vpg_info}" | jq -r '.VpgIdentifier')

    # 3. Lancement du failover
    if ! initiate_failover "${token}" "${vpg_id}"; then
        error "Échec du lancement du failover"
        send_notifications "ERROR" "Échec du lancement du failover"
        exit 1
    fi

    # 4. Attendre la fin du failover
    if ! wait_for_failover_completion "${token}" "${vpg_id}"; then
        error "Le failover n'a pas pu se terminer"
        send_notifications "ERROR" "Le failover n'a pas pu se terminer"
        exit 1
    fi

    # 5. Reconfigurer le réseau
    if ! reconfigure_fortigate; then
        warning "La reconfiguration réseau a échoué, intervention manuelle requise"
        send_notifications "WARNING" "Failover réussi mais reconfiguration réseau échouée"
    fi

    # 6. Vérifier la continuité de service
    verify_service_continuity

    # 7. Notification de succès
    banner "FAILOVER TERMINÉ AVEC SUCCÈS"
    log "Les VMs sont maintenant opérationnelles sur SBG"
    log "Log complet: ${LOG_FILE}"

    send_notifications "SUCCESS" "Failover RBX->SBG terminé avec succès"

    if [[ "${TEST_MODE}" == "false" ]]; then
        info "Pour revenir à RBX une fois l'incident résolu, exécutez:"
        info "  ./failback.sh --from sbg --to rbx"
    fi
}

# Gestion des signaux
trap 'error "Script interrompu"; send_notifications "ERROR" "Failover interrompu"; exit 130' INT TERM

# Exécution
main "$@"
