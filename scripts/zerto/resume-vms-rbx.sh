#!/bin/bash
###############################################################################
# Script : resume-vms-rbx.sh
# Description : Active (resume) manuellement les VMs RBX après failback Zerto
#               Une fois la checklist de validation complétée
# Auteur : Équipe DevOps / PRA
# Date : 2025-12-30
# ADR Associé : ADR-2025-12-30 - Stratégie Failback Mode Pause VMware
###############################################################################
# Usage : ./resume-vms-rbx.sh [OPTIONS]
#
# Options :
#   -v, --vpg-name <nom>     Nom du VPG Zerto (ex: VPG-RBX-TO-SBG)
#   -s, --site <site>        Site cible (rbx ou sbg)
#   -d, --dry-run            Mode simulation (n'effectue pas les changements)
#   -f, --force              Forcer l'activation sans confirmation
#   -h, --help               Afficher l'aide
#
# Exemples :
#   ./resume-vms-rbx.sh --vpg-name VPG-RBX-TO-SBG --site rbx
#   ./resume-vms-rbx.sh --vpg-name VPG-RBX-TO-SBG --site rbx --dry-run
###############################################################################

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="${LOG_FILE:-/var/log/zerto/resume-vms.log}"
LOG_DIR="$(dirname "$LOG_FILE")"

# Options par défaut
VPG_NAME=""
SITE=""
DRY_RUN=false
FORCE=false

# Timeout pour les opérations vSphere (secondes)
VSPHERE_TIMEOUT=60

# Délai d'attente entre les activations de VMs (secondes)
RESUME_DELAY=5

# ------------------------------------------------------------------------------
# Couleurs pour l'affichage
# ------------------------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ------------------------------------------------------------------------------
# Fonctions utilitaires
# ------------------------------------------------------------------------------

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "$@"
    echo -e "${BLUE}ℹ️  $*${NC}"
}

log_success() {
    log "SUCCESS" "$@"
    echo -e "${GREEN}✅ $*${NC}"
}

log_warn() {
    log "WARN" "$@"
    echo -e "${YELLOW}⚠️  $*${NC}"
}

log_error() {
    log "ERROR" "$@"
    echo -e "${RED}❌ $*${NC}"
}

usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Active (resume) les VMs suspendues après un failback Zerto.

Options:
  -v, --vpg-name <nom>     Nom du VPG Zerto (ex: VPG-RBX-TO-SBG)
  -s, --site <site>        Site cible (rbx ou sbg)
  -d, --dry-run            Mode simulation (n'effectue pas les changements)
  -f, --force              Forcer l'activation sans confirmation
  -h, --help               Afficher cette aide

Exemples:
  $SCRIPT_NAME --vpg-name VPG-RBX-TO-SBG --site rbx
  $SCRIPT_NAME --vpg-name VPG-RBX-TO-SBG --site rbx --dry-run

Note: Ce script doit être exécuté APRÈS avoir complété la checklist de
      validation failback (voir Documentation/zerto/checklist-failback-mode-pause.md)

EOF
    exit 0
}

check_dependencies() {
    local missing_deps=()

    for cmd in vim-cmd govc jq; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Dépendances manquantes : ${missing_deps[*]}"
        log_error "Installez les outils requis :"
        log_error "  - vim-cmd : Installé avec VMware Tools"
        log_error "  - govc : https://github.com/vmware/govmomi/releases"
        log_error "  - jq : apt-get install jq"
        return 1
    fi

    return 0
}

# ------------------------------------------------------------------------------
# Fonctions vSphere
# ------------------------------------------------------------------------------

get_vms_by_site() {
    local site="$1"
    local vms=()

    log_info "Recherche des VMs pour le site : $site"

    # Utilisation de govc pour lister les VMs avec le tag failback
    if command -v govc &> /dev/null; then
        # Récupérer toutes les VMs qui ont la configuration pra.failback.site=$site
        local vm_list
        vm_list=$(govc find / -type m 2>/dev/null || echo "")

        while IFS= read -r vm_path; do
            [ -z "$vm_path" ] && continue

            local vm_name
            vm_name=$(basename "$vm_path")

            # Vérifier la configuration failback de la VM
            local failback_site
            failback_site=$(govc vm.info -json "$vm_path" 2>/dev/null | jq -r '.VirtualMachines[0].Config.ExtraConfig[] | select(.Key=="pra.failback.site") | .Value // ""')

            if [ "$failback_site" == "$site" ]; then
                vms+=("$vm_name")
            fi
        done <<< "$vm_list"
    fi

    if [ ${#vms[@]} -eq 0 ]; then
        log_warn "Aucune VM trouvée pour le site $site avec configuration failback"
        return 1
    fi

    printf '%s\n' "${vms[@]}"
}

get_vm_id_by_name() {
    local vm_name="$1"
    local vm_id

    vm_id=$(vim-cmd vmsvc/getallvms | grep -E "^\s*[0-9]+" | grep "$vm_name" | awk '{print $1}' | head -n1)

    if [ -z "$vm_id" ]; then
        return 1
    fi

    echo "$vm_id"
}

get_vm_power_state() {
    local vm_id="$1"
    local power_state

    power_state=$(vim-cmd vmsvc/power.getstate "$vm_id" 2>/dev/null | grep -E "^Powered" | awk '{print $2}')
    echo "$power_state"
}

resume_vm() {
    local vm_id="$1"
    local vm_name="$2"
    local power_state

    power_state=$(get_vm_power_state "$vm_id")

    log_info "État actuel de la VM '$vm_name' (ID: $vm_id) : $power_state"

    case "$power_state" in
        suspended)
            if [ "$DRY_RUN" = true ]; then
                log_info "[DRY-RUN] Activation de la VM '$vm_name' (ID: $vm_id)..."
                return 0
            fi

            log_info "Activation de la VM '$vm_name' (ID: $vm_id)..."

            if vim-cmd vmsvc/power.on "$vm_id" 2>&1 | tee -a "$LOG_FILE"; then
                log_success "VM '$vm_name' activée avec succès"
                return 0
            else
                log_error "Échec de l'activation de la VM '$vm_name'"
                return 1
            fi
            ;;
        on)
            log_success "VM '$vm_name' déjà active"
            return 0
            ;;
        off)
            log_warn "VM '$vm_name' est éteinte (pas en état suspendu)"

            if [ "$FORCE" = true ]; then
                log_warn "Démarrage forcé de la VM..."
                if [ "$DRY_RUN" = false ]; then
                    vim-cmd vmsvc/power.on "$vm_id" 2>&1 | tee -a "$LOG_FILE"
                fi
                return 0
            else
                log_error "Utilisez --force pour démarrer une VM éteinte"
                return 1
            fi
            ;;
        *)
            log_error "État inconnu pour la VM '$vm_name' : $power_state"
            return 1
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Checklist de validation
# ------------------------------------------------------------------------------

show_checklist() {
    cat << 'EOF'

╔══════════════════════════════════════════════════════════════════════════════╗
║                     CHECKLIST DE VALIDATION FAILBACK                         ║
╚══════════════════════════════════════════════════════════════════════════════╝

Avant d'activer les VMs, assurez-vous d'avoir complété les étapes suivantes :

  ☐ 1. Vérifier l'état de réplication Zerto (RPO < 5min)
  ☐ 2. Confirmer que les VMs sont en état SUSPENDED
  ☐ 3. Vérifier connectivité réseau (ping gateway, DNS)
  ☐ 4. Tester accès vRack (ping inter-VM)
  ☐ 5. Vérifier montages NFS/Volumes (df -h, mount)
  ☐ 6. Valider intégrité base de données MySQL (select 1)
  ☐ 7. Vérifier logs Zerto (aucune erreur de synchronisation)

EOF
}

confirm_action() {
    if [ "$FORCE" = true ]; then
        return 0
    fi

    show_checklist

    echo ""
    read -p "Avez-vous complété toute la checklist ? (oui/non) : " -r
    echo ""

    if [[ ! $REPLY =~ ^[Oo]ui$ ]]; then
        log_warn "Opération annulée par l'utilisateur"
        log_info "Consultez la checklist complète dans : Documentation/zerto/checklist-failback-mode-pause.md"
        exit 0
    fi

    echo ""
    read -p "Confirmez-vous l'activation des VMs $SITE ? (oui/non) : " -r
    echo ""

    if [[ ! $REPLY =~ ^[Oo]ui$ ]]; then
        log_warn "Opération annulée par l'utilisateur"
        exit 0
    fi
}

# ------------------------------------------------------------------------------
# Fonction principale
# ------------------------------------------------------------------------------

main() {
    # Parse des arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--vpg-name)
                VPG_NAME="$2"
                shift 2
                ;;
            -s|--site)
                SITE="$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                log_error "Option inconnue : $1"
                usage
                ;;
        esac
    done

    # Validation des paramètres
    if [ -z "$SITE" ]; then
        log_error "Le paramètre --site est obligatoire"
        usage
    fi

    if [[ ! "$SITE" =~ ^(rbx|sbg)$ ]]; then
        log_error "Le site doit être 'rbx' ou 'sbg'"
        usage
    fi

    # Créer le répertoire de logs
    mkdir -p "$LOG_DIR"

    log_info "=========================================="
    log_info "Activation des VMs après failback"
    log_info "=========================================="
    log_info "Site : $SITE"
    log_info "VPG : ${VPG_NAME:-auto-détection}"
    log_info "Mode : $([ "$DRY_RUN" = true ] && echo "Simulation" || echo "Production")"
    log_info "=========================================="

    # Vérifier les dépendances
    if ! check_dependencies; then
        exit 1
    fi

    # Récupérer les VMs du site
    local vms
    if ! vms=$(get_vms_by_site "$SITE"); then
        log_error "Impossible de récupérer les VMs du site $SITE"
        exit 1
    fi

    local vm_count
    vm_count=$(echo "$vms" | wc -l)

    log_info "VMs à activer ($vm_count) :"
    echo "$vms" | while read -r vm_name; do
        log_info "  - $vm_name"
    done

    # Confirmation utilisateur
    confirm_action

    # Activer chaque VM
    local success_count=0
    local failure_count=0

    while IFS= read -r vm_name; do
        [ -z "$vm_name" ] && continue

        log_info "----------------------------------------"
        log_info "Traitement de la VM : $vm_name"

        # Récupérer l'ID de la VM
        local vm_id
        if ! vm_id=$(get_vm_id_by_name "$vm_name"); then
            log_error "Impossible de récupérer l'ID de la VM '$vm_name'"
            ((failure_count++))
            continue
        fi

        # Activer la VM
        if resume_vm "$vm_id" "$vm_name"; then
            ((success_count++))
            # Attendre entre chaque activation
            if [ "$success_count" -lt "$vm_count" ]; then
                log_info "Attente de $RESUME_DELAY secondes avant la VM suivante..."
                sleep "$RESUME_DELAY"
            fi
        else
            ((failure_count++))
        fi

    done <<< "$vms"

    # Résumé
    log_info "=========================================="
    log_info "Résumé de l'opération :"
    log_info "  - VMs activées avec succès : $success_count"
    log_info "  - VMs en échec : $failure_count"
    log_info "=========================================="

    if [ "$DRY_RUN" = true ]; then
        log_info "Mode simulation activé - Aucune modification effectuée"
    fi

    if [ "$failure_count" -gt 0 ]; then
        log_error "Certaines VMs n'ont pas pu être activées"
        log_error "Consultez le log : $LOG_FILE"
        exit 1
    fi

    log_success "Toutes les VMs ont été activées avec succès"
    log_info ""
    log_info "Prochaines étapes :"
    log_info "  1. Vérifier le démarrage des services (MySQL, Docker)"
    log_info "  2. Effectuer les tests applicatifs"
    log_info "  3. Basculer le DNS/Load Balancer vers $SITE"
    log_info "  4. Arrêter les VMs du site de secours"
    log_info ""

    exit 0
}

# ------------------------------------------------------------------------------
# Point d'entrée
# ------------------------------------------------------------------------------

main "$@"
