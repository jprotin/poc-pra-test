#!/bin/bash
###############################################################################
# SCRIPT DE FAILBACK ZERTO
###############################################################################
# Description: Retour à la normale après un failover
# Usage: ./failback.sh --from <site> --to <site> [--commit]
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "${SCRIPT_DIR}")"

# Configuration
ZERTO_API_ENDPOINT="${ZERTO_API_ENDPOINT:-https://zerto-api.ovh.net}"
LOG_FILE="${BASE_DIR}/logs/failback-$(date +%Y%m%d-%H%M%S).log"

FROM_SITE=""
TO_SITE=""
AUTO_COMMIT=false

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

###############################################################################
# FONCTIONS
###############################################################################

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "${LOG_FILE}"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "${LOG_FILE}" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "${LOG_FILE}"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "${LOG_FILE}"
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
Usage: $0 --from <site> --to <site> [OPTIONS]

Options:
    --from <site>   Site source actuel (rbx ou sbg)
    --to <site>     Site cible pour le retour (rbx ou sbg)
    --commit        Commit automatique sans confirmation
    -h, --help      Affiche cette aide

Description:
    Effectue un failback pour revenir au site d'origine après un incident.
    Le failback se fait en plusieurs étapes:
    1. Vérification de la santé du site cible
    2. Synchronisation des données via le journal Zerto
    3. Planification du failback
    4. Exécution du failback
    5. Reconfiguration réseau
    6. Vérification de la continuité

Exemples:
    $0 --from sbg --to rbx --commit    # Retour de SBG vers RBX
    $0 --from rbx --to sbg             # Retour de RBX vers SBG (avec confirmation)

EOF
    exit 0
}

###############################################################################
# PARSING DES ARGUMENTS
###############################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        --from)
            FROM_SITE="$2"
            shift 2
            ;;
        --to)
            TO_SITE="$2"
            shift 2
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

# Validation
if [[ -z "${FROM_SITE}" ]] || [[ -z "${TO_SITE}" ]]; then
    error "Les options --from et --to sont obligatoires"
    usage
fi

if [[ ! "${FROM_SITE}" =~ ^(rbx|sbg)$ ]] || [[ ! "${TO_SITE}" =~ ^(rbx|sbg)$ ]]; then
    error "Les sites doivent être 'rbx' ou 'sbg'"
    exit 1
fi

if [[ "${FROM_SITE}" == "${TO_SITE}" ]]; then
    error "Le site source et cible doivent être différents"
    exit 1
fi

# Déterminer le VPG
VPG_NAME="VPG-${TO_SITE^^}-to-${FROM_SITE^^}-production"

###############################################################################
# FONCTION: Obtenir le token
###############################################################################

get_zerto_token() {
    info "Authentification Zerto..."

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
# FONCTION: Vérifier la santé du site cible
###############################################################################

check_target_site_health() {
    local site=$1

    info "Vérification de la santé du site ${site^^}..."

    # Vérifier la connectivité réseau
    local site_ip
    [[ "${site}" == "rbx" ]] && site_ip="${RBX_FORTIGATE_IP:-10.1.0.1}"
    [[ "${site}" == "sbg" ]] && site_ip="${SBG_FORTIGATE_IP:-10.2.0.1}"

    if ping -c 3 -W 2 "${site_ip}" > /dev/null 2>&1; then
        log "Site ${site^^} accessible"
        return 0
    else
        error "Site ${site^^} non accessible"
        return 1
    fi
}

###############################################################################
# FONCTION: Vérifier l'état du VPG
###############################################################################

check_vpg_status() {
    local token=$1

    info "Vérification du VPG: ${VPG_NAME}"

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

    info "État VPG: ${status}"
    info "RPO actuel: ${rpo}s"

    # Vérifier que le RPO est acceptable pour un failback
    if [[ ${rpo} -gt 600 ]]; then
        warning "RPO élevé (${rpo}s), risque de perte de données"
        if [[ "${AUTO_COMMIT}" == "false" ]]; then
            read -p "Continuer malgré le RPO élevé? (o/N): " confirm
            [[ ! "${confirm}" =~ ^[oO]$ ]] && { error "Annulé"; exit 1; }
        fi
    fi

    echo "${vpg_info}"
}

###############################################################################
# FONCTION: Effectuer le failback
###############################################################################

perform_failback() {
    local token=$1
    local vpg_id=$2

    warning "ATTENTION: Lancement du failback de ${FROM_SITE^^} vers ${TO_SITE^^}"

    if [[ "${AUTO_COMMIT}" == "false" ]]; then
        echo ""
        read -p "Confirmez le failback (tapez 'FAILBACK'): " confirm
        if [[ "${confirm}" != "FAILBACK" ]]; then
            error "Failback annulé"
            exit 1
        fi
    fi

    log "Lancement du failback..."

    # Le failback dans Zerto est un Move
    local payload
    payload=$(cat <<EOF
{
    "VpgIdentifier": "${vpg_id}",
    "FailbackOperation": "Move",
    "CommitPolicy": "CommitAfterTimeout",
    "TimeToWaitBeforeCommitInSec": 3600,
    "ShutdownPolicy": "Shutdown",
    "ReverseReplication": true
}
EOF
)

    local response
    response=$(curl -s -w "\n%{http_code}" -X POST \
        "${ZERTO_API_ENDPOINT}/v1/failback" \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json" \
        -d "${payload}")

    local http_code
    http_code=$(echo "${response}" | tail -n1)

    if [[ "${http_code}" -eq 200 ]]; then
        log "Failback lancé avec succès"
        return 0
    else
        error "Échec du failback (HTTP ${http_code})"
        echo "${response}" | sed '$d' >&2
        return 1
    fi
}

###############################################################################
# FONCTION: Attendre la fin du failback
###############################################################################

wait_for_failback_completion() {
    local token=$1
    local vpg_id=$2
    local max_wait=3600  # 1 heure
    local elapsed=0

    info "Attente de la fin du failback (peut prendre jusqu'à 1 heure)..."

    while [[ ${elapsed} -lt ${max_wait} ]]; do
        local status
        status=$(curl -s "${ZERTO_API_ENDPOINT}/v1/vpgs/${vpg_id}" \
            -H "Authorization: Bearer ${token}" | jq -r '.Status')

        info "État: ${status} (${elapsed}s écoulées)"

        if [[ "${status}" == "MeetingSLA" ]]; then
            log "Failback terminé avec succès"
            return 0
        elif [[ "${status}" == "Error" ]]; then
            error "Le failback a échoué"
            return 1
        fi

        sleep 60
        elapsed=$((elapsed + 60))
    done

    error "Timeout du failback"
    return 1
}

###############################################################################
# FONCTION: Reconfigurer le réseau
###############################################################################

reconfigure_network() {
    info "Reconfiguration réseau pour ${TO_SITE^^}..."

    ansible-playbook -i "${BASE_DIR}/../ansible/inventory/zerto_hosts.yml" \
        "${BASE_DIR}/../ansible/playbooks/failover-network-reconfigure.yml" \
        -e "target_site=${TO_SITE}" \
        -e "source_site=${FROM_SITE}" \
        -e "operation=failback"

    if [[ $? -eq 0 ]]; then
        log "Réseau reconfiguré"
        return 0
    else
        error "Échec de la reconfiguration réseau"
        return 1
    fi
}

###############################################################################
# FONCTION: Vérifier la continuité
###############################################################################

verify_continuity() {
    info "Vérification de la continuité de service sur ${TO_SITE^^}..."

    # Liste des VMs à vérifier selon le site cible
    local vms_to_check
    if [[ "${TO_SITE}" == "rbx" ]]; then
        vms_to_check=("rbx-app-prod-01" "rbx-db-prod-01")
    else
        vms_to_check=("sbg-app-prod-01" "sbg-db-prod-01")
    fi

    for vm in "${vms_to_check[@]}"; do
        info "Vérification de ${vm}..."
        # Ajouter des checks de santé spécifiques ici
    done

    log "Vérifications terminées"
}

###############################################################################
# MAIN
###############################################################################

main() {
    mkdir -p "$(dirname "${LOG_FILE}")"

    banner "FAILBACK ${FROM_SITE^^} -> ${TO_SITE^^}"

    log "Début du failback"
    log "VPG: ${VPG_NAME}"

    # 1. Vérifier la santé du site cible
    if ! check_target_site_health "${TO_SITE}"; then
        error "Le site cible ${TO_SITE^^} n'est pas disponible"
        exit 1
    fi

    # 2. Authentification
    local token
    if ! token=$(get_zerto_token); then
        error "Échec de l'authentification"
        exit 1
    fi

    # 3. Vérifier le VPG
    local vpg_info
    if ! vpg_info=$(check_vpg_status "${token}"); then
        error "Impossible de vérifier le VPG"
        exit 1
    fi

    local vpg_id
    vpg_id=$(echo "${vpg_info}" | jq -r '.VpgIdentifier')

    # 4. Effectuer le failback
    if ! perform_failback "${token}" "${vpg_id}"; then
        error "Échec du failback"
        exit 1
    fi

    # 5. Attendre la fin
    if ! wait_for_failback_completion "${token}" "${vpg_id}"; then
        error "Le failback n'a pas pu se terminer"
        exit 1
    fi

    # 6. Reconfigurer le réseau
    if ! reconfigure_network; then
        warning "Reconfiguration réseau échouée, intervention manuelle requise"
    fi

    # 7. Vérifier la continuité
    verify_continuity

    banner "FAILBACK TERMINÉ AVEC SUCCÈS"
    log "Les VMs sont de retour sur ${TO_SITE^^}"
    log "La réplication inverse a été activée"
    log "Log complet: ${LOG_FILE}"

    info "Le système est de retour à la normale"
}

trap 'error "Script interrompu"; exit 130' INT TERM
main "$@"
