# Audit de Sécurité - POC PRA

## 📋 Résumé exécutif

Ce document présente l'audit de sécurité complet de l'infrastructure POC PRA et les recommandations pour un déploiement en production.

### Niveau de sécurité actuel

| Composant | Niveau POC | Niveau Production Requis |
|-----------|------------|--------------------------|
| Authentification | ⚠️ Moyenne | 🔒 Élevée |
| Chiffrement | ✅ Élevée | ✅ Élevée |
| Contrôle d'accès | ⚠️ Moyenne | 🔒 Élevée |
| Gestion des secrets | ❌ Faible | 🔒 Élevée |
| Monitoring | ❌ Inexistant | 🔒 Élevée |

---

## 🔍 Analyse des Vulnérabilités

### 1. Gestion des Secrets

#### 🔴 CRITIQUE - PSK en clair dans terraform.tfvars

**Vulnérabilité :**
```hcl
# terraform.tfvars
ipsec_psk_strongswan = "mon-psk-en-clair"
```

**Risque :** Exposition des PSK si le fichier est commité dans Git.

**Impact :** ⚠️ **ÉLEVÉ** - Compromission complète des tunnels VPN

**Solution :**

```hcl
# 1. Utiliser Azure Key Vault
data "azurerm_key_vault_secret" "ipsec_psk" {
  name         = "ipsec-psk-strongswan"
  key_vault_id = azurerm_key_vault.main.id
}

# 2. Référencer le secret
variable "ipsec_psk_strongswan" {
  default = data.azurerm_key_vault_secret.ipsec_psk.value
  sensitive = true
}

# 3. Créer le secret via Azure CLI
az keyvault secret set \
  --vault-name "kv-poc-pra" \
  --name "ipsec-psk-strongswan" \
  --value "$(openssl rand -base64 32)"
```

---

### 2. Contrôle d'accès SSH

#### 🟡 MOYEN - SSH ouvert à tous (0.0.0.0/0)

**Vulnérabilité :**
```hcl
# variables.tf
variable "ssh_source_address_prefix" {
  default = "*"  # ⚠️ DANGER : SSH ouvert au monde entier
}
```

**Risque :** Attaques brute-force, exploitation de vulnérabilités SSH.

**Impact :** ⚠️ **MOYEN** - Compromission potentielle des VMs

**Solution :**

```hcl
# terraform.tfvars - PRODUCTION
ssh_source_address_prefix = "203.0.113.0/24"  # IP de votre entreprise

# Ou liste d'IPs avec NSG personnalisé
security_rule {
  name                       = "Allow-SSH-Admin"
  priority                   = 100
  source_address_prefixes    = ["203.0.113.10/32", "198.51.100.20/32"]
  destination_port_range     = "22"
  access                     = "Allow"
}
```

**Recommandations supplémentaires :**

1. **Bastion Host** :
```bash
# Utiliser Azure Bastion pour SSH
az network bastion create \
  --name bastion-poc-pra \
  --public-ip-address pip-bastion \
  --resource-group rg-dev-pra-vpn \
  --vnet-name vnet-dev-pra-azure

# Connexion sans exposition SSH publique
az network bastion ssh \
  --name bastion-poc-pra \
  --resource-group rg-dev-pra-vpn \
  --target-resource-id <vm-id> \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa
```

2. **Fail2Ban sur StrongSwan** :
```yaml
# ansible/roles/strongswan-security/tasks/main.yml
- name: Installer Fail2Ban
  apt:
    name: fail2ban
    state: present

- name: Configurer Fail2Ban pour SSH
  copy:
    content: |
      [sshd]
      enabled = true
      port = 22
      filter = sshd
      logpath = /var/log/auth.log
      maxretry = 3
      bantime = 3600
    dest: /etc/fail2ban/jail.d/sshd.conf
```

---

### 3. Chiffrement IPsec

#### ✅ CORRECT - Algorithmes de chiffrement forts

**Configuration actuelle :**
```hcl
ipsec_policy = {
  ike_encryption   = "AES256"      # ✅
  ike_integrity    = "SHA256"      # ✅
  ipsec_encryption = "AES256"      # ✅
  ipsec_integrity  = "SHA256"      # ✅
  dh_group         = "DHGroup14"   # ✅
  pfs_group        = "PFS2048"     # ✅
}
```

**Évaluation :** ✅ **CONFORME** aux standards actuels (2024)

**Recommandations pour renforcer :**

```hcl
# Configuration renforcée (2025+)
ipsec_policy_hardened = {
  ike_encryption   = "GCMAES256"   # 🔒 AES-GCM plus performant
  ike_integrity    = "GCMAES256"   # 🔒 Intégrité intégrée
  ipsec_encryption = "GCMAES256"
  ipsec_integrity  = "GCMAES256"
  dh_group         = "DHGroup24"   # 🔒 2048-bit MODP
  pfs_group        = "ECP384"      # 🔒 Courbe elliptique 384-bit
  sa_lifetime      = 1800          # 🔒 Renouvellement plus fréquent
}
```

---

### 4. Exposition des ports

#### 🟡 MOYEN - Ports IPsec ouverts à tous

**NSG actuel :**
```hcl
security_rule {
  name                       = "Allow-IKE"
  source_address_prefix      = "*"  # ⚠️ Ouvert au monde entier
  destination_port_range     = "500"
  protocol                   = "Udp"
  access                     = "Allow"
}
```

**Risque :** Scan de ports, attaques DoS sur IKE.

**Impact :** ⚠️ **MOYEN** - Disponibilité du service

**Solution - Production :**

```hcl
# Restreindre aux IPs connues
locals {
  allowed_vpn_endpoints = [
    "1.2.3.4/32",      # Azure VPN Gateway
    "5.6.7.8/32",      # FortiGate RBX
    "9.10.11.12/32",   # FortiGate SBG
  ]
}

security_rule {
  name                       = "Allow-IKE-Restricted"
  source_address_prefixes    = local.allowed_vpn_endpoints
  destination_port_range     = "500"
  protocol                   = "Udp"
  access                     = "Allow"
}
```

---

### 5. Logs et Monitoring

#### 🔴 CRITIQUE - Absence de logging centralisé

**Problème :** Aucun log centralisé, pas de monitoring des tunnels VPN.

**Risque :** Impossibilité de détecter une intrusion ou un incident.

**Impact :** ⚠️ **ÉLEVÉ** - Absence de visibilité

**Solution :**

```hcl
# 1. Activer Azure Monitor pour le VPN Gateway
resource "azurerm_monitor_diagnostic_setting" "vpn_gateway" {
  name                       = "vpn-gateway-diagnostics"
  target_resource_id         = azurerm_virtual_network_gateway.vpn.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  log {
    category = "GatewayDiagnosticLog"
    enabled  = true
  }

  log {
    category = "TunnelDiagnosticLog"
    enabled  = true
  }

  log {
    category = "RouteDiagnosticLog"
    enabled  = true
  }

  log {
    category = "IKEDiagnosticLog"
    enabled  = true
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# 2. Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-poc-pra"
  location            = azurerm_resource_group.vpn.location
  resource_group_name = azurerm_resource_group.vpn.name
  sku                 = "PerGB2018"
  retention_in_days   = 90
}
```

**Alertes recommandées :**

```bash
# Alerte si tunnel VPN down
az monitor metrics alert create \
  --name "VPN-Tunnel-Down" \
  --resource-group rg-prod-pra-vpn \
  --scopes <vpn-gateway-id> \
  --condition "avg TunnelIngressBytes < 1" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action <action-group-id>
```

---

### 6. Gestion des identités

#### 🟡 MOYEN - Pas d'identité managée

**Problème :** VMs sans identité managée pour accéder aux ressources Azure.

**Solution :**

```hcl
# Activer l'identité managée sur les VMs
resource "azurerm_linux_virtual_machine" "strongswan" {
  # ...
  identity {
    type = "SystemAssigned"
  }
}

# Donner accès au Key Vault
resource "azurerm_key_vault_access_policy" "vm" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_virtual_machine.strongswan.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}
```

---

### 7. Mise à jour et Patching

#### 🔴 CRITIQUE - Pas de gestion automatique des mises à jour

**Problème :** VMs sans système de patching automatique.

**Solution :**

```hcl
# Azure Update Management
resource "azurerm_automation_account" "main" {
  name                = "aa-poc-pra"
  location            = azurerm_resource_group.vpn.location
  resource_group_name = azurerm_resource_group.vpn.name
  sku_name            = "Basic"
}

resource "azurerm_log_analytics_linked_service" "main" {
  resource_group_name = azurerm_resource_group.vpn.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  read_access_id      = azurerm_automation_account.main.id
}

# Configuration Ansible pour auto-updates
# ansible/roles/security-updates/tasks/main.yml
- name: Configurer unattended-upgrades
  apt:
    name: unattended-upgrades
    state: present

- name: Activer les mises à jour automatiques
  copy:
    content: |
      APT::Periodic::Update-Package-Lists "1";
      APT::Periodic::Unattended-Upgrade "1";
      APT::Periodic::AutocleanInterval "7";
    dest: /etc/apt/apt.conf.d/20auto-upgrades
```

---

## 🛡️ Recommandations par Priorité

### 🔴 PRIORITÉ 1 - À faire IMMÉDIATEMENT

1. **Migrer les PSK vers Azure Key Vault**
   - Impact : Critique
   - Effort : 2 heures
   - Documentation : [Azure Key Vault](https://learn.microsoft.com/azure/key-vault/)

2. **Restreindre l'accès SSH**
   - Impact : Élevé
   - Effort : 30 minutes
   - Action : Modifier `ssh_source_address_prefix` dans terraform.tfvars

3. **Activer Azure Monitor et Log Analytics**
   - Impact : Élevé
   - Effort : 1 heure
   - Coût : ~5-10€/mois

### 🟡 PRIORITÉ 2 - À faire sous 1 semaine

4. **Restreindre les ports IPsec aux IPs connues**
   - Impact : Moyen
   - Effort : 1 heure

5. **Implémenter Azure Bastion**
   - Impact : Moyen
   - Effort : 2 heures
   - Coût : ~40€/mois

6. **Configurer Update Management**
   - Impact : Moyen
   - Effort : 2 heures

### 🟢 PRIORITÉ 3 - À faire sous 1 mois

7. **Renforcer les algorithmes IPsec (GCM)**
   - Impact : Faible (déjà sécurisé)
   - Effort : 1 heure

8. **Implémenter un WAF**
   - Impact : Moyen (si APIs exposées)
   - Effort : 4 heures

9. **Mettre en place Azure Sentinel (SIEM)**
   - Impact : Élevé (détection menaces)
   - Effort : 8 heures
   - Coût : ~100€/mois

---

## 🔒 Checklist de Sécurité Production

### Avant le déploiement

- [ ] PSK stockés dans Azure Key Vault
- [ ] SSH restreint aux IPs de l'entreprise
- [ ] Ports IPsec restreints aux endpoints connus
- [ ] Identités managées activées
- [ ] Azure Monitor configuré
- [ ] Log Analytics workspace créé
- [ ] Alertes VPN configurées
- [ ] Update Management activé
- [ ] Fail2Ban installé sur les VMs
- [ ] Azure Bastion déployé (optionnel)

### Après le déploiement

- [ ] Audit des logs pendant 7 jours
- [ ] Test de pénétration externe
- [ ] Revue des règles NSG
- [ ] Validation des alertes
- [ ] Documentation des incidents
- [ ] Formation de l'équipe d'exploitation

### Maintenance continue

- [ ] Revue mensuelle des logs
- [ ] Rotation des PSK tous les 90 jours
- [ ] Mises à jour de sécurité automatiques
- [ ] Audit trimestriel de conformité
- [ ] Test annuel de disaster recovery

---

## 📊 Conformité

### Standards respectés

- ✅ **ISO 27001** : Gestion de la sécurité de l'information
- ✅ **NIST Cybersecurity Framework** : Chiffrement et contrôle d'accès
- ⚠️ **PCI DSS** : Partiellement (logs à améliorer)
- ⚠️ **RGPD** : À valider selon les données transitées

### Recommandations conformité

1. **Chiffrement au repos** :
   ```hcl
   # Chiffrer les disques des VMs
   resource "azurerm_linux_virtual_machine" "strongswan" {
     # ...
     os_disk {
       encryption_type = "EncryptionAtRestWithPlatformKey"
     }
   }
   ```

2. **Rétention des logs** :
   ```hcl
   # Conserver les logs 1 an minimum (RGPD)
   resource "azurerm_log_analytics_workspace" "main" {
     retention_in_days = 365
   }
   ```

---

## 🚨 Plan de Réponse aux Incidents

### 1. Détection d'une intrusion

```bash
# 1. Isoler immédiatement
az network nsg rule update \
  --name Allow-SSH \
  --nsg-name nsg-strongswan \
  --resource-group rg-prod-pra-onprem \
  --access Deny

# 2. Capturer les logs
az monitor log-analytics query \
  --workspace <workspace-id> \
  --analytics-query "SecurityEvent | where TimeGenerated > ago(24h)"

# 3. Créer un snapshot
az snapshot create \
  --name snapshot-forensics-$(date +%Y%m%d) \
  --resource-group rg-prod-pra-onprem \
  --source <vm-osdisk-id>
```

### 2. Compromission d'un PSK

```bash
# 1. Générer un nouveau PSK
NEW_PSK=$(openssl rand -base64 32)

# 2. Mettre à jour Azure Key Vault
az keyvault secret set \
  --vault-name kv-poc-pra \
  --name ipsec-psk-strongswan \
  --value "$NEW_PSK"

# 3. Re-déployer avec Terraform
cd terraform
terraform apply -target=module.tunnel_ipsec_static

# 4. Re-configurer avec Ansible
cd ../ansible
ansible-playbook -i inventories/prod/strongswan.ini \
  playbooks/01-configure-strongswan.yml
```

---

## 📚 Ressources

- [Azure Security Best Practices](https://learn.microsoft.com/azure/security/fundamentals/best-practices-and-patterns)
- [IPsec Cryptographic Recommendations](https://www.rfc-editor.org/rfc/rfc8221.html)
- [NIST SP 800-77](https://csrc.nist.gov/publications/detail/sp/800-77/rev-1/final) - Guide IPsec VPN
- [Azure Key Vault Best Practices](https://learn.microsoft.com/azure/key-vault/general/best-practices)
- [CIS Azure Foundations Benchmark](https://www.cisecurity.org/benchmark/azure)

---

**Dernière révision :** 2025-01-16
**Prochaine révision :** 2025-04-16 (tous les 3 mois)
