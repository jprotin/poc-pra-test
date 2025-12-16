#!/bin/bash
# ==============================================================================
# Script de déploiement : VPN Gateway uniquement
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform"

# Couleurs
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${BLUE}Déploiement du VPN Gateway Azure uniquement${NC}"
echo ""

cd "${TERRAFORM_DIR}"

# Initialiser Terraform
if [ ! -d ".terraform" ]; then
    echo "Initialisation de Terraform..."
    terraform init
fi

# Valider
terraform validate

# Appliquer uniquement le module VPN Gateway
terraform apply -target=module.azure_vpn_gateway

echo ""
echo -e "${GREEN}✅ VPN Gateway déployé avec succès !${NC}"
echo ""
echo "Prochaines étapes :"
echo "  - Attendre 30-45 minutes que le VPN Gateway soit créé"
echo "  - Déployer StrongSwan : ../deploy.sh --strongswan"
echo "  - Déployer OVH : ../deploy.sh --ovh"
