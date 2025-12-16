# ==============================================================================
# Variables Ansible pour StrongSwan
# Générées automatiquement par Terraform
# ==============================================================================

# Azure VPN Gateway
azure_vpn_gateway_ip: "${azure_vpn_public_ip}"
azure_vnet_cidr: "${azure_vnet_cidr}"

# On-Premises Network
onprem_vnet_cidr: "${onprem_vnet_cidr}"

# IPsec Configuration
ipsec_psk: "${ipsec_psk}"

# IPsec Policy
ipsec_dh_group: "${ipsec_policy.dh_group}"
ipsec_ike_encryption: "${ipsec_policy.ike_encryption}"
ipsec_ike_integrity: "${ipsec_policy.ike_integrity}"
ipsec_esp_encryption: "${ipsec_policy.ipsec_encryption}"
ipsec_esp_integrity: "${ipsec_policy.ipsec_integrity}"
ipsec_pfs_group: "${ipsec_policy.pfs_group}"
ipsec_sa_lifetime: "${ipsec_policy.sa_lifetime}"
