# Variables Ansible générées automatiquement par Terraform
# Ne pas éditer manuellement - sera régénéré

---
# Azure VPN Gateway Configuration
azure_vpn_gateway_ip: "${azure_vpn_public_ip}"
azure_vnet_cidr: "${azure_address_space}"

# On-Premises Configuration
onprem_vnet_cidr: "${onprem_address_space}"

# IPsec Configuration
ipsec_psk: "${ipsec_psk}"

# StrongSwan Configuration
strongswan_debug_level: 2
strongswan_dpddelay: 30
strongswan_dpdtimeout: 120

# IKE/ESP Parameters
ike_encryption: "aes256"
ike_integrity: "sha256"
ike_dhgroup: "modp2048"
esp_encryption: "aes256"
esp_integrity: "sha256"
ike_lifetime: "10800s"
sa_lifetime: "3600s"
