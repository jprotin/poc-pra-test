#!/bin/bash

# restore-rbx.sh - Restauration du site RBX (Primary) et retour à l'état normal
# Ce script restaure le tunnel IPsec RBX et force le retour du trafic sur la route primaire

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
LOG_FILE="${SCRIPT_DIR}/restore-test-$(date +%Y%m%d-%H%M%S).log"

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
echo -e "${GREEN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║        RESTAURATION DU SITE RBX (PRIMARY)               ║
║         Retour à l'état normal du routage BGP           ║
╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

log_info "Début de la restauration RBX"
log_info "Logs sauvegardés dans: $LOG_FILE"

# Charger les variables Terraform
cd "$TERRAFORM_DIR"

if [ ! -f "terraform.tfstate" ]; then
    log_error "Fichier terraform.tfstate introuvable."
    exit 1
fi

# Récupérer les informations
log_info "Récupération des informations de configuration..."

RG_NAME=$(terraform output -raw resource_groups 2>/dev/null | jq -r '.azure' || echo "")
RBX_CONN_NAME="conn-prod-azure-rbx-primary"
SBG_CONN_NAME="conn-prod-azure-sbg-backup"

# Récupérer le PSK original depuis terraform.tfvars
ORIGINAL_PSK_RBX=$(grep '^ipsec_psk_rbx' terraform.tfvars | cut -d'"' -f2)

if [ -z "$ORIGINAL_PSK_RBX" ]; then
    log_error "Impossible de récupérer le PSK original depuis terraform.tfvars"
    log_info "Vous devrez peut-être restaurer manuellement avec:"
    log_info "  az network vpn-connection shared-key update --connection-name $RBX_CONN_NAME --resource-group $RG_NAME --value 'VOTRE_PSK'"
    exit 1
fi

log_success "Configuration chargée:"
log_info "  Resource Group: $RG_NAME"
log_info "  RBX Connection: $RBX_CONN_NAME"
log_info "  SBG Connection: $SBG_CONN_NAME"

echo ""
log_info "=========================================="
log_info "Phase 1: État actuel"
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

if [ "$RBX_STATUS" = "Connected" ]; then
    log_warning "Le tunnel RBX est déjà connecté. Vérifiez si une restauration est nécessaire."
    read -p "Voulez-vous forcer la restauration? (oui/non): " force_restore
    if [ "$force_restore" != "oui" ]; then
        log_info "Restauration annulée"
        exit 0
    fi
fi

echo ""
log_info "Récupération des routes BGP avant restauration..."

BGP_ROUTES_BEFORE="${SCRIPT_DIR}/bgp-routes-before-restore-$(date +%Y%m%d-%H%M%S).json"
az network vnet-gateway list-learned-routes \
    --name "vpngw-prod-azure" \
    --resource-group "$RG_NAME" \
    --output json > "$BGP_ROUTES_BEFORE" 2>/dev/null || true

log_info "Routes BGP sauvegardées: $BGP_ROUTES_BEFORE"

echo ""
log_info "=========================================="
log_info "Phase 2: Restauration du tunnel RBX"
log_info "=========================================="

log_info "Restauration du Shared Key RBX..."

az network vpn-connection shared-key update \
    --resource-group "$RG_NAME" \
    --connection-name "$RBX_CONN_NAME" \
    --value "$ORIGINAL_PSK_RBX" \
    --output none

log_success "Shared Key RBX restauré"

# Si BGP était désactivé, le réactiver
log_info "Vérification de la configuration BGP..."
az network vpn-connection update \
    --name "$RBX_CONN_NAME" \
    --resource-group "$RG_NAME" \
    --set enableBgp=true \
    --output none 2>/dev/null || true

log_success "Configuration RBX restaurée"

echo ""
log_info "Attente de la reconnexion du tunnel (60 secondes)..."
for i in {60..1}; do
    echo -ne "  Temps restant: ${i}s\r"
    sleep 1
done
echo ""

echo ""
log_info "=========================================="
log_info "Phase 3: Vérification de la reconnexion"
log_info "=========================================="

log_info "Vérification du statut des tunnels..."

# Vérifier plusieurs fois (peut prendre du temps)
MAX_ATTEMPTS=6
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    RBX_STATUS_AFTER=$(az network vpn-connection show \
        --name "$RBX_CONN_NAME" \
        --resource-group "$RG_NAME" \
        --query connectionStatus -o tsv 2>/dev/null || echo "Unknown")
    
    log_info "Tentative $ATTEMPT/$MAX_ATTEMPTS - RBX Status: $RBX_STATUS_AFTER"
    
    if [ "$RBX_STATUS_AFTER" = "Connected" ]; then
        break
    fi
    
    if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
        log_info "Attente de 30 secondes avant nouvelle tentative..."
        sleep 30
    fi
    
    ATTEMPT=$((ATTEMPT + 1))
done

SBG_STATUS_AFTER=$(az network vpn-connection show \
    --name "$SBG_CONN_NAME" \
    --resource-group "$RG_NAME" \
    --query connectionStatus -o tsv 2>/dev/null || echo "Unknown")

echo ""
if [ "$RBX_STATUS_AFTER" = "Connected" ]; then
    log_success "✓ RESTAURATION RÉUSSIE!"
    log_success "  - RBX (Primary): ${GREEN}$RBX_STATUS_AFTER${NC}"
    log_success "  - SBG (Backup):  ${GREEN}$SBG_STATUS_AFTER${NC}"
else
    log_error "✗ Le tunnel RBX n'a pas pu se reconnecter"
    log_error "  - RBX Status: $RBX_STATUS_AFTER"
    log_info "Actions de dépannage:"
    log_info "  1. Vérifier les logs Azure: az monitor activity-log list ..."
    log_info "  2. Vérifier la configuration FortiGate RBX"
    log_info "  3. Vérifier le PSK sur le FortiGate"
    exit 1
fi

echo ""
log_info "Attente de la convergence BGP (90 secondes)..."
log_info "BGP doit reconverger pour préférer RBX (LOCAL_PREF 200) sur SBG (LOCAL_PREF 100)..."
sleep 90

echo ""
log_info "=========================================="
log_info "Phase 4: Vérification du retour à la normale"
log_info "=========================================="

log_info "Récupération des routes BGP après restauration..."

BGP_ROUTES_AFTER="${SCRIPT_DIR}/bgp-routes-after-restore-$(date +%Y%m%d-%H%M%S).json"
az network vnet-gateway list-learned-routes \
    --name "vpngw-prod-azure" \
    --resource-group "$RG_NAME" \
    --output json > "$BGP_ROUTES_AFTER" 2>/dev/null || true

log_info "Routes BGP sauvegardées: $BGP_ROUTES_AFTER"

echo ""
log_info "Routes BGP actuelles (via RBX + SBG):"
az network vnet-gateway list-learned-routes \
    --name "vpngw-prod-azure" \
    --resource-group "$RG_NAME" \
    --output table 2>/dev/null | tee -a "$LOG_FILE" || true

echo ""
log_info "=========================================="
log_info "Phase 5: Vérification de la préférence de route"
log_info "=========================================="

log_info "Analyse de la préférence des routes BGP..."

# Extraire les routes et leurs métriques
ROUTES_JSON=$(az network vnet-gateway list-learned-routes \
    --name "vpngw-prod-azure" \
    --resource-group "$RG_NAME" \
    --output json 2>/dev/null || echo "[]")

# Chercher les routes vers les réseaux OVH
RBX_ROUTES=$(echo "$ROUTES_JSON" | jq -r '.value[] | select(.network == "192.168.10.0/24") | .asPath' 2>/dev/null | head -1)
SBG_ROUTES=$(echo "$ROUTES_JSON" | jq -r '.value[] | select(.network == "192.168.20.0/24") | .asPath' 2>/dev/null | head -1)

if [ ! -z "$RBX_ROUTES" ]; then
    RBX_AS_PATH_LENGTH=$(echo "$RBX_ROUTES" | tr '-' '\n' | wc -l)
    log_info "Route RBX (192.168.10.0/24): AS-PATH length = $RBX_AS_PATH_LENGTH"
else
    log_warning "Route RBX non trouvée dans la table BGP"
fi

if [ ! -z "$SBG_ROUTES" ]; then
    SBG_AS_PATH_LENGTH=$(echo "$SBG_ROUTES" | tr '-' '\n' | wc -l)
    log_info "Route SBG (192.168.20.0/24): AS-PATH length = $SBG_AS_PATH_LENGTH"
else
    log_warning "Route SBG non trouvée dans la table BGP"
fi

echo ""
log_info "=========================================="
log_info "Résumé de la restauration"
log_info "=========================================="

log_success "Restauration terminée avec succès!"
echo ""
log_info "État des tunnels:"
log_info "  RBX (Primary):  ${GREEN}$RBX_STATUS_AFTER${NC} (restauré)"
log_info "  SBG (Backup):   ${GREEN}$SBG_STATUS_AFTER${NC} (actif en backup)"
echo ""
log_info "Configuration BGP:"
log_info "  RBX - LOCAL_PREF: 200 (route préférée)"
log_info "  SBG - LOCAL_PREF: 100 (route backup)"
echo ""
log_info "Le trafic doit maintenant passer prioritairement par RBX (Primary)"
log_info "SBG reste disponible comme backup en cas de nouvelle panne"
echo ""
log_info "Fichiers générés:"
log_info "  - Log: $LOG_FILE"
log_info "  - BGP avant: $BGP_ROUTES_BEFORE"
log_info "  - BGP après: $BGP_ROUTES_AFTER"
echo ""
log_info "Pour resimule une panne:"
log_info "  ${YELLOW}./simulate-rbx-failure.sh${NC}"
echo ""
log_info "Pour comparer les routes BGP:"
log_info "  diff $BGP_ROUTES_BEFORE $BGP_ROUTES_AFTER"
