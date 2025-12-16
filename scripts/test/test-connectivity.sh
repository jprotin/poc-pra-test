#!/bin/bash
# ==============================================================================
# Script de test de connectivité complète
# ==============================================================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}======================================================================"
echo "  Test de connectivité POC PRA"
echo "======================================================================${NC}"
echo ""

# Récupérer les IPs depuis Terraform
cd "$(dirname "$0")/../../terraform"

STRONGSWAN_IP=$(terraform output -raw strongswan_public_ip 2>/dev/null || echo "")
AZURE_VPN_IP=$(terraform output -raw azure_vpn_gateway_public_ip 2>/dev/null || echo "")

if [ -z "$STRONGSWAN_IP" ]; then
    echo -e "${YELLOW}StrongSwan non déployé${NC}"
else
    echo -e "${BLUE}Test 1 : Connexion SSH vers StrongSwan${NC}"
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 azureuser@${STRONGSWAN_IP} "echo 'SSH OK'" 2>/dev/null; then
        echo -e "${GREEN}✅ SSH OK vers ${STRONGSWAN_IP}${NC}"
    else
        echo -e "${RED}❌ SSH FAILED vers ${STRONGSWAN_IP}${NC}"
    fi
    echo ""

    echo -e "${BLUE}Test 2 : Statut du tunnel IPsec${NC}"
    ssh -o StrictHostKeyChecking=no azureuser@${STRONGSWAN_IP} "sudo ipsec status" || echo -e "${RED}❌ Erreur${NC}"
    echo ""
fi

echo -e "${BLUE}Test 3 : Statut des connexions VPN Azure${NC}"
bash "$(dirname "$0")/check-vpn-status.sh" 2>/dev/null || echo -e "${YELLOW}Script check-vpn-status.sh non généré${NC}"

echo ""
echo -e "${BLUE}======================================================================${NC}"
echo -e "${GREEN}Tests de connectivité terminés${NC}"
echo -e "${BLUE}======================================================================${NC}"
