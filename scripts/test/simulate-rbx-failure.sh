#!/bin/bash
# ==============================================================================
# Script de simulation de panne RBX
# ==============================================================================

set -e

YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Simulation d'une panne du datacenter RBX...${NC}"

cd "$(dirname "$0")/../../terraform"

# Récupérer le nom de la connexion RBX
RG=$(terraform output -json deployment_summary 2>/dev/null | jq -r '.resource_group_name')
CONN_RBX=$(terraform output -raw tunnel_rbx_id 2>/dev/null | xargs basename)

if [ -z "$CONN_RBX" ]; then
    echo -e "${RED}Tunnel RBX non trouvé${NC}"
    exit 1
fi

echo "Arrêt de la connexion : ${CONN_RBX}"

# Simuler la panne en mettant la connexion en mode "disabled"
# Note : Cette méthode nécessite l'API Azure ou un redéploiement Terraform

echo ""
echo -e "${YELLOW}Pour simuler une vraie panne :${NC}"
echo "  1. Se connecter au FortiGate RBX"
echo "  2. Désactiver l'interface IPsec : set status down"
echo "  3. OU arrêter le service : execute vpn ipsec down azure-tunnel"
echo ""
echo "Vérifier le failover avec :"
echo "  ./check-vpn-status.sh"
echo "  cd ../../terraform && terraform output check_bgp_routes_command | sh"
