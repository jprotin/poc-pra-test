#!/bin/bash
# ==============================================================================
# Script de destruction : StrongSwan uniquement
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform"

echo "Destruction de l'infrastructure StrongSwan..."
cd "${TERRAFORM_DIR}"

terraform destroy \
  -target=module.tunnel_ipsec_static \
  -target=module.strongswan_vm

echo "✅ StrongSwan détruit"
