# Inventaire Ansible généré automatiquement par Terraform
# Ne pas éditer manuellement

[fortigates]
fortigate-rbx ansible_host=${rbx_fortigate_ip} fortigate_role=primary
fortigate-sbg ansible_host=${sbg_fortigate_ip} fortigate_role=backup

[fortigates:vars]
ansible_network_os=fortinet.fortios.fortios
ansible_connection=httpapi
ansible_httpapi_use_ssl=yes
ansible_httpapi_validate_certs=no
ansible_httpapi_port=443

# Azure VPN Gateway
azure_vpn_gateway_ip=${azure_vpn_gateway_ip}
azure_bgp_asn=${azure_bgp_asn}
azure_bgp_peer_primary=${azure_bgp_peer_primary}

# FortiGate common settings
wan_interface=port1
lan_interface=port2

[primary]
fortigate-rbx

[primary:vars]
fortigate_public_ip=${rbx_fortigate_ip}
fortigate_mgmt_ip=${rbx_fortigate_ip}
bgp_asn=${rbx_bgp_asn}
bgp_peer_ip=${rbx_bgp_peer_ip}
azure_bgp_peer_ip=${azure_bgp_peer_primary}
local_network_cidr=192.168.10.0/24
tunnel_name=azure-vpn-primary
policy_id=100
static_route_seq=10

[backup]
fortigate-sbg

[backup:vars]
fortigate_public_ip=${sbg_fortigate_ip}
fortigate_mgmt_ip=${sbg_fortigate_ip}
bgp_asn=${sbg_bgp_asn}
bgp_peer_ip=${sbg_bgp_peer_ip}
azure_bgp_peer_ip=${azure_bgp_peer_primary}
local_network_cidr=192.168.20.0/24
tunnel_name=azure-vpn-backup
policy_id=200
static_route_seq=20
