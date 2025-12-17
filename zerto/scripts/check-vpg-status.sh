#!/bin/bash
###############################################################################
# SCRIPT - CHECK VPG STATUS
###############################################################################
# Description: Vérifie l'état des VPGs et déclenche le backup d'urgence
# Usage: ./check-vpg-status.sh [--all | --vpg VPG_NAME]
# Cron: */5 * * * * /path/to/check-vpg-status.sh --all --auto-remediate
###############################################################################

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/zerto/vpg-monitoring.log"
LOCK_FILE="/var/run/zerto-vpg-check.lock"

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables API (à configurer via environnement ou fichier)
ZERTO_API_ENDPOINT="${ZERTO_API_ENDPOINT:-https://zerto-api.ovh.net}"
ZERTO_API_TOKEN="${ZERTO_API_TOKEN:-}"
ALERT_WEBHOOK_URL="${ALERT_WEBHOOK_URL:-}"

# Options par défaut
CHECK_ALL=false
AUTO_REMEDIATE=false
VPG_NAME=""
VERBOSE=false

###############################################################################
# FONCTIONS UTILITAIRES
###############################################################################

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "$@"
    [[ "$VERBOSE" == "true" ]] && echo -e "${BLUE}ℹ️  $*${NC}"
}

log_warning() {
    log "WARNING" "$@"
    echo -e "${YELLOW}⚠️  $*${NC}"
}

log_error() {
    log "ERROR" "$@"
    echo -e "${RED}❌ $*${NC}"
}

log_success() {
    log "SUCCESS" "$@"
    echo -e "${GREEN}✅ $*${NC}"
}

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
    --all                   Vérifier tous les VPGs
    --vpg VPG_NAME          Vérifier un VPG spécifique
    --auto-remediate        Activer automatiquement le backup d'urgence si VPG KO
    --verbose               Mode verbeux
    -h, --help              Afficher cette aide

Examples:
    $0 --all
    $0 --vpg VPG-SBG-to-RBX --verbose
    $0 --all --auto-remediate  # Mode automatique (cron)

EOF
    exit 0
}

check_prerequisites() {
    log_info "Vérification des prérequis..."

    # Vérifier les commandes requises
    for cmd in jq curl ansible-playbook; do
        if ! command -v $cmd &> /dev/null; then
            log_error "Commande '$cmd' non trouvée. Installer d'abord."
            exit 1
        fi
    done

    # Vérifier les variables d'environnement
    if [[ -z "$ZERTO_API_TOKEN" ]]; then
        log_error "ZERTO_API_TOKEN non défini. Exporter la variable ou utiliser un fichier .env"
        exit 1
    fi

    # Créer le répertoire de logs si nécessaire
    mkdir -p "$(dirname "$LOG_FILE")"

    log_success "Prérequis validés"
}

acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_pid=$(cat "$LOCK_FILE")
        if kill -0 "$lock_pid" 2>/dev/null; then
            log_warning "Script déjà en cours d'exécution (PID: $lock_pid)"
            exit 0
        else
            log_warning "Lock file obsolète détecté. Nettoyage..."
            rm -f "$LOCK_FILE"
        fi
    fi

    echo $$ > "$LOCK_FILE"
    trap "rm -f $LOCK_FILE" EXIT
}

###############################################################################
# FONCTIONS API ZERTO
###############################################################################

get_all_vpgs() {
    log_info "Récupération de la liste des VPGs..."

    local response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer $ZERTO_API_TOKEN" \
        -H "Content-Type: application/json" \
        "$ZERTO_API_ENDPOINT/v1/vpgs")

    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')

    if [[ "$http_code" -ne 200 ]]; then
        log_error "Échec récupération VPGs (HTTP $http_code)"
        log_error "Response: $body"
        exit 1
    fi

    echo "$body"
}

get_vpg_by_name() {
    local vpg_name="$1"
    local all_vpgs=$(get_all_vpgs)

    echo "$all_vpgs" | jq -r --arg name "$vpg_name" \
        '.[] | select(.VpgName == $name)'
}

check_vpg_health() {
    local vpg_json="$1"

    local vpg_name=$(echo "$vpg_json" | jq -r '.VpgName')
    local status=$(echo "$vpg_json" | jq -r '.Status')
    local actual_rpo=$(echo "$vpg_json" | jq -r '.ActualRPO // "N/A"')
    local sub_status=$(echo "$vpg_json" | jq -r '.SubStatus // "N/A"')
    local source_site=$(echo "$vpg_json" | jq -r '.SourceSite // "N/A"')
    local target_site=$(echo "$vpg_json" | jq -r '.TargetSite // "N/A"')

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "VPG: $vpg_name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Source Site: $source_site"
    echo "  Target Site: $target_site"
    echo "  Status: $status"
    echo "  Sub-Status: $sub_status"
    echo "  Actual RPO: $actual_rpo seconds"

    # Déterminer la santé
    if [[ "$status" == "MeetingSLA" ]]; then
        log_success "VPG $vpg_name: HEALTHY"
        return 0
    else
        log_error "VPG $vpg_name: UNHEALTHY (Status: $status)"

        # Envoyer alerte
        send_alert "$vpg_name" "$status" "$actual_rpo" "$source_site" "$target_site"

        # Déclencher backup d'urgence si auto-remediate
        if [[ "$AUTO_REMEDIATE" == "true" ]]; then
            trigger_emergency_backup "$vpg_name" "$source_site" "$target_site"
        fi

        return 1
    fi
}

###############################################################################
# FONCTIONS ALERTES
###############################################################################

send_alert() {
    local vpg_name="$1"
    local status="$2"
    local actual_rpo="$3"
    local source_site="$4"
    local target_site="$5"

    if [[ -z "$ALERT_WEBHOOK_URL" ]]; then
        log_warning "ALERT_WEBHOOK_URL non défini. Alerte non envoyée."
        return
    fi

    local alert_message=$(cat <<EOF
{
  "text": "🚨 **ZERTO VPG ALERT**\n\n**VPG**: $vpg_name\n**Status**: $status\n**Source**: $source_site\n**Target**: $target_site\n**Actual RPO**: $actual_rpo seconds\n\n⚠️ Protection compromise détectée. Vérifier l'infrastructure.",
  "priority": "high",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)

    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$alert_message" \
        "$ALERT_WEBHOOK_URL" > /dev/null

    log_info "Alerte envoyée pour VPG $vpg_name"
}

###############################################################################
# FONCTION BACKUP D'URGENCE
###############################################################################

trigger_emergency_backup() {
    local vpg_name="$1"
    local source_site="$2"
    local target_site="$3"

    log_warning "Déclenchement du backup d'urgence pour $vpg_name..."

    # Déterminer l'application et le site survivant
    local app_name=""
    local survivor_site=""

    if [[ "$vpg_name" =~ "RBX-to-SBG" ]]; then
        # VPG RBX→SBG KO → RBX est down, SBG survit, App A affectée
        # Mais on protège App B (qui est sur SBG et réplique vers RBX)
        app_name="Application-B"
        survivor_site="SBG"
    elif [[ "$vpg_name" =~ "SBG-to-RBX" ]]; then
        # VPG SBG→RBX KO → SBG ou RBX down
        # Si RBX down, SBG survit avec App B
        app_name="Application-B"
        survivor_site="SBG"
    else
        log_error "Impossible de déterminer l'application depuis le VPG $vpg_name"
        return 1
    fi

    log_info "Application détectée: $app_name"
    log_info "Site survivant: $survivor_site"

    # Exécuter le playbook Ansible
    local playbook_path="$SCRIPT_DIR/../ansible/playbooks/activate-emergency-backup.yml"

    if [[ ! -f "$playbook_path" ]]; then
        log_error "Playbook non trouvé: $playbook_path"
        return 1
    fi

    log_info "Exécution du playbook Ansible..."

    ansible-playbook "$playbook_path" \
        -e "app_name=$app_name" \
        -e "site=$survivor_site" \
        -e "vpg_name=$vpg_name" \
        -e "zerto_api_endpoint=$ZERTO_API_ENDPOINT" \
        -e "zerto_api_token=$ZERTO_API_TOKEN" \
        -e "alert_webhook_url=$ALERT_WEBHOOK_URL" \
        --vault-password-file ~/.ansible/vault_pass.txt \
        2>&1 | tee -a "$LOG_FILE"

    local ansible_exit_code=${PIPESTATUS[0]}

    if [[ $ansible_exit_code -eq 0 ]]; then
        log_success "Backup d'urgence activé avec succès pour $app_name"
    else
        log_error "Échec de l'activation du backup d'urgence (code: $ansible_exit_code)"
        return 1
    fi
}

###############################################################################
# FONCTION PRINCIPALE
###############################################################################

main() {
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "ZERTO VPG STATUS CHECK - $(date)"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    check_prerequisites
    acquire_lock

    local exit_code=0

    if [[ "$CHECK_ALL" == "true" ]]; then
        log_info "Vérification de tous les VPGs..."

        local all_vpgs=$(get_all_vpgs)
        local vpg_count=$(echo "$all_vpgs" | jq -r '. | length')

        log_info "Nombre de VPGs trouvés: $vpg_count"

        echo "$all_vpgs" | jq -c '.[]' | while read -r vpg; do
            check_vpg_health "$vpg" || exit_code=1
            echo ""
        done

    elif [[ -n "$VPG_NAME" ]]; then
        log_info "Vérification du VPG: $VPG_NAME"

        local vpg=$(get_vpg_by_name "$VPG_NAME")

        if [[ -z "$vpg" || "$vpg" == "null" ]]; then
            log_error "VPG '$VPG_NAME' non trouvé"
            exit 1
        fi

        check_vpg_health "$vpg" || exit_code=1

    else
        log_error "Aucune option spécifiée. Utiliser --all ou --vpg VPG_NAME"
        usage
    fi

    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Vérification terminée"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    exit $exit_code
}

###############################################################################
# PARSING DES ARGUMENTS
###############################################################################

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)
            CHECK_ALL=true
            shift
            ;;
        --vpg)
            VPG_NAME="$2"
            shift 2
            ;;
        --auto-remediate)
            AUTO_REMEDIATE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Option inconnue: $1"
            usage
            ;;
    esac
done

###############################################################################
# EXÉCUTION
###############################################################################

main
