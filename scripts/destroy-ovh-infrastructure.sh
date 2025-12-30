#!/bin/bash
# ==============================================================================
# Script de destruction - Infrastructure OVH VMware
# ==============================================================================
# Description : Destruction complète de l'infrastructure applicative OVH
#               déployée via Terraform (VMs, réseau, règles FortiGate, VPG Zerto)
# Usage       : ./scripts/destroy-ovh-infrastructure.sh [--auto-approve]
# ATTENTION   : Cette action est IRREVERSIBLE et supprimera toutes les VMs !
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Variables globales
# ------------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform/ovh-infrastructure"
LOG_FILE="${PROJECT_ROOT}/destroy-ovh-$(date +%Y%m%d_%H%M%S).log"

AUTO_APPROVE=false

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ------------------------------------------------------------------------------
# Fonctions utilitaires
# ------------------------------------------------------------------------------

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "${LOG_FILE}"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $*" | tee -a "${LOG_FILE}" >&2
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $*" | tee -a "${LOG_FILE}"
}

print_banner() {
    cat <<'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   ⚠️  DESTRUCTION Infrastructure OVH VMware Applicative ⚠️    ║
║                                                               ║
║            Cette action est IRREVERSIBLE !                    ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
}

confirm_destruction() {
    if [ "${AUTO_APPROVE}" = true ]; then
        log_warning "Mode auto-approve activé - Destruction sans confirmation"
        return 0
    fi

    log_warning "Vous êtes sur le point de détruire l'infrastructure suivante :"
    echo ""

    cd "${TERRAFORM_DIR}"
    terraform show -no-color 2>/dev/null || true

    echo ""
    echo -e "${RED}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ATTENTION : Cette action supprimera définitivement : ║${NC}"
    echo -e "${RED}║  • Toutes les VMs (Docker + MySQL)                    ║${NC}"
    echo -e "${RED}║  • Les données stockées sur les VMs                   ║${NC}"
    echo -e "${RED}║  • Les configurations réseau (port groups)            ║${NC}"
    echo -e "${RED}║  • Les règles FortiGate                               ║${NC}"
    echo -e "${RED}║  • Les Virtual Protection Groups (VPG) Zerto          ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""

    read -p "Êtes-vous ABSOLUMENT SÛR de vouloir continuer ? (tapez 'DESTROY' en majuscules) : " confirmation

    if [ "${confirmation}" != "DESTROY" ]; then
        log "❌ Destruction annulée par l'utilisateur"
        exit 0
    fi

    log_warning "Confirmation reçue - Démarrage de la destruction..."
}

disable_zerto_protection() {
    log "🛑 Désactivation des Virtual Protection Groups (VPG) Zerto..."

    # Note: Zerto VPG doivent être désactivés/supprimés avant de détruire les VMs
    # pour éviter des erreurs de réplication

    log_warning "⚠️  Assurez-vous que les VPG Zerto sont désactivés manuellement via Zerto UI"
    log_warning "   ou attendez que Terraform les détruise automatiquement"

    sleep 5
}

terraform_destroy() {
    log "💥 Destruction de l'infrastructure via Terraform..."

    cd "${TERRAFORM_DIR}"

    local destroy_cmd="terraform destroy"

    if [ "${AUTO_APPROVE}" = true ]; then
        destroy_cmd="${destroy_cmd} -auto-approve"
    fi

    if ${destroy_cmd} 2>&1 | tee -a "${LOG_FILE}"; then
        log "✅ Infrastructure détruite avec succès"
    else
        log_error "❌ Échec de la destruction"
        log_error "Certaines ressources peuvent encore exister - Vérifiez manuellement"
        exit 1
    fi
}

cleanup_files() {
    log "🧹 Nettoyage des fichiers générés..."

    local files_to_remove=(
        "${TERRAFORM_DIR}/tfplan"
        "${TERRAFORM_DIR}/.terraform.lock.hcl"
        "${TERRAFORM_DIR}/terraform.tfstate.backup"
        "${PROJECT_ROOT}/terraform-outputs.json"
        "${PROJECT_ROOT}/ansible/playbooks/ovh-infrastructure/inventory.yml"
    )

    for file in "${files_to_remove[@]}"; do
        if [ -f "${file}" ]; then
            rm -f "${file}"
            log "  🗑️  Supprimé: $(basename "${file}")"
        fi
    done

    log "✅ Nettoyage terminé"
}

print_summary() {
    log "📊 Résumé de la destruction"

    cat <<EOF | tee -a "${LOG_FILE}"

╔═══════════════════════════════════════════════════════════════╗
║          Infrastructure détruite avec succès ! ✅             ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Ressources supprimées :                                      ║
║    ✅ VMs Docker (RBX + SBG)                                  ║
║    ✅ VMs MySQL (RBX + SBG)                                   ║
║    ✅ Configuration réseau vRack                              ║
║    ✅ Règles FortiGate                                        ║
║    ✅ Virtual Protection Groups (VPG) Zerto                   ║
║                                                               ║
║  Fichier de log :                                             ║
║    📄 ${LOG_FILE}                                             ║
║                                                               ║
║  Pour redéployer l'infrastructure :                           ║
║    ./scripts/deploy-ovh-infrastructure.sh                     ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

EOF
}

# ------------------------------------------------------------------------------
# Parse arguments
# ------------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case $1 in
        --auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--auto-approve]"
            echo ""
            echo "Options:"
            echo "  --auto-approve    Skip confirmation before destroying"
            echo "  -h, --help        Show this help message"
            echo ""
            echo "ATTENTION: This will permanently delete all VMs and data!"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

main() {
    print_banner

    log "📁 Répertoire projet: ${PROJECT_ROOT}"
    log "📁 Répertoire Terraform: ${TERRAFORM_DIR}"
    log "📄 Fichier de log: ${LOG_FILE}"
    echo ""

    confirm_destruction
    echo ""

    disable_zerto_protection
    echo ""

    terraform_destroy
    echo ""

    cleanup_files
    echo ""

    print_summary

    log "✅ Destruction terminée avec succès !"
}

# Execute main function
main "$@"
