#!/bin/bash
# ==============================================================================
# Utilitaire : Générer des PSK sécurisés
# ==============================================================================

echo "Génération de Pre-Shared Keys sécurisés..."
echo ""
echo "PSK StrongSwan:"
openssl rand -base64 32
echo ""
echo "PSK RBX:"
openssl rand -base64 32
echo ""
echo "PSK SBG:"
openssl rand -base64 32
echo ""
echo "Copiez ces valeurs dans terraform/terraform.tfvars"
