# Variables Ansible générées automatiquement par Terraform
# Ne pas éditer manuellement

---
# Azure Configuration
azure_vpn_gateway_ip: "${azure_vpn_gateway_ip}"
azure_vnet_cidr: "${azure_vnet_cidr}"
azure_bgp_asn: ${azure_bgp_asn}
azure_bgp_peer_primary: "${azure_bgp_peer_primary}"

# OVHcloud RBX (Primary)
rbx_fortigate_ip: "${rbx_fortigate_ip}"
rbx_network_cidr: "${rbx_network_cidr}"
rbx_bgp_asn: ${rbx_bgp_asn}
rbx_bgp_peer_ip: "${rbx_bgp_peer_ip}"
rbx_local_preference: ${rbx_local_preference | default(200)}
rbx_as_path_prepend: ${rbx_as_path_prepend | default(0)}

# OVHcloud SBG (Backup)
sbg_fortigate_ip: "${sbg_fortigate_ip}"
sbg_network_cidr: "${sbg_network_cidr}"
sbg_bgp_asn: ${sbg_bgp_asn}
sbg_bgp_peer_ip: "${sbg_bgp_peer_ip}"
sbg_local_preference: ${sbg_local_preference | default(100)}
sbg_as_path_prepend: ${sbg_as_path_prepend | default(3)}

# IPsec PSK
ipsec_psk_rbx: "${ipsec_psk_rbx}"
ipsec_psk_sbg: "${ipsec_psk_sbg}"

# FortiGate Common Settings
fortigate_admin_username: "admin"
wan_interface: "port1"
lan_interface: "port2"

# IPsec Parameters
ipsec_ike_version: 2
ipsec_proposal: "aes256-sha256"
ipsec_dhgroup: 14
ipsec_pfs_group: 14
ipsec_lifetime: 27000
ipsec_dpd_interval: 5
ipsec_dpd_retry: 3

# BGP Parameters
bgp_keepalive: 60
bgp_holdtime: 180
bgp_connect_timer: 30
bgp_advertisement_interval: 30
