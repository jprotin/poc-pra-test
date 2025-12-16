# ==============================================================================
# Inventaire Ansible pour FortiGates
# Généré automatiquement par Terraform
# ==============================================================================

%{ if deploy_rbx ~}
[fortigate-rbx]
fortigate-rbx ansible_host=${rbx_mgmt_ip} ansible_network_os=fortinet.fortios.fortios

[fortigate-rbx:vars]
fortigate_public_ip=${rbx_public_ip}
azure_vpn_gateway_ip=${azure_vpn_ip}
fortigate_role=primary
bgp_local_preference=200
%{ endif ~}

%{ if deploy_sbg ~}
[fortigate-sbg]
fortigate-sbg ansible_host=${sbg_mgmt_ip} ansible_network_os=fortinet.fortios.fortios

[fortigate-sbg:vars]
fortigate_public_ip=${sbg_public_ip}
azure_vpn_gateway_ip=${azure_vpn_ip}
fortigate_role=backup
bgp_local_preference=100
%{ endif ~}

[fortigates:children]
%{ if deploy_rbx ~}
fortigate-rbx
%{ endif ~}
%{ if deploy_sbg ~}
fortigate-sbg
%{ endif ~}
