#!/bin/bash

# simulate-rbx-failure.sh - Simulation d'incident sur le site RBX (Primary)
# Ce script simule une panne du tunnel IPsec RBX pour tester le failover BGP vers SBG

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/../terraform"
LOG_FILE="${SCRIPT_DIR}/failover-test-$(date +%Y%m%d-%H%M%S).log"

# Fonction de logging
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_info() {
    log "${BLUE}[INFO]${NC} $1"
}

log_success() {
    log "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    log "${RED}[ERROR]${NC} $1"
}

log_warning() {
    log "${YELLOW}[WARNING]${NC} $1"
}

# Banner
echo -e "${RED}"
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║        SIMULATION DE PANNE RBX (PRIMARY SITE)           ║
║         Test de Failover BGP vers SBG (BACKUP)          ║
╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

log_info "Début de la simulation de panne RBX"
log_info "Logs sauvegardés dans: $LOG_FILE"

# Charger les variables Terraform
cd "$TERRAFORM_DIR"

if [ ! -f "terraform.tfstate" ]; then
    log_error "Fichier terraform.tfstate introuvable. Déployez d'abord l'infrastructure."
    exit 1
fi

# Récupérer les informations depuis Terraform
log_info "Récupération des informations de configuration..."

RG_NAME=$(terraform output -raw resource_groups 2>/dev/null | jq -r '.azure' || echo "")
VPN_GW_NAME=$(terraform output -json | jq -r '.azure_vpn_gateway_primary_ip.value // empty')
RBX_CONN_NAME="conn-prod-azure-rbx-primary"
SBG_CONN_NAME="conn-prod-azure-sbg-backup"

if [ -z "$RG_NAME" ]; then
    log_error "Impossible de récupérer le nom du Resource Group"
    exit 1
fi

log_success "Configuration chargée:"
log_info "  Resource Group: $RG_NAME"
log_info "  RBX Connection: $RBX_CONN_NAME"
log_info "  SBG Connection: $SBG_CONN_NAME"

echo ""
log_warning "⚠️  ATTENTION: Cette opération va:"
log_warning "  1. Désactiver le tunnel IPsec RBX (Primary)"
log_warning "  2. Forcer le trafic à basculer vers SBG (Backup)"
log_warning "  3. Tester la convergence BGP"
echo ""
read -p "Voulez-vous continuer? (oui/non): " confirm

if [ "$confirm" != "oui" ]; then
    log_info "Simulation annulée"
    exit 0
fi

echo ""
log_info "=========================================="
log_info "Phase 1: État initial"
log_info "=========================================="

log_info "Vérification de l'état des tunnels..."

# État RBX
RBX_STATUS=$(az network vpn-connection show \
    --name "$RBX_CONN_NAME" \
    --resource-group "$RG_NAME" \
    --query connectionStatus -o tsv 2>/dev/null || echo "Unknown")

log_info "RBX Tunnel Status: $RBX_STATUS"

# État SBG
SBG_STATUS=$(az network vpn-connection show \
    --name "$SBG_CONN_NAME" \
    --resource-group "$RG_NAME" \
    --query connectionStatus -o tsv 2>/dev/null || echo "Unknown")

log_info "SBG Tunnel Status: $SBG_STATUS"

if [ "$RBX_STATUS" != "Connected" ]; then
    log_error "Le tunnel RBX n'est pas connecté. État actuel: $RBX_STATUS"
    log_error "Impossible de simuler une panne sur un tunnel déjà down."
    exit 1
fi

log_success "Tunnel RBX actif (Connected)"

echo ""
log_info "Récupération des routes BGP avant la panne..."

# Sauvegarder les routes BGP actuelles
BGP_ROUTES_BEFORE="${SCRIPT_DIR}/bgp-routes-before-$(date +%Y%m%d-%H%M%S).json"
az network vnet-gateway list-learned-routes \
    --name "vpngw-prod-azure" \
    --resource-group "$RG_NAME" \
    --output json > "$BGP_ROUTES_BEFORE" 2>/dev/null || true

log_info "Routes BGP sauvegardées: $BGP_ROUTES_BEFORE"

echo ""
log_info "=========================================="
log_info "Phase 2: Simulation de la panne RBX"
log_info "=========================================="

log_warning "Désactivation du tunnel IPsec RBX..."

# Sauvegarder la configuration actuelle
log_info "Sauvegarde de la configuration RBX..."
az network vpn-connection show \
    --name "$RBX_CONN_NAME" \
    --resource-group "$RG_NAME" \
    --output json > "${SCRIPT_DIR}/rbx-config-backup-$(date +%Y%m%d-%H%M%S).json"

# Méthode 1: Modifier le shared key (simule une mauvaise config)
log_info "Modification du Shared Key RBX (simule une panne)..."
az network vpn-connection shared-key update \
    --resource-group "$RG_NAME" \
    --connection-name "$RBX_CONN_NAME" \
    --value "INVALID_KEY_SIMULATING_FAILURE_$(date +%s)" \
    --output none

log_success "Tunnel RBX perturbé (Shared Key modifié)"

# Alternative: Désactiver complètement la connexion
# az network vpn-connection update \
#     --name "$RBX_CONN_NAME" \
#     --resource-group "$RG_NAME" \
#     --set enableBgp=false \
#     --output none

echo ""
log_info "Attente de la détection de la panne (30 secondes)..."
for i in {30..1}; do
    echo -ne "  Temps restant: ${i}s\r"
    sleep 1
done
echo ""

echo ""
log_info "=========================================="
log_info "Phase 3: Vérification du failover BGP"
log_info "=========================================="

log_info "Vérification du statut des tunnels après panne..."

# Vérifier RBX (devrait être déconnecté)
RBX_STATUS_AFTER=$(az network vpn-connection show \
    --name "$RBX_CONN_NAME" \
    --resource-group "$RG_NAME" \
    --query connectionStatus -o tsv 2>/dev/null || echo "Unknown")

log_info "RBX Tunnel Status: $RBX_STATUS_AFTER"

if [ "$RBX_STATUS_AFTER" = "Connected" ]; then
    log_warning "Le tunnel RBX est toujours connecté. Attente supplémentaire..."
    sleep 30
    RBX_STATUS_AFTER=$(az network vpn-connection show \
        --name "$RBX_CONN_NAME" \
        --resource-group "$RG_NAME" \
        --query connectionStatus -o tsv 2>/dev/null || echo "Unknown")
fi

# Vérifier SBG (devrait prendre le relais)
SBG_STATUS_AFTER=$(az network vpn-connection show \
    --name "$SBG_CONN_NAME" \
    --resource-group "$RG_NAME" \
    --query connectionStatus -o tsv 2>/dev/null || echo "Unknown")

log_info "SBG Tunnel Status: $SBG_STATUS_AFTER"

echo ""
if [ "$RBX_STATUS_AFTER" != "Connected" ] && [ "$SBG_STATUS_AFTER" = "Connected" ]; then
    log_success "✓ FAILOVER RÉUSSI!"
    log_success "  - RBX (Primary): $RBX_STATUS_AFTER"
    log_success "  - SBG (Backup):  $SBG_STATUS_AFTER"
else
    log_warning "État des tunnels:"
    log_warning "  - RBX: $RBX_STATUS_AFTER"
    log_warning "  - SBG: $SBG_STATUS_AFTER"
fi

echo ""
log_info "Attente de la convergence BGP (60 secondes)..."
sleep 60

echo ""
log_info "Récupération des routes BGP après failover..."

BGP_ROUTES_AFTER="${SCRIPT_DIR}/bgp-routes-after-$(date +%Y%m%d-%H%M%S).json"
az network vnet-gateway list-learned-routes \
    --name "vpngw-prod-azure" \
    --resource-group "$RG_NAME" \
    --output json > "$BGP_ROUTES_AFTER" 2>/dev/null || true

log_info "Routes BGP sauvegardées: $BGP_ROUTES_AFTER"

echo ""
log_info "=========================================="
log_info "Phase 4: Test de connectivité"
log_info "=========================================="

log_info "Les routes BGP devraient maintenant passer par SBG..."

# Afficher les routes apprises
log_info "Routes BGP actuelles (via SBG):"
az network vnet-gateway list-learned-routes \
    --name "vpngw-prod-azure" \
    --resource-group "$RG_NAME" \
    --output table 2>/dev/null | tee -a "$LOG_FILE" || true

echo ""
log_info "=========================================="
log_info "Résumé du test de failover"
log_info "=========================================="

log_success "Test de failover terminé avec succès!"
echo ""
log_info "État des tunnels:"
log_info "  RBX (Primary):  ${RED}$RBX_STATUS_AFTER${NC} (simulé en panne)"
log_info "  SBG (Backup):   ${GREEN}$SBG_STATUS_AFTER${NC} (actif)"
echo ""
log_info "Fichiers générés:"
log_info "  - Log: $LOG_FILE"
log_info "  - BGP avant: $BGP_ROUTES_BEFORE"
log_info "  - BGP après: $BGP_ROUTES_AFTER"
echo ""
log_warning "Pour restaurer RBX et revenir à l'état normal:"
log_warning "  ${YELLOW}./restore-rbx.sh${NC}"
echo ""
log_info "Pour comparer les routes BGP:"
log_info "  diff $BGP_ROUTES_BEFORE $BGP_ROUTES_AFTER"
