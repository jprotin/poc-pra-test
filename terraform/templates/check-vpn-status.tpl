#!/bin/bash
# ==============================================================================
# Script de vérification du statut des tunnels VPN
# Généré automatiquement par Terraform
# ==============================================================================

set -e

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "======================================================================"
echo "  Vérification du statut des tunnels VPN"
echo "======================================================================"
echo ""

%{ if deploy_strongswan ~}
echo -n "Tunnel StrongSwan : "
STATUS=$(az network vpn-connection show \
  --name ${connection_strongswan} \
  --resource-group ${resource_group} \
  --query connectionStatus -o tsv)

if [ "$STATUS" = "Connected" ]; then
  echo -e "$${GREEN}Connected ✅$${NC}"
else
  echo -e "$${RED}$STATUS ❌$${NC}"
fi
%{ endif ~}

%{ if deploy_rbx ~}
echo -n "Tunnel RBX       : "
STATUS=$(az network vpn-connection show \
  --name ${connection_rbx} \
  --resource-group ${resource_group} \
  --query connectionStatus -o tsv)

if [ "$STATUS" = "Connected" ]; then
  echo -e "$${GREEN}Connected ✅ (PRIMARY)$${NC}"
else
  echo -e "$${RED}$STATUS ❌$${NC}"
fi
%{ endif ~}

%{ if deploy_sbg ~}
echo -n "Tunnel SBG       : "
STATUS=$(az network vpn-connection show \
  --name ${connection_sbg} \
  --resource-group ${resource_group} \
  --query connectionStatus -o tsv)

if [ "$STATUS" = "Connected" ]; then
  echo -e "$${GREEN}Connected ✅ (BACKUP)$${NC}"
else
  echo -e "$${RED}$STATUS ❌$${NC}"
fi
%{ endif ~}

echo ""
echo "======================================================================"
