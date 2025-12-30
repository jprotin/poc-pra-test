#cloud-config
# ==============================================================================
# Cloud-init Configuration - MySQL Database VM
# ==============================================================================
# Description : Provisioning automatisé d'une VM Ubuntu avec MySQL 8.0
#               optimisée pour production avec hardening sécurité
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
    groups: sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ${admin_ssh_public_key}
    lock_passwd: true

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
  - vim
  - htop
  - jq
  - fail2ban
  - ufw
  - ntp
  - chrony
  - python3
  - python3-pip
  - lvm2
  - parted

# ------------------------------------------------------------------------------
# Fichiers de configuration
# ------------------------------------------------------------------------------
write_files:
  # Configuration DNS
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

  # Configuration MySQL my.cnf optimisée
  - path: /etc/mysql/mysql.conf.d/zz-custom.cnf
    permissions: '0644'
    content: |
      [mysqld]
      # === Configuration réseau ===
      bind-address = 0.0.0.0
      port = 3306
      max_connections = ${mysql_max_connections}

      # === Performance InnoDB ===
      innodb_buffer_pool_size = ${mysql_innodb_buffer_pool}
      innodb_log_file_size = 512M
      innodb_flush_log_at_trx_commit = 2
      innodb_flush_method = O_DIRECT
      innodb_file_per_table = 1

      # === Logging ===
      log_error = /var/log/mysql/error.log
      slow_query_log = 1
      slow_query_log_file = /var/log/mysql/slow-query.log
      long_query_time = 2

      # === Binary Log (pour réplication future) ===
      server-id = 1
      log_bin = /var/log/mysql/mysql-bin.log
      binlog_format = ROW
      expire_logs_days = 7
      max_binlog_size = 100M

      # === Charset ===
      character-set-server = utf8mb4
      collation-server = utf8mb4_unicode_ci

      [client]
      default-character-set = utf8mb4

  # Script de backup MySQL
  - path: /usr/local/bin/mysql-backup.sh
    permissions: '0750'
    owner: root:root
    content: |
      #!/bin/bash
      # Script de backup automatique MySQL
      BACKUP_DIR="/var/backups/mysql"
      RETENTION_DAYS=${mysql_backup_retention_days}
      TIMESTAMP=$(date +%Y%m%d_%H%M%S)

      mkdir -p $BACKUP_DIR

      # Backup de toutes les bases de données
      mysqldump --all-databases --single-transaction --quick \
                --lock-tables=false --routines --triggers \
                --events --set-gtid-purged=OFF \
                --result-file=$BACKUP_DIR/mysql-all-$TIMESTAMP.sql

      # Compression
      gzip $BACKUP_DIR/mysql-all-$TIMESTAMP.sql

      # Rotation (suppression anciens backups)
      find $BACKUP_DIR -name "mysql-all-*.sql.gz" -mtime +$RETENTION_DAYS -delete

      echo "✅ Backup MySQL terminé: mysql-all-$TIMESTAMP.sql.gz"

  # Fichier .my.cnf pour root (credentials MySQL)
  - path: /root/.my.cnf
    permissions: '0600'
    owner: root:root
    content: |
      [client]
      user=root
      password=${mysql_root_password}

# ------------------------------------------------------------------------------
# Commandes de configuration (exécutées séquentiellement)
# ------------------------------------------------------------------------------
runcmd:
  # === Configuration système de base ===
  - echo "🚀 Démarrage configuration cloud-init pour ${hostname}"
  - timedatectl set-timezone ${timezone}
  - systemctl enable ntp && systemctl start ntp

  # === Préparation disque de données MySQL (/dev/sdb) ===
  - echo "💾 Configuration disque de données MySQL..."
  - parted /dev/sdb --script mklabel gpt
  - parted /dev/sdb --script mkpart primary ext4 0% 100%
  - mkfs.ext4 -F /dev/sdb1
  - mkdir -p /var/lib/mysql-data
  - echo '/dev/sdb1 /var/lib/mysql-data ext4 defaults,nofail,noatime 0 2' >> /etc/fstab
  - mount -a

  # === Préparation disque de logs MySQL (/dev/sdc si présent) ===
  - |
    if [ -b /dev/sdc ]; then
      echo "💾 Configuration disque de logs MySQL..."
      parted /dev/sdc --script mklabel gpt
      parted /dev/sdc --script mkpart primary ext4 0% 100%
      mkfs.ext4 -F /dev/sdc1
      mkdir -p /var/log/mysql-logs
      echo '/dev/sdc1 /var/log/mysql-logs ext4 defaults,nofail,noatime 0 2' >> /etc/fstab
      mount -a
    fi

  # === Installation MySQL ${mysql_version} ===
  - echo "🐬 Installation MySQL ${mysql_version}..."
  - wget https://dev.mysql.com/get/mysql-apt-config_0.8.29-1_all.deb -O /tmp/mysql-apt-config.deb
  - DEBIAN_FRONTEND=noninteractive dpkg -i /tmp/mysql-apt-config.deb
  - apt-get update -y
  - DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server mysql-client

  # === Configuration initiale MySQL ===
  - systemctl stop mysql
  - |
    # Migration données MySQL vers disque dédié
    if [ -d /var/lib/mysql-data ]; then
      rsync -av /var/lib/mysql/ /var/lib/mysql-data/
      mv /var/lib/mysql /var/lib/mysql.bak
      ln -s /var/lib/mysql-data /var/lib/mysql
      chown -R mysql:mysql /var/lib/mysql-data
    fi
  - |
    # Migration logs MySQL vers disque dédié (si présent)
    if [ -d /var/log/mysql-logs ]; then
      mkdir -p /var/log/mysql-logs
      chown -R mysql:mysql /var/log/mysql-logs
      ln -sf /var/log/mysql-logs /var/log/mysql
    fi
  - systemctl start mysql
  - systemctl enable mysql

  # === Sécurisation MySQL (équivalent mysql_secure_installation) ===
  - |
    mysql -u root <<EOF
    ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${mysql_root_password}';
    DELETE FROM mysql.user WHERE User='';
    DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
    DROP DATABASE IF EXISTS test;
    DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
    FLUSH PRIVILEGES;
    EOF

  # === Création base de données et utilisateur applicatif ===
%{ if mysql_database_name != "" ~}
  - |
    mysql -u root -p'${mysql_root_password}' <<EOF
    CREATE DATABASE IF NOT EXISTS ${mysql_database_name} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    CREATE USER IF NOT EXISTS '${mysql_app_user}'@'localhost' IDENTIFIED BY '${mysql_app_password}';
%{ for host in jsondecode(mysql_allowed_hosts) ~}
    CREATE USER IF NOT EXISTS '${mysql_app_user}'@'${host}' IDENTIFIED BY '${mysql_app_password}';
    GRANT ALL PRIVILEGES ON ${mysql_database_name}.* TO '${mysql_app_user}'@'${host}';
%{ endfor ~}
    FLUSH PRIVILEGES;
    EOF
%{ endif ~}

  # === Hardening sécurité ===
%{ if enable_firewall ~}
  - echo "🔒 Configuration firewall UFW..."
  - ufw --force reset
  - ufw default deny incoming
  - ufw default allow outgoing
%{ for cidr in jsondecode(allowed_ssh_cidrs) ~}
  - ufw allow from ${cidr} to any port 22 proto tcp comment 'SSH'
%{ endfor ~}
%{ for cidr in jsondecode(allowed_mysql_cidrs) ~}
  - ufw allow from ${cidr} to any port 3306 proto tcp comment 'MySQL'
%{ endfor ~}
  - ufw --force enable
%{ endif ~}

  # === Fail2ban pour protection SSH ===
  - systemctl enable fail2ban && systemctl start fail2ban

  # === Mises à jour automatiques ===
%{ if enable_automatic_updates ~}
  - apt-get install -y unattended-upgrades
  - dpkg-reconfigure -plow unattended-upgrades
%{ endif ~}

  # === Configuration backups MySQL ===
%{ if enable_mysql_backup ~}
  - echo "📦 Configuration backups MySQL..."
  - mkdir -p /var/backups/mysql
  - chmod 700 /var/backups/mysql
  - chmod +x /usr/local/bin/mysql-backup.sh
  # Cron quotidien à 02h00
  - echo "0 2 * * * root /usr/local/bin/mysql-backup.sh >> /var/log/mysql-backup.log 2>&1" >> /etc/crontab
%{ endif ~}

  # === Installation monitoring (mysqld_exporter pour Prometheus) ===
%{ if enable_mysql_monitoring ~}
  - echo "📊 Installation mysqld_exporter..."
  - wget https://github.com/prometheus/mysqld_exporter/releases/download/v0.15.1/mysqld_exporter-0.15.1.linux-amd64.tar.gz -O /tmp/mysqld_exporter.tar.gz
  - tar -xvf /tmp/mysqld_exporter.tar.gz -C /tmp
  - mv /tmp/mysqld_exporter-0.15.1.linux-amd64/mysqld_exporter /usr/local/bin/
  - useradd -rs /bin/false mysqld_exporter
  # Créer utilisateur MySQL pour exporter
  - |
    mysql -u root -p'${mysql_root_password}' <<EOF
    CREATE USER IF NOT EXISTS 'exporter'@'localhost' IDENTIFIED BY 'exporter_password' WITH MAX_USER_CONNECTIONS 3;
    GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'localhost';
    FLUSH PRIVILEGES;
    EOF
  # Créer fichier credentials
  - |
    cat <<EOF > /etc/.mysqld_exporter.cnf
    [client]
    user=exporter
    password=exporter_password
    EOF
  - chmod 600 /etc/.mysqld_exporter.cnf
  # Service systemd
  - |
    cat <<EOF > /etc/systemd/system/mysqld_exporter.service
    [Unit]
    Description=MySQL Exporter
    After=network.target mysql.service

    [Service]
    User=mysqld_exporter
    Group=mysqld_exporter
    Type=simple
    ExecStart=/usr/local/bin/mysqld_exporter --config.my-cnf=/etc/.mysqld_exporter.cnf

    [Install]
    WantedBy=multi-user.target
    EOF
  - systemctl daemon-reload
  - systemctl enable mysqld_exporter && systemctl start mysqld_exporter

  # Installation node_exporter
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
%{ endif ~}

  # === Logs et finalisation ===
  - echo "✅ Configuration cloud-init terminée avec succès pour ${hostname}" | tee -a /var/log/cloud-init-custom.log
  - mysql --version | tee -a /var/log/cloud-init-custom.log
  - systemctl status mysql --no-pager | tee -a /var/log/cloud-init-custom.log
  - echo "🎉 VM MySQL prête pour applications" | tee -a /var/log/cloud-init-custom.log

# ------------------------------------------------------------------------------
# Configuration finale et redémarrage
# ------------------------------------------------------------------------------
power_state:
  mode: reboot
  delay: now
  message: "Redémarrage après configuration cloud-init MySQL"
  timeout: 30
  condition: true
