#!/bin/bash
###############################################################################
# SCRIPT DE SUPPRESSION VPG ZERTO
###############################################################################
# Description: Supprime un Virtual Protection Group via l'API Zerto
# Usage: ./delete-vpg.sh <VPG_NAME>
###############################################################################

set -euo pipefail

VPG_NAME="${1:-${VPG_NAME:-}}"

if [[ -z "${VPG_NAME}" ]]; then
    echo "Usage: $0 <VPG_NAME>" >&2
    exit 1
fi

ZERTO_API_ENDPOINT="${ZERTO_API_ENDPOINT:-https://zerto-api.ovh.net}"
ZERTO_API_TOKEN="${ZERTO_API_TOKEN:-}"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

error() {
    echo "[ERROR] $*" >&2
}

# Obtenir le token API
get_token() {
    if [[ -n "${ZERTO_API_TOKEN}" ]]; then
        echo "${ZERTO_API_TOKEN}"
        return 0
    fi

    if [[ -z "${ZERTO_USERNAME:-}" ]] || [[ -z "${ZERTO_PASSWORD:-}" ]]; then
        error "ZERTO_API_TOKEN ou ZERTO_USERNAME/ZERTO_PASSWORD requis"
        return 1
    fi

    curl -s -X POST "${ZERTO_API_ENDPOINT}/v1/session/add" \
        -H "Content-Type: application/json" \
        --user "${ZERTO_USERNAME}:${ZERTO_PASSWORD}"
}

# Obtenir l'ID du VPG
get_vpg_id() {
    local token=$1
    local vpg_name=$2

    local response
    response=$(curl -s -X GET "${ZERTO_API_ENDPOINT}/v1/vpgs" \
        -H "Authorization: Bearer ${token}")

    echo "${response}" | jq -r ".[] | select(.VpgName == \"${vpg_name}\") | .VpgIdentifier"
}

# Supprimer le VPG
delete_vpg() {
    local token=$1
    local vpg_id=$2

    log "Suppression du VPG: ${VPG_NAME} (ID: ${vpg_id})"

    local response
    response=$(curl -s -w "\n%{http_code}" -X DELETE \
        "${ZERTO_API_ENDPOINT}/v1/vpgs/${vpg_id}" \
        -H "Authorization: Bearer ${token}")

    local http_code
    http_code=$(echo "${response}" | tail -n1)

    if [[ "${http_code}" -eq 200 ]] || [[ "${http_code}" -eq 204 ]]; then
        log "VPG supprimé avec succès"
        return 0
    else
        error "Échec de la suppression (HTTP ${http_code})"
        return 1
    fi
}

main() {
    log "Suppression du VPG: ${VPG_NAME}"

    local token
    if ! token=$(get_token); then
        error "Impossible d'obtenir le token API"
        exit 1
    fi

    local vpg_id
    vpg_id=$(get_vpg_id "${token}" "${VPG_NAME}")

    if [[ -z "${vpg_id}" ]] || [[ "${vpg_id}" == "null" ]]; then
        log "VPG ${VPG_NAME} introuvable, peut-être déjà supprimé"
        exit 0
    fi

    if delete_vpg "${token}" "${vpg_id}"; then
        log "VPG ${VPG_NAME} supprimé avec succès"
    else
        error "Échec de la suppression du VPG"
        exit 1
    fi
}

main "$@"
