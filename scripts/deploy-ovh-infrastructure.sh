#!/bin/bash
# ==============================================================================
# Script de déploiement - Infrastructure OVH VMware
# ==============================================================================
# Description : Déploiement automatisé de l'infrastructure applicative OVH
#               (Docker + MySQL + vRack + FortiGate + Zerto) via Terraform
# Usage       : ./scripts/deploy-ovh-infrastructure.sh [--auto-approve]
# ==============================================================================

set -euo pipefail  # Exit on error, undefined variable, or pipe failure

# ------------------------------------------------------------------------------
# Variables globales
# ------------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform/ovh-infrastructure"
ANSIBLE_DIR="${PROJECT_ROOT}/ansible/playbooks/ovh-infrastructure"
LOG_FILE="${PROJECT_ROOT}/deploy-ovh-$(date +%Y%m%d_%H%M%S).log"

AUTO_APPROVE=false

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

log_info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $*" | tee -a "${LOG_FILE}"
}

print_banner() {
    cat <<'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║     Déploiement Infrastructure OVH VMware Applicative        ║
║     Docker + MySQL + vRack + FortiGate + Zerto PRA           ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
}

check_prerequisites() {
    log "🔍 Vérification des prérequis..."

    local missing_tools=()

    # Vérifier Terraform
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    else
        log_info "✅ Terraform $(terraform version | head -n1)"
    fi

    # Vérifier Ansible
    if ! command -v ansible &> /dev/null; then
        missing_tools+=("ansible")
    else
        log_info "✅ Ansible $(ansible --version | head -n1)"
    fi

    # Vérifier SSH
    if ! command -v ssh &> /dev/null; then
        missing_tools+=("ssh")
    fi

    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Outils manquants: ${missing_tools[*]}"
        log_error "Installez les outils requis avant de continuer."
        exit 1
    fi

    # Vérifier fichier terraform.tfvars
    if [ ! -f "${TERRAFORM_DIR}/terraform.tfvars" ]; then
        log_error "Fichier terraform.tfvars non trouvé dans ${TERRAFORM_DIR}"
        log_info "Copiez terraform.tfvars.example vers terraform.tfvars et configurez les variables."
        exit 1
    fi

    log "✅ Tous les prérequis sont satisfaits"
}

terraform_init() {
    log "🚀 Initialisation Terraform..."

    cd "${TERRAFORM_DIR}"

    if terraform init -upgrade 2>&1 | tee -a "${LOG_FILE}"; then
        log "✅ Terraform initialisé avec succès"
    else
        log_error "❌ Échec de l'initialisation Terraform"
        exit 1
    fi
}

terraform_plan() {
    log "📋 Génération du plan Terraform..."

    cd "${TERRAFORM_DIR}"

    if terraform plan -out=tfplan 2>&1 | tee -a "${LOG_FILE}"; then
        log "✅ Plan Terraform généré avec succès"
        log_info "Plan sauvegardé dans tfplan"
        return 0
    else
        log_error "❌ Échec de la génération du plan"
        exit 1
    fi
}

terraform_apply() {
    log "🔨 Déploiement de l'infrastructure via Terraform..."

    cd "${TERRAFORM_DIR}"

    local apply_cmd="terraform apply"

    if [ "${AUTO_APPROVE}" = true ]; then
        apply_cmd="${apply_cmd} -auto-approve"
        log_warning "Mode auto-approve activé - Le déploiement démarrera sans confirmation"
    else
        log_info "Veuillez confirmer le déploiement ci-dessous..."
    fi

    if ${apply_cmd} tfplan 2>&1 | tee -a "${LOG_FILE}"; then
        log "✅ Infrastructure déployée avec succès"
    else
        log_error "❌ Échec du déploiement"
        exit 1
    fi
}

terraform_output() {
    log "📊 Récupération des outputs Terraform..."

    cd "${TERRAFORM_DIR}"

    terraform output -json > "${PROJECT_ROOT}/terraform-outputs.json"

    log "✅ Outputs sauvegardés dans terraform-outputs.json"
}

generate_ansible_inventory() {
    log "📝 Génération de l'inventory Ansible..."

    cd "${TERRAFORM_DIR}"

    terraform output -raw ansible_inventory > "${ANSIBLE_DIR}/inventory.yml"

    log "✅ Inventory Ansible généré: ${ANSIBLE_DIR}/inventory.yml"
}

run_ansible_playbooks() {
    log "🎭 Exécution des playbooks Ansible pour post-configuration..."

    cd "${ANSIBLE_DIR}"

    # Attendre que les VMs soient accessibles via SSH (max 5 minutes)
    log_info "⏳ Attente de la disponibilité SSH des VMs..."
    sleep 60  # Attendre 1 minute pour que les VMs redémarrent après cloud-init

    # Exécuter le playbook de configuration
    if ansible-playbook -i inventory.yml configure-all.yml 2>&1 | tee -a "${LOG_FILE}"; then
        log "✅ Configuration Ansible terminée avec succès"
    else
        log_warning "⚠️  Playbook Ansible a échoué - Vérifiez manuellement"
        log_info "Vous pouvez réexécuter: cd ${ANSIBLE_DIR} && ansible-playbook -i inventory.yml configure-all.yml"
    fi
}

print_summary() {
    log "📊 Résumé du déploiement"

    cat <<EOF | tee -a "${LOG_FILE}"

╔═══════════════════════════════════════════════════════════════╗
║              Déploiement terminé avec succès ! 🎉             ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Infrastructure déployée :                                    ║
║    ✅ VMs Docker (RBX + SBG)                                  ║
║    ✅ VMs MySQL (RBX + SBG)                                   ║
║    ✅ Configuration réseau vRack                              ║
║    ✅ Règles FortiGate                                        ║
║    ✅ Virtual Protection Groups (VPG) Zerto                   ║
║                                                               ║
║  Fichiers générés :                                           ║
║    📄 ${PROJECT_ROOT}/terraform-outputs.json                  ║
║    📄 ${ANSIBLE_DIR}/inventory.yml                            ║
║    📄 ${LOG_FILE}                                             ║
║                                                               ║
║  Prochaines étapes :                                          ║
║    1. Vérifier la connectivité SSH vers les VMs               ║
║    2. Tester les connexions Docker → MySQL                    ║
║    3. Déployer vos applications Docker                        ║
║    4. Effectuer un test de failover Zerto                     ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

Pour afficher les outputs Terraform :
  cd ${TERRAFORM_DIR} && terraform output

Pour tester la connectivité SSH :
  terraform output -raw ansible_inventory

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
            echo "  --auto-approve    Skip confirmation before applying Terraform"
            echo "  -h, --help        Show this help message"
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
    log "📁 Répertoire Ansible: ${ANSIBLE_DIR}"
    log "📄 Fichier de log: ${LOG_FILE}"
    echo ""

    check_prerequisites
    echo ""

    terraform_init
    echo ""

    terraform_plan
    echo ""

    terraform_apply
    echo ""

    terraform_output
    echo ""

    generate_ansible_inventory
    echo ""

    run_ansible_playbooks
    echo ""

    print_summary

    log "✅ Déploiement terminé avec succès ! 🎉"
}

# Execute main function
main "$@"
