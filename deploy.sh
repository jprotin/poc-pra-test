#!/bin/bash

# ==============================================================================
# Script de Déploiement Global - POC PRA
# ==============================================================================
# Description : Script principal pour déployer l'infrastructure hybride
#               Azure + OVHCloud avec VPN IPsec/BGP
# Usage       : ./deploy.sh [options]
# Options     : --all, --vpn, --strongswan, --ovh, --help
# ==============================================================================

set -e  # Arrêter en cas d'erreur

# ==============================================================================
# Configuration
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/terraform"
ANSIBLE_DIR="${SCRIPT_DIR}/ansible"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ==============================================================================
# Fonctions Utilitaires
# ==============================================================================

# Afficher le banner
print_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║                           POC PRA - Déploiement                              ║
║                  Infrastructure Hybride Azure + OVHCloud                     ║
║                                                                              ║
║                  🔹 VPN Gateway Azure avec BGP                               ║
║                  🔹 Tunnels IPsec vers StrongSwan et FortiGate               ║
║                  🔹 Failover automatique RBX ↔ SBG                          ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Messages de log
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_step() {
    echo -e "${MAGENTA}[ÉTAPE]${NC} $1"
}

# Afficher un séparateur
separator() {
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════════${NC}"
}

# Afficher l'aide
show_help() {
    cat << EOF
Usage: ./deploy.sh [OPTIONS]

Déploie l'infrastructure POC PRA selon les options choisies.

OPTIONS:
  --all              Déployer toute l'infrastructure (VPN + StrongSwan + OVH)
  --vpn              Déployer uniquement le VPN Gateway Azure
  --strongswan       Déployer le VPN Gateway + VM StrongSwan + Tunnel statique
  --ovh              Déployer le VPN Gateway + Tunnels OVH (RBX + SBG)
  --terraform-only   Exécuter uniquement Terraform (pas Ansible)
  --ansible-only     Exécuter uniquement Ansible (suppose Terraform déjà fait)
  --skip-checks      Ignorer les vérifications de prérequis
  --help             Afficher cette aide

EXEMPLES:
  ./deploy.sh --all              # Déploiement complet
  ./deploy.sh --strongswan       # Déployer VPN + StrongSwan uniquement
  ./deploy.sh --vpn              # Déployer uniquement le VPN Gateway
  ./deploy.sh --terraform-only   # Terraform uniquement

PRÉREQUIS:
  - Terraform >= 1.5.0
  - Ansible >= 2.14
  - Azure CLI authentifié (az login)
  - Fichier terraform/terraform.tfvars configuré

DOCUMENTATION:
  Consulter Documentation/03-DEPLOIEMENT.md pour plus de détails.

EOF
}

# ==============================================================================
# Fonctions de Vérification
# ==============================================================================

check_prerequisites() {
    log_step "Vérification des prérequis..."

    local errors=0

    # Vérifier Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform n'est pas installé"
        errors=$((errors + 1))
    else
        local tf_version=$(terraform version -json | jq -r .terraform_version)
        log_success "Terraform v${tf_version} installé"
    fi

    # Vérifier Ansible
    if ! command -v ansible &> /dev/null; then
        log_error "Ansible n'est pas installé"
        errors=$((errors + 1))
    else
        local ansible_version=$(ansible --version | head -n1 | awk '{print $2}')
        log_success "Ansible v${ansible_version} installé"
    fi

    # Vérifier Azure CLI
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI n'est pas installé"
        errors=$((errors + 1))
    else
        local az_version=$(az version --query '"azure-cli"' -o tsv)
        log_success "Azure CLI v${az_version} installé"
    fi

    # Vérifier la connexion Azure
    if ! az account show &> /dev/null; then
        log_error "Non connecté à Azure. Exécutez: az login"
        errors=$((errors + 1))
    else
        local subscription=$(az account show --query name -o tsv)
        log_success "Azure Subscription: ${subscription}"
    fi

    # Vérifier jq
    if ! command -v jq &> /dev/null; then
        log_warning "jq n'est pas installé (optionnel mais recommandé)"
    else
        log_success "jq installé"
    fi

    # Vérifier le fichier terraform.tfvars
    if [ ! -f "${TERRAFORM_DIR}/terraform.tfvars" ]; then
        log_error "Le fichier terraform/terraform.tfvars n'existe pas"
        log_info "Copiez l'exemple : cp terraform/terraform.tfvars.example terraform/terraform.tfvars"
        errors=$((errors + 1))
    else
        log_success "Fichier terraform.tfvars trouvé"
    fi

    if [ $errors -gt 0 ]; then
        log_error "${errors} erreur(s) détectée(s). Impossible de continuer."
        exit 1
    fi

    separator
}

# ==============================================================================
# Fonctions de Déploiement
# ==============================================================================

deploy_terraform() {
    log_step "Déploiement de l'infrastructure avec Terraform..."

    cd "${TERRAFORM_DIR}"

    # Initialiser Terraform
    if [ ! -d ".terraform" ]; then
        log_info "Initialisation de Terraform..."
        terraform init
    else
        log_info "Terraform déjà initialisé"
    fi

    # Valider la configuration
    log_info "Validation de la configuration Terraform..."
    terraform validate

    # Planifier le déploiement
    log_info "Planification du déploiement..."
    terraform plan -out=tfplan

    # Demander confirmation
    echo ""
    log_warning "⚠️  IMPORTANT ⚠️"
    log_warning "Le VPN Gateway Azure prend environ 30-45 minutes à créer"
    log_warning "Coûts estimés : VpnGw1 ~90-100€/mois + VMs ~8-15€/mois"
    echo ""
    read -p "Voulez-vous appliquer ce plan? (oui/non): " confirm

    if [ "$confirm" != "oui" ]; then
        log_info "Déploiement annulé"
        rm -f tfplan
        exit 0
    fi

    # Appliquer le plan
    log_info "Application du plan Terraform..."
    terraform apply tfplan

    rm -f tfplan

    log_success "Infrastructure Terraform déployée avec succès!"
    separator

    cd "${SCRIPT_DIR}"
}

deploy_ansible_strongswan() {
    log_step "Configuration de StrongSwan avec Ansible..."

    cd "${ANSIBLE_DIR}"

    # Vérifier que l'inventaire existe
    local inventory="${ANSIBLE_DIR}/inventories/dev/strongswan.ini"
    if [ ! -f "${inventory}" ]; then
        log_error "Inventaire Ansible non trouvé: ${inventory}"
        log_error "Assurez-vous que Terraform a été exécuté avec succès"
        exit 1
    fi

    # Attendre que la VM soit prête
    log_info "Attente de la disponibilité de la VM StrongSwan (60 secondes)..."
    sleep 60

    # Exécuter le playbook
    log_info "Exécution du playbook Ansible pour StrongSwan..."
    ansible-playbook -i "${inventory}" playbooks/01-configure-strongswan.yml

    log_success "Configuration StrongSwan terminée avec succès!"
    separator

    cd "${SCRIPT_DIR}"
}

deploy_ansible_fortigates() {
    log_step "Configuration des FortiGates avec Ansible..."

    cd "${ANSIBLE_DIR}"

    # Vérifier que l'inventaire existe
    local inventory="${ANSIBLE_DIR}/inventories/dev/fortigates.ini"
    if [ ! -f "${inventory}" ]; then
        log_error "Inventaire Ansible non trouvé: ${inventory}"
        log_error "Assurez-vous que Terraform a été exécuté avec succès"
        exit 1
    fi

    # Exécuter le playbook
    log_info "Exécution du playbook Ansible pour FortiGates..."
    ansible-playbook -i "${inventory}" playbooks/02-configure-fortigates.yml

    log_success "Configuration FortiGates terminée avec succès!"
    separator

    cd "${SCRIPT_DIR}"
}

run_connectivity_tests() {
    log_step "Exécution des tests de connectivité..."

    if [ -f "${SCRIPTS_DIR}/test/check-vpn-status.sh" ]; then
        bash "${SCRIPTS_DIR}/test/check-vpn-status.sh"
    else
        log_warning "Script de test non trouvé, en cours de génération par Terraform..."
    fi

    separator
}

# ==============================================================================
# Fonction Principale
# ==============================================================================

main() {
    print_banner

    # Variables
    local deploy_mode="help"
    local skip_terraform=false
    local skip_ansible=false
    local skip_checks=false

    # Parser les arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                deploy_mode="all"
                shift
                ;;
            --vpn)
                deploy_mode="vpn"
                shift
                ;;
            --strongswan)
                deploy_mode="strongswan"
                shift
                ;;
            --ovh)
                deploy_mode="ovh"
                shift
                ;;
            --terraform-only)
                skip_ansible=true
                shift
                ;;
            --ansible-only)
                skip_terraform=true
                shift
                ;;
            --skip-checks)
                skip_checks=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Option inconnue: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Afficher l'aide si aucun argument
    if [ "$deploy_mode" = "help" ]; then
        show_help
        exit 0
    fi

    # Vérifications
    if [ "$skip_checks" = false ]; then
        check_prerequisites
    fi

    # Déploiement selon le mode
    case $deploy_mode in
        all)
            log_info "Mode: Déploiement complet (VPN + StrongSwan + OVH)"
            if [ "$skip_terraform" = false ]; then
                deploy_terraform
            fi
            if [ "$skip_ansible" = false ]; then
                deploy_ansible_strongswan
                deploy_ansible_fortigates
            fi
            run_connectivity_tests
            ;;
        vpn)
            log_info "Mode: Déploiement VPN Gateway uniquement"
            if [ "$skip_terraform" = false ]; then
                deploy_terraform
            fi
            ;;
        strongswan)
            log_info "Mode: Déploiement VPN + StrongSwan"
            if [ "$skip_terraform" = false ]; then
                deploy_terraform
            fi
            if [ "$skip_ansible" = false ]; then
                deploy_ansible_strongswan
            fi
            run_connectivity_tests
            ;;
        ovh)
            log_info "Mode: Déploiement VPN + OVH (RBX + SBG)"
            if [ "$skip_terraform" = false ]; then
                deploy_terraform
            fi
            if [ "$skip_ansible" = false ]; then
                deploy_ansible_fortigates
            fi
            run_connectivity_tests
            ;;
    esac

    # Message final
    separator
    log_success "🎉 DÉPLOIEMENT TERMINÉ AVEC SUCCÈS! 🎉"
    separator
    echo ""
    echo -e "${GREEN}📋 PROCHAINES ÉTAPES :${NC}"
    echo ""
    echo "  1. Vérifier les tunnels VPN :"
    echo "     ${CYAN}./scripts/test/check-vpn-status.sh${NC}"
    echo ""
    echo "  2. Tester la connectivité :"
    echo "     ${CYAN}./scripts/test/test-connectivity.sh${NC}"
    echo ""
    echo "  3. Consulter les outputs Terraform :"
    echo "     ${CYAN}cd terraform && terraform output${NC}"
    echo ""
    echo -e "${GREEN}📚 DOCUMENTATION :${NC}"
    echo "     ${CYAN}Documentation/03-DEPLOIEMENT.md${NC}"
    echo ""
    separator
}

# Exécuter le script principal
main "$@"
