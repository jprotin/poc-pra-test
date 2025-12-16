# ==============================================================================
# Inventaire Ansible pour StrongSwan
# Généré automatiquement par Terraform
# ==============================================================================

[strongswan]
strongswan-vm ansible_host=${strongswan_public_ip} ansible_user=${admin_username} ansible_python_interpreter=/usr/bin/python3

[strongswan:vars]
strongswan_private_ip=${strongswan_private_ip}
