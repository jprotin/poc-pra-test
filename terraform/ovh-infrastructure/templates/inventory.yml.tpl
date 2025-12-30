# ==============================================================================
# Ansible Inventory - Généré automatiquement par Terraform
# ==============================================================================

all:
  vars:
    ansible_user: ${admin_username}
    ansible_python_interpreter: /usr/bin/python3

  children:
    docker_vms:
      hosts:
        docker-rbx:
          ansible_host: ${docker_rbx_ip}
          site: rbx
          role: docker-host

        docker-sbg:
          ansible_host: ${docker_sbg_ip}
          site: sbg
          role: docker-host

    mysql_vms:
      hosts:
        mysql-rbx:
          ansible_host: ${mysql_rbx_ip}
          site: rbx
          role: mysql-database

        mysql-sbg:
          ansible_host: ${mysql_sbg_ip}
          site: sbg
          role: mysql-database

    rbx_site:
      hosts:
        docker-rbx:
        mysql-rbx:

    sbg_site:
      hosts:
        docker-sbg:
        mysql-sbg:
