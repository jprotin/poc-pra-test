# Documentation Technique - POC PRA

## 📋 Table des matières

1. [Architecture technique](#architecture-technique)
2. [Spécifications des composants](#spécifications-des-composants)
3. [Configuration IPsec](#configuration-ipsec)
4. [Configuration BGP](#configuration-bgp)
5. [Réseaux et adressage](#réseaux-et-adressage)
6. [Infrastructure as Code](#infrastructure-as-code)
7. [Ansible et provisioning](#ansible-et-provisioning)
8. [Performances](#performances)

---

## Architecture technique

### Diagramme d'architecture détaillé

```
                          ┌─────────────────────────────────────┐
                          │           AZURE CLOUD               │
                          │                                     │
                          │  ┌────────────────────────────────┐ │
                          │  │    VPN Gateway (VpnGw1)       │ │
                          │  │                                │ │
                          │  │  IP Public: [Dynamic]          │ │
                          │  │  BGP ASN: 65515                │ │
                          │  │  BGP Peering: 10.1.255.4       │ │
                          │  └──────┬─────────────────┬───────┘ │
                          │         │                 │         │
                          │  ┌──────▼─────────────────▼──────┐ │
                          │  │   VNet: 10.1.0.0/16          │ │
                          │  │                                │ │
                          │  │   - GatewaySubnet: 10.1.255.0 │ │
                          │  │   - Default: 10.1.1.0/24      │ │
                          │  └────────────────────────────────┘ │
                          └──────────┬───────────────┬──────────┘
                                     │               │
                     ┌───────────────┴───────────────┴──────────────┐
                     │                                              │
          IPsec Tunnel 1 (Static)        IPsec Tunnel 2 (BGP)      IPsec Tunnel 3 (BGP)
          No BGP                          PRIMARY                   BACKUP
          DH14, AES256/SHA256            DH14, AES256/SHA256       DH14, AES256/SHA256
          PFS: None                      PFS: PFS2048              PFS: PFS2048
                     │                   LOCAL_PREF: 200           LOCAL_PREF: 100
                     │                                              │
┌────────────────────▼─────────┐  ┌──────────────▼────────┐  ┌────▼──────────────────┐
│   StrongSwan VM (On-Prem)    │  │  FortiGate RBX        │  │  FortiGate SBG        │
│                              │  │                        │  │                        │
│  IP Public: [Dynamic]        │  │  IP Public: [Static]  │  │  IP Public: [Static]  │
│  IP Private: 192.168.1.x     │  │  BGP ASN: 65001       │  │  BGP ASN: 65002       │
│  VNet: 192.168.0.0/16        │  │  BGP Peer: 169.254.30.│  │  BGP Peer: 169.254.31.│
│                              │  │                        │  │                        │
│  Ubuntu 22.04 LTS            │  │  FortiOS 7.x          │  │  FortiOS 7.x          │
│  StrongSwan 5.9+             │  │                        │  │                        │
└──────────────────────────────┘  └────────┬───────────────┘  └───────┬────────────────┘
                                           │                          │
                                           │                          │
                                      ┌────▼──────────────────────────▼────┐
                                      │      OVHCloud vRack                │
                                      │                                    │
                                      │  RBX: 192.168.10.0/24              │
                                      │  SBG: 192.168.20.0/24              │
                                      │                                    │
                                      │  VMs applicatives + MySQL          │
                                      └────────────────────────────────────┘
```

---

## Spécifications des composants

### Azure VPN Gateway

**Configuration :**
```hcl
SKU                 : VpnGw1
Type                : VPN (Route-Based)
VPN Type            : RouteBased
Active-Active       : False
BGP                 : Enabled
BGP ASN             : 65515
Generation          : Generation1
```

**Performances :**
- Bande passante : 650 Mbps max
- Tunnels S2S     : 30 max
- Latence         : ~5ms (intra-région)
- Throughput IPsec: ~500-600 Mbps (réel)

**IP Configuration :**
```
Public IP  : [Généré dynamiquement par Azure]
Private IP : 10.1.255.4 (GatewaySubnet)
```

### VM StrongSwan

**Spécifications :**
```
VM Size            : Standard_B1s
vCPU               : 1
RAM                : 1 GB
Disque OS          : 30 GB (Standard_LRS)
OS                 : Ubuntu 22.04 LTS (Jammy)
StrongSwan Version : 5.9.x
```

**Packages installés :**
- strongswan
- strongswan-pki
- libcharon-extra-plugins
- iptables
- iptables-persistent

**Configuration système :**
```bash
# IP Forwarding activé
net.ipv4.ip_forward = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
```

### FortiGate (RBX et SBG)

**Configuration :**
```
Version FortiOS : 7.x
Mode            : Transparent/NAT
Interfaces      :
  - WAN  : Connexion Internet
  - LAN  : vRack OVH
  - DMZ  : Management
```

**Features utilisées :**
- VPN IPsec (IKEv2)
- BGP (RFC 4271)
- OSPF (optionnel pour LAN)
- Firewall policies
- NAT

**Policies IPsec :**
```
Phase 1 (IKE):
  - Encryption : AES-256-CBC
  - Authentication : SHA-256
  - DH Group : 14 (2048-bit MODP)
  - Lifetime : 28800s (8h)

Phase 2 (IPsec):
  - Encryption : AES-256-CBC
  - Authentication : SHA-256
  - PFS : Group 14 (PFS2048)
  - Lifetime : 27000s (7.5h)
```

---

## Configuration IPsec

### IKEv2 Négociation

**Phase 1 - IKE SA :**

```
Proposal Azure VPN Gateway:
  encryption-algorithm : aes-cbc-256
  hash-algorithm       : sha256
  prf-algorithm        : prfsha256
  dh-group            : modp2048 (group 14)
```

**Phase 2 - IPsec SA :**

```
Proposal:
  protocol            : ESP
  encryption-algorithm : aes-cbc-256
  hash-algorithm       : hmac-sha256-128
  pfs-group           : none (StrongSwan) / modp2048 (FortiGate)
  lifetime            : 3600s (StrongSwan) / 27000s (FortiGate)
```

### Configuration StrongSwan (ipsec.conf)

```
conn azure-tunnel
    auto=start
    type=tunnel

    # Phase 1
    keyexchange=ikev2
    ike=aes256-sha256-modp2048!
    ikelifetime=28800s

    # Phase 2
    esp=aes256-sha256!
    lifetime=3600s

    # Auth
    authby=psk

    # Local (StrongSwan)
    left=%defaultroute
    leftid=<PUBLIC_IP>
    leftsubnet=192.168.0.0/16

    # Remote (Azure)
    right=<AZURE_VPN_IP>
    rightsubnet=10.1.0.0/16

    # DPD
    dpdaction=restart
    dpddelay=30s
    dpdtimeout=120s

    # Options
    closeaction=restart
    compress=no
    mobike=no
```

### Configuration FortiGate (CLI)

```fortios
config vpn ipsec phase1-interface
    edit "azure-tunnel"
        set interface "wan1"
        set peertype any
        set proposal aes256-sha256
        set dhgrp 14
        set remote-gw <AZURE_VPN_IP>
        set psksecret <PSK>
        set dpd on-idle
        set dpd-retryinterval 30
    next
end

config vpn ipsec phase2-interface
    edit "azure-tunnel-p2"
        set phase1name "azure-tunnel"
        set proposal aes256-sha256
        set pfs enable
        set dhgrp 14
        set lifetime 27000
    next
end
```

### Dead Peer Detection (DPD)

**Paramètres :**
- Mode : on-idle (FortiGate) / on-demand (StrongSwan)
- Intervalle : 30 secondes
- Timeout : 120 secondes (StrongSwan) / 90 secondes (FortiGate)

**Comportement :**
1. Pas de trafic pendant 30s → envoi DPD probe
2. Pas de réponse après 3 tentatives → tunnel déclaré DOWN
3. Action : restart automatique

---

## Configuration BGP

### Topologie BGP

```
AS 65515 (Azure)
    ├─ Neighbor: 169.254.30.2 (RBX) - AS 65001
    │  └─ Import: Local Pref 200
    │
    └─ Neighbor: 169.254.31.2 (SBG) - AS 65002
       └─ Import: Local Pref 100
```

### Configuration Azure VPN Gateway

```hcl
bgp_settings {
  asn = 65515

  peering_addresses {
    ip_configuration_name = "vnetGatewayConfig"
    apipa_addresses       = ["169.254.30.1", "169.254.31.1"]
  }
}
```

### Configuration FortiGate RBX

```fortios
config router bgp
    set as 65001
    set router-id <RBX_PUBLIC_IP>

    config neighbor
        edit "169.254.30.1"
            set remote-as 65515
            set route-map-in "azure-in"
            set route-map-out "azure-out"
        next
    end

    config network
        edit 1
            set prefix 192.168.10.0 255.255.255.0
        next
    end
end

# Route-map pour priorité
config router route-map
    edit "azure-out"
        config rule
            edit 1
                set set-local-preference 200
            next
        end
    next
end
```

### Configuration FortiGate SBG

```fortios
config router bgp
    set as 65002
    set router-id <SBG_PUBLIC_IP>

    config neighbor
        edit "169.254.31.1"
            set remote-as 65515
            set route-map-out "azure-out-backup"
        next
    end

    config network
        edit 1
            set prefix 192.168.20.0 255.255.255.0
        next
    end
end

# Route-map avec AS-PATH prepend pour backup
config router route-map
    edit "azure-out-backup"
        config rule
            edit 1
                set set-local-preference 100
                set set-aspath "65002 65002 65002"
            next
        end
    next
end
```

### Mécanisme de failover

**Normal (RBX actif) :**
```
Route Selection:
  Network: 192.168.10.0/24
  Via: RBX (169.254.30.2)
  Reason: LOCAL_PREF 200 > LOCAL_PREF 100
```

**Panne RBX (SBG actif) :**
```
1. DPD détecte panne : ~30s
2. BGP session timeout : ~90s (Hold Time)
3. Routes RBX retirées
4. Route SBG devient best path
5. Convergence totale : ~60-90s
```

**Restauration RBX :**
```
1. Tunnel IPsec rétabli
2. BGP session réétablie
3. Routes RBX réannoncées (LOCAL_PREF 200)
4. Préférence RBX > SBG
5. Trafic rebascule sur RBX
6. Convergence : ~60s
```

---

## Réseaux et adressage

### Plan d'adressage IP

| Site | Réseau | CIDR | Utilisation |
|------|--------|------|-------------|
| **Azure Hub** | | | |
| - VNet Azure | 10.1.0.0/16 | /16 | VNet principal |
| - GatewaySubnet | 10.1.255.0/24 | /24 | VPN Gateway |
| - Default Subnet | 10.1.1.0/24 | /24 | VMs de test |
| **On-Premises (StrongSwan)** | | | |
| - VNet On-Prem | 192.168.0.0/16 | /16 | Site simulé |
| - Subnet VPN | 192.168.1.0/24 | /24 | StrongSwan VM |
| **OVHCloud RBX** | | | |
| - vRack RBX | 192.168.10.0/24 | /24 | Applications |
| - BGP Peering | 169.254.30.0/30 | /30 | APIPA |
| **OVHCloud SBG** | | | |
| - vRack SBG | 192.168.20.0/24 | /24 | Applications |
| - BGP Peering | 169.254.31.0/30 | /30 | APIPA |

### Adresses APIPA (BGP Peering)

**Tunnel RBX :**
- Azure : 169.254.30.1/30
- RBX   : 169.254.30.2/30

**Tunnel SBG :**
- Azure : 169.254.31.1/30
- SBG   : 169.254.31.2/30

**StrongSwan (si BGP activé) :**
- Azure : 169.254.21.1/30
- Swan  : 169.254.21.2/30

> 💡 **Note :** Les adresses APIPA (169.254.0.0/16) sont utilisées pour le peering BGP over IPsec selon RFC 3927

---

## Infrastructure as Code

### Structure Terraform

```
terraform/
├── main.tf                    # Orchestration des modules
├── variables.tf               # 50+ variables
├── outputs.tf                 # Sorties structurées
└── terraform.tfvars          # Configuration (gitignored)

modules/
├── 01-azure-vpn-gateway/     # VPN Gateway + VNet
├── 02-strongswan-vm/          # VM Ubuntu + StrongSwan
├── 03-tunnel-ipsec-static/    # Tunnel statique
├── 04-tunnel-ipsec-bgp-rbx/   # Tunnel BGP vers RBX
├── 05-tunnel-ipsec-bgp-sbg/   # Tunnel BGP vers SBG
└── 06-ovh-vmware-infrastructure/ # (optionnel)
```

### Dépendances entre ressources

```
azurerm_virtual_network_gateway (VPN Gateway)
    ↓ depends_on
azurerm_public_ip (IP publique)
    ↓ depends_on
azurerm_subnet (GatewaySubnet)
    ↓ depends_on
azurerm_virtual_network (VNet)
    ↓ depends_on
azurerm_resource_group

Parallèle:
azurerm_linux_virtual_machine (StrongSwan)
    ↓ depends_on
azurerm_network_interface
    ↓ depends_on
azurerm_subnet (On-Prem)

Puis:
azurerm_virtual_network_gateway_connection
    ↓ depends_on (implicite)
[VPN Gateway + VM StrongSwan créés]
```

### Providers utilisés

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}
```

---

## Ansible et provisioning

### Rôles Ansible

| Rôle | Description | Fichiers |
|------|-------------|----------|
| `strongswan` | Installation StrongSwan | tasks/main.yml |
| `ipsec-config` | Configuration IPsec | tasks/main.yml, templates/ipsec.conf.j2 |
| `test-scripts` | Scripts de test | templates/*.sh.j2 |
| `fortigate-ipsec-bgp` | Config FortiGate | tasks/main.yml |

### Inventaire dynamique

Généré automatiquement par Terraform :

```ini
# ansible/inventories/dev/strongswan.ini
[strongswan]
strongswan-vm ansible_host=<IP_PUBLIC> ansible_user=azureuser

# ansible/inventories/dev/fortigates.ini
[fortigate-rbx]
fortigate-rbx ansible_host=<RBX_MGMT_IP>

[fortigate-sbg]
fortigate-sbg ansible_host=<SBG_MGMT_IP>
```

### Variables Ansible

```yaml
# group_vars/dev/strongswan.yml
azure_vpn_gateway_ip: "<AZURE_IP>"
azure_vnet_cidr: "10.1.0.0/16"
onprem_vnet_cidr: "192.168.0.0/16"
ipsec_psk: "<SECRET>"
ipsec_dh_group: "modp2048"
```

---

## Performances

### Métriques observées

**VPN Gateway VpnGw1 :**
- Throughput moyen : 500-600 Mbps
- Latence : 5-10 ms (France Central → RBX)
- Jitter : < 2 ms
- Packet loss : < 0.01%

**StrongSwan VM (B1s) :**
- Throughput : limité par VM (~80-100 Mbps)
- CPU usage : 20-30% à pleine charge
- Mémoire : 300-400 MB utilisés

**Tunnel IPsec :**
- Overhead : ~5-10% (encapsulation)
- MTU : 1400 bytes (IPsec overhead)
- Fragmentation : Évitée si MSS clamping

### Optimisations possibles

1. **Augmenter SKU VPN Gateway :**
   - VpnGw2 : 1 Gbps (~250€/mois)
   - VpnGw3 : 1.25 Gbps (~500€/mois)

2. **VM StrongSwan plus performante :**
   - Standard_B2s : 2 vCPU, 4 GB RAM (~30€/mois)
   - Meilleur throughput IPsec

3. **MSS Clamping :**
```bash
iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN \
  -j TCPMSS --clamp-mss-to-pmtu
```

4. **Offload crypto (si supporté) :**
```bash
ethtool -K eth0 tx-checksum-ipv4 off
```

---

**Auteur :** Équipe POC PRA
**Version :** 1.0
**Date :** 2025-01-16
