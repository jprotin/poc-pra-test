#!/bin/bash

# deploy.sh - Script de déploiement automatique Terraform + Ansible

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Banner
echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║   Déploiement IPsec S2S - StrongSwan + Azure VPN Gateway  ║
║   Terraform + Ansible                                     ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Vérification des prérequis
log_info "Vérification des prérequis..."

if ! command -v terraform &> /dev/null; then
    log_error "Terraform n'est pas installé"
    exit 1
fi
log_success "Terraform: $(terraform version -json | jq -r .terraform_version)"

if ! command -v ansible &> /dev/null; then
    log_error "Ansible n'est pas installé"
    exit 1
fi
log_success "Ansible: $(ansible --version | head -n1 | awk '{print $2}')"

if ! command -v az &> /dev/null; then
    log_error "Azure CLI n'est pas installé"
    exit 1
fi
log_success "Azure CLI: $(az version --query '"azure-cli"' -o tsv)"

# Vérifier la connexion Azure
if ! az account show &> /dev/null; then
    log_error "Non connecté à Azure. Exécutez: az login"
    exit 1
fi
SUBSCRIPTION=$(az account show --query name -o tsv)
log_success "Azure Subscription: $SUBSCRIPTION"

# Vérifier que terraform.tfvars existe
if [ ! -f "terraform/terraform.tfvars" ]; then
    log_error "Le fichier terraform/terraform.tfvars n'existe pas"
    log_info "Copiez terraform.tfvars.example et configurez-le:"
    log_info "  cp terraform/terraform.tfvars.example terraform/terraform.tfvars"
    log_info "  nano terraform/terraform.tfvars"
    exit 1
fi
log_success "Fichier terraform.tfvars trouvé"

echo ""
log_warning "Ce déploiement va créer des ressources Azure qui coûteront ~105€/mois"
log_warning "Le VPN Gateway prend environ 30-45 minutes à créer"
read -p "Voulez-vous continuer? (oui/non): " confirm

if [ "$confirm" != "oui" ]; then
    log_info "Déploiement annulé"
    exit 0
fi

echo ""
log_info "=========================================="
log_info "Étape 1/4: Initialisation Terraform"
log_info "=========================================="

cd terraform

if [ ! -d ".terraform" ]; then
    terraform init
else
    log_info "Terraform déjà initialisé"
fi

echo ""
log_info "=========================================="
log_info "Étape 2/4: Déploiement de l'infrastructure"
log_info "=========================================="

log_info "Planification..."
terraform plan -out=tfplan

log_info "Application du plan..."
terraform apply tfplan

log_success "Infrastructure déployée avec succès!"

# Récupérer les outputs
STRONGSWAN_IP=$(terraform output -raw strongswan_public_ip)
AZURE_VPN_IP=$(terraform output -raw azure_vpn_gateway_public_ip)

echo ""
log_info "=========================================="
log_info "Étape 3/4: Attente de la disponibilité"
log_info "=========================================="

log_info "Attente de la disponibilité de la VM StrongSwan..."
sleep 60

# Tester la connexion SSH
log_info "Test de la connexion SSH..."
MAX_RETRIES=10
RETRY=0

while [ $RETRY -lt $MAX_RETRIES ]; do
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 azureuser@$STRONGSWAN_IP "echo 'SSH OK'" &> /dev/null; then
        log_success "VM accessible via SSH"
        break
    fi
    RETRY=$((RETRY + 1))
    log_info "Tentative $RETRY/$MAX_RETRIES..."
    sleep 10
done

if [ $RETRY -eq $MAX_RETRIES ]; then
    log_error "Impossible de se connecter à la VM via SSH"
    exit 1
fi

echo ""
log_info "=========================================="
log_info "Étape 4/4: Provisioning avec Ansible"
log_info "=========================================="

cd ansible

if [ ! -f "inventory.ini" ]; then
    log_error "L'inventaire Ansible n'a pas été généré par Terraform"
    exit 1
fi

log_info "Exécution du playbook Ansible..."
ansible-playbook -i inventory.ini playbook.yml

echo ""
log_success "=========================================="
log_success "Déploiement terminé avec succès!"
log_success "=========================================="

echo ""
echo -e "${GREEN}Configuration:${NC}"
echo -e "  VM StrongSwan IP:    ${BLUE}$STRONGSWAN_IP${NC}"
echo -e "  Azure VPN Gateway:   ${BLUE}$AZURE_VPN_IP${NC}"
echo ""
echo -e "${GREEN}Prochaines étapes:${NC}"
echo -e "  1. SSH vers la VM:   ${YELLOW}ssh azureuser@$STRONGSWAN_IP${NC}"
echo -e "  2. Tester IPsec:     ${YELLOW}sudo ipsec status${NC}"
echo -e "  3. Lancer les tests: ${YELLOW}sudo /usr/local/bin/test-ipsec.sh${NC}"
echo ""
echo -e "${GREEN}Vérifier la connexion VPN:${NC}"
echo -e "  ${YELLOW}az network vpn-connection show --name conn-dev-s2s-onprem --resource-group rg-dev-azure-vpn --query connectionStatus -o tsv${NC}"
echo ""

# Optionnel: lancer un test automatique
read -p "Voulez-vous lancer un test de connectivité maintenant? (oui/non): " run_test

if [ "$run_test" = "oui" ]; then
    log_info "Lancement du test de connectivité..."
    sleep 10
    ssh -o StrictHostKeyChecking=no azureuser@$STRONGSWAN_IP "sudo /usr/local/bin/test-ipsec.sh"
fi

echo ""
log_success "Déploiement terminé! 🎉"
