#cloud-config
# ==============================================================================
# Cloud-init Configuration - Docker Host VM
# ==============================================================================
# Description : Provisioning automatisé d'une VM Ubuntu avec Docker Engine
#               et hardening sécurité pour environnement de production
# ==============================================================================

hostname: ${hostname}
fqdn: ${hostname}.${domain}
manage_etc_hosts: true
timezone: ${timezone}

# ------------------------------------------------------------------------------
# Configuration utilisateurs
# ------------------------------------------------------------------------------
users:
  - name: ${admin_username}
    groups: sudo, docker
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ${admin_ssh_public_key}
    lock_passwd: true # Désactiver l'authentification par mot de passe

# ------------------------------------------------------------------------------
# Configuration réseau
# ------------------------------------------------------------------------------
# Note: La configuration IP statique est gérée par vSphere customization
# Cette section configure uniquement les paramètres additionnels
write_files:
  - path: /etc/netplan/99-custom-dns.yaml
    permissions: '0644'
    content: |
      network:
        version: 2
        ethernets:
          ens192:
            nameservers:
              addresses: ${dns_servers}
            dhcp4: false

# ------------------------------------------------------------------------------
# Packages à installer
# ------------------------------------------------------------------------------
packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg
  - lsb-release
  - software-properties-common
  - net-tools
  - wget
  - git
  - vim
  - htop
  - jq
  - unzip
  - fail2ban
  - ufw
  - ntp
  - chrony
  - python3
  - python3-pip

# ------------------------------------------------------------------------------
# Commandes de configuration (exécutées séquentiellement)
# ------------------------------------------------------------------------------
runcmd:
  # === Configuration système de base ===
  - echo "🚀 Démarrage configuration cloud-init pour ${hostname}"
  - timedatectl set-timezone ${timezone}
  - systemctl enable ntp && systemctl start ntp

  # === Installation Docker ===
  - echo "🐳 Installation Docker Engine ${docker_version}..."
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  - echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  - apt-get update -y
  - apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  - systemctl enable docker && systemctl start docker
  - usermod -aG docker ${admin_username}

  # === Installation Docker Compose (standalone) ===
  - echo "🔧 Installation Docker Compose ${docker_compose_version}..."
  - curl -SL "https://github.com/docker/compose/releases/download/v${docker_compose_version}/docker-compose-linux-$(uname -m)" -o /usr/local/bin/docker-compose
  - chmod +x /usr/local/bin/docker-compose
  - ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

  # === Configuration Docker daemon ===
  - mkdir -p /etc/docker
  - |
    cat <<EOF > /etc/docker/daemon.json
    {
      "log-driver": "json-file",
      "log-opts": {
        "max-size": "10m",
        "max-file": "3"
      },
      "storage-driver": "overlay2",
      "live-restore": true,
      "userland-proxy": false,
      "ipv6": false,
      "metrics-addr": "127.0.0.1:9323",
      "experimental": false
    }
    EOF
  - systemctl restart docker

  # === Hardening sécurité ===
%{ if enable_firewall ~}
  - echo "🔒 Configuration firewall UFW..."
  - ufw --force reset
  - ufw default deny incoming
  - ufw default allow outgoing
%{ for cidr in jsondecode(allowed_ssh_cidrs) ~}
  - ufw allow from ${cidr} to any port 22 proto tcp comment 'SSH'
%{ endfor ~}
  - ufw allow 80/tcp comment 'HTTP'
  - ufw allow 443/tcp comment 'HTTPS'
  - ufw --force enable
%{ endif ~}

  # === Fail2ban pour protection SSH ===
  - systemctl enable fail2ban && systemctl start fail2ban
  - |
    cat <<EOF > /etc/fail2ban/jail.local
    [sshd]
    enabled = true
    port = 22
    filter = sshd
    logpath = /var/log/auth.log
    maxretry = 3
    bantime = 3600
    findtime = 600
    EOF
  - systemctl restart fail2ban

  # === Mises à jour automatiques ===
%{ if enable_automatic_updates ~}
  - apt-get install -y unattended-upgrades
  - dpkg-reconfigure -plow unattended-upgrades
  - |
    cat <<EOF > /etc/apt/apt.conf.d/50unattended-upgrades
    Unattended-Upgrade::Allowed-Origins {
        "\${distro_id}:\${distro_codename}-security";
    };
    Unattended-Upgrade::AutoFixInterruptedDpkg "true";
    Unattended-Upgrade::MinimalSteps "true";
    Unattended-Upgrade::Remove-Unused-Dependencies "true";
    Unattended-Upgrade::Automatic-Reboot "false";
    EOF
%{ endif ~}

  # === Installation monitoring (Prometheus node_exporter + cAdvisor) ===
%{ if enable_docker_monitoring ~}
  - echo "📊 Installation node_exporter pour monitoring..."
  - wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz -O /tmp/node_exporter.tar.gz
  - tar -xvf /tmp/node_exporter.tar.gz -C /tmp
  - mv /tmp/node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
  - useradd -rs /bin/false node_exporter
  - |
    cat <<EOF > /etc/systemd/system/node_exporter.service
    [Unit]
    Description=Node Exporter
    After=network.target

    [Service]
    User=node_exporter
    Group=node_exporter
    Type=simple
    ExecStart=/usr/local/bin/node_exporter

    [Install]
    WantedBy=multi-user.target
    EOF
  - systemctl daemon-reload
  - systemctl enable node_exporter && systemctl start node_exporter

  - echo "📊 Déploiement cAdvisor pour monitoring containers..."
  - docker run -d --name=cadvisor --restart=always --privileged --device=/dev/kmsg -v /:/rootfs:ro -v /var/run:/var/run:ro -v /sys:/sys:ro -v /var/lib/docker:/var/lib/docker:ro -v /dev/disk:/dev/disk:ro -p 8080:8080 gcr.io/cadvisor/cadvisor:latest
%{ endif ~}

  # === Montage disque additionnel pour volumes Docker (si présent) ===
  - |
    if [ -b /dev/sdb ]; then
      echo "💾 Formatage et montage du disque additionnel /dev/sdb..."
      parted /dev/sdb --script mklabel gpt
      parted /dev/sdb --script mkpart primary ext4 0% 100%
      mkfs.ext4 -F /dev/sdb1
      mkdir -p /var/lib/docker-volumes
      echo '/dev/sdb1 /var/lib/docker-volumes ext4 defaults,nofail 0 2' >> /etc/fstab
      mount -a
      chown -R root:docker /var/lib/docker-volumes
      chmod 775 /var/lib/docker-volumes
    fi

  # === Logs et finalisation ===
  - echo "✅ Configuration cloud-init terminée avec succès pour ${hostname}" | tee -a /var/log/cloud-init-custom.log
  - docker --version | tee -a /var/log/cloud-init-custom.log
  - docker-compose --version | tee -a /var/log/cloud-init-custom.log
  - echo "🎉 VM Docker prête pour déploiement d'applications" | tee -a /var/log/cloud-init-custom.log

# ------------------------------------------------------------------------------
# Configuration finale et redémarrage
# ------------------------------------------------------------------------------
power_state:
  mode: reboot
  delay: now
  message: "Redémarrage après configuration cloud-init"
  timeout: 30
  condition: true
