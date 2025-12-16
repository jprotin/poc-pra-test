#!/bin/bash
# ==============================================================================
# Script de destruction : Toute l'infrastructure
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform"

# Couleurs
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}⚠️  ATTENTION - DESTRUCTION COMPLÈTE DE L'INFRASTRUCTURE${NC}"
echo ""
echo "Cette action va SUPPRIMER DÉFINITIVEMENT toutes les ressources :"
echo "  - VPN Gateway Azure"
echo "  - VM StrongSwan"
echo "  - Tous les tunnels VPN"
echo "  - Tous les réseaux virtuels"
echo "  - Toutes les IPs publiques"
echo ""
echo -e "${YELLOW}Cette action est IRRÉVERSIBLE !${NC}"
echo ""
read -p "Tapez 'DESTROY' pour confirmer : " confirm

if [ "$confirm" != "DESTROY" ]; then
    echo "Destruction annulée"
    exit 0
fi

cd "${TERRAFORM_DIR}"

echo ""
echo "Destruction en cours..."
terraform destroy

echo ""
echo -e "${RED}Infrastructure détruite${NC}"
