# Inventaire Ansible généré automatiquement par Terraform
# Ne pas éditer manuellement - sera régénéré

[strongswan]
strongswan-vm ansible_host=${strongswan_public_ip} ansible_user=${admin_username}

[strongswan:vars]
strongswan_private_ip=${strongswan_private_ip}
azure_vpn_gateway_ip=${azure_vpn_public_ip}
azure_address_space=${azure_address_space}
onprem_address_space=${onprem_address_space}
ipsec_psk=${ipsec_psk}
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
