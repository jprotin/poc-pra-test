#!/bin/bash
###############################################################################
# Script : post-failback-suspend.sh
# Description : Suspend automatiquement les VMs après un failback Zerto
#               pour éviter la double exécution des tâches CRON
# Auteur : Équipe DevOps / PRA
# Date : 2025-12-30
# ADR Associé : ADR-2025-12-30 - Stratégie Failback Mode Pause VMware
###############################################################################
# Usage : Ce script est appelé automatiquement par Zerto via les Post-Scripts
#         du VPG après l'opération de failback
###############################################################################

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

SCRIPT_NAME="$(basename "$0")"
LOG_FILE="${LOG_FILE:-/var/log/zerto/post-failback-suspend.log}"
LOG_DIR="$(dirname "$LOG_FILE")"

# Timeout pour les opérations vSphere (secondes)
VSPHERE_TIMEOUT=60

# Délai d'attente après démarrage VM avant suspension (secondes)
SUSPEND_DELAY=10

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
}

log_warn() {
    log "WARN" "$@"
}

log_error() {
    log "ERROR" "$@"
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
        log_error "Installez les outils requis : vim-cmd (VMware Tools), govc, jq"
        return 1
    fi

    return 0
}

# ------------------------------------------------------------------------------
# Fonctions vSphere
# ------------------------------------------------------------------------------

get_vm_id_by_name() {
    local vm_name="$1"
    local vm_id

    log_info "Recherche de l'ID de la VM : $vm_name"

    # Utilisation de vim-cmd pour récupérer l'ID de la VM
    vm_id=$(vim-cmd vmsvc/getallvms | grep -E "^\s*[0-9]+" | grep "$vm_name" | awk '{print $1}' | head -n1)

    if [ -z "$vm_id" ]; then
        log_error "VM '$vm_name' introuvable"
        return 1
    fi

    log_info "VM '$vm_name' trouvée avec ID : $vm_id"
    echo "$vm_id"
}

get_vm_power_state() {
    local vm_id="$1"
    local power_state

    power_state=$(vim-cmd vmsvc/power.getstate "$vm_id" 2>/dev/null | grep -E "^Powered" | awk '{print $2}')
    echo "$power_state"
}

suspend_vm() {
    local vm_id="$1"
    local vm_name="$2"
    local power_state

    power_state=$(get_vm_power_state "$vm_id")

    log_info "État actuel de la VM '$vm_name' (ID: $vm_id) : $power_state"

    case "$power_state" in
        on)
            log_info "Suspension de la VM '$vm_name' (ID: $vm_id)..."

            if vim-cmd vmsvc/power.suspend "$vm_id" 2>&1 | tee -a "$LOG_FILE"; then
                log_info "✅ VM '$vm_name' suspendue avec succès"
                return 0
            else
                log_error "❌ Échec de la suspension de la VM '$vm_name'"
                return 1
            fi
            ;;
        suspended)
            log_info "✅ VM '$vm_name' déjà en état suspendu"
            return 0
            ;;
        off)
            log_warn "⚠️  VM '$vm_name' est éteinte (pas de suspension nécessaire)"
            return 0
            ;;
        *)
            log_error "❌ État inconnu pour la VM '$vm_name' : $power_state"
            return 1
            ;;
    esac
}

check_vm_extra_config() {
    local vm_name="$1"
    local has_failback_config=false

    # Utilisation de govc pour vérifier la configuration extra_config
    if command -v govc &> /dev/null; then
        local failback_enabled
        failback_enabled=$(govc vm.info -json "$vm_name" 2>/dev/null | jq -r '.VirtualMachines[0].Config.ExtraConfig[] | select(.Key=="pra.failback.enabled") | .Value // "false"')

        if [ "$failback_enabled" == "true" ]; then
            has_failback_config=true
            log_info "✅ VM '$vm_name' a la configuration failback activée"
        else
            log_info "ℹ️  VM '$vm_name' n'a pas la configuration failback activée"
        fi
    fi

    echo "$has_failback_config"
}

# ------------------------------------------------------------------------------
# Fonction principale
# ------------------------------------------------------------------------------

main() {
    log_info "=========================================="
    log_info "Démarrage du script $SCRIPT_NAME"
    log_info "=========================================="

    # Créer le répertoire de logs si nécessaire
    mkdir -p "$LOG_DIR"

    # Vérifier les dépendances
    if ! check_dependencies; then
        log_error "Vérification des dépendances échouée"
        exit 1
    fi

    # Récupérer la liste des VMs depuis les variables d'environnement Zerto
    # Format attendu : VPG_NAME, PROTECTED_VMS_JSON
    local vpg_name="${VPG_NAME:-unknown}"
    local protected_vms_json="${PROTECTED_VMS_JSON:-[]}"

    log_info "VPG : $vpg_name"
    log_info "VMs protégées (JSON) : $protected_vms_json"

    # Parser le JSON pour extraire les noms de VMs
    local vm_names
    if command -v jq &> /dev/null; then
        vm_names=$(echo "$protected_vms_json" | jq -r '.[].name // .[].vm_name_vcenter // empty')
    else
        log_error "jq n'est pas installé, impossible de parser PROTECTED_VMS_JSON"
        exit 1
    fi

    if [ -z "$vm_names" ]; then
        log_error "Aucune VM trouvée dans PROTECTED_VMS_JSON"
        exit 1
    fi

    log_info "VMs à traiter :"
    echo "$vm_names" | while read -r vm_name; do
        log_info "  - $vm_name"
    done

    # Attendre un délai avant de commencer les suspensions
    log_info "Attente de $SUSPEND_DELAY secondes avant suspension..."
    sleep "$SUSPEND_DELAY"

    # Suspendre chaque VM
    local success_count=0
    local failure_count=0

    while IFS= read -r vm_name; do
        [ -z "$vm_name" ] && continue

        log_info "----------------------------------------"
        log_info "Traitement de la VM : $vm_name"
        log_info "----------------------------------------"

        # Vérifier si la VM a la configuration failback activée
        local has_config
        has_config=$(check_vm_extra_config "$vm_name")

        if [ "$has_config" != "true" ]; then
            log_warn "⚠️  VM '$vm_name' ignorée (configuration failback non activée)"
            continue
        fi

        # Récupérer l'ID de la VM
        local vm_id
        if ! vm_id=$(get_vm_id_by_name "$vm_name"); then
            log_error "Impossible de récupérer l'ID de la VM '$vm_name'"
            ((failure_count++))
            continue
        fi

        # Suspendre la VM
        if suspend_vm "$vm_id" "$vm_name"; then
            ((success_count++))
        else
            ((failure_count++))
        fi

    done <<< "$vm_names"

    # Résumé
    log_info "=========================================="
    log_info "Résumé de l'opération :"
    log_info "  - VMs suspendues avec succès : $success_count"
    log_info "  - VMs en échec : $failure_count"
    log_info "=========================================="

    if [ "$failure_count" -gt 0 ]; then
        log_error "⚠️  Certaines VMs n'ont pas pu être suspendues"
        log_error "Consultez le log : $LOG_FILE"
        exit 1
    fi

    log_info "✅ Script terminé avec succès"
    exit 0
}

# ------------------------------------------------------------------------------
# Point d'entrée
# ------------------------------------------------------------------------------

main "$@"
