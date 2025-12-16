# Module Terraform : Azure VPN Gateway

## Description

Ce module Terraform crée une infrastructure Azure VPN Gateway complète comprenant :

- **Resource Group** : Groupe de ressources Azure dédié
- **Virtual Network** : Réseau virtuel Azure avec espace d'adressage configurable
- **GatewaySubnet** : Subnet dédié au VPN Gateway (nom obligatoire)
- **Subnet par défaut** : Pour les VMs de test et autres ressources
- **IP Publique** : IP publique statique Standard pour le VPN Gateway
- **VPN Gateway** : Gateway VPN avec support BGP pour routage dynamique

## Caractéristiques

- ✅ Support BGP pour routage dynamique
- ✅ Configuration APIPA personnalisable
- ✅ Mode Active-Active optionnel
- ✅ SKUs multiples (VpnGw1 à VpnGw5)
- ✅ Tags personnalisables
- ✅ Code commenté en français

## Utilisation

```hcl
module "vpn_gateway" {
  source = "./modules/01-azure-vpn-gateway"

  # Configuration du Resource Group
  resource_group_name = "rg-prod-vpn"
  location            = "francecentral"

  # Configuration du Virtual Network
  vnet_name          = "vnet-prod-azure"
  vnet_address_space = "10.1.0.0/16"
  gateway_subnet_cidr = "10.1.255.0/24"
  default_subnet_cidr = "10.1.1.0/24"

  # Configuration du VPN Gateway
  vpn_gateway_name = "vpngw-prod-azure"
  public_ip_name   = "pip-prod-vpngw"
  sku              = "VpnGw1"
  active_active    = false

  # Configuration BGP
  enable_bgp = true
  bgp_asn    = 65515

  # Tags
  tags = {
    Environment = "Production"
    Project     = "POC-PRA"
    ManagedBy   = "Terraform"
  }
}
```

## Variables

| Variable | Type | Description | Défaut | Requis |
|----------|------|-------------|--------|--------|
| `resource_group_name` | string | Nom du resource group | - | ✅ |
| `location` | string | Région Azure | `francecentral` | ❌ |
| `vnet_name` | string | Nom du Virtual Network | - | ✅ |
| `vnet_address_space` | string | CIDR du VNet | - | ✅ |
| `gateway_subnet_cidr` | string | CIDR du GatewaySubnet | - | ✅ |
| `default_subnet_cidr` | string | CIDR du subnet par défaut | - | ✅ |
| `vpn_gateway_name` | string | Nom du VPN Gateway | - | ✅ |
| `public_ip_name` | string | Nom de l'IP publique | - | ✅ |
| `sku` | string | SKU du VPN Gateway | `VpnGw1` | ❌ |
| `active_active` | bool | Mode Active-Active | `false` | ❌ |
| `enable_bgp` | bool | Activer le BGP | `true` | ❌ |
| `bgp_asn` | number | ASN BGP | `65515` | ❌ |
| `tags` | map(string) | Tags Azure | `{}` | ❌ |

## Outputs

| Output | Description |
|--------|-------------|
| `resource_group_name` | Nom du resource group |
| `vnet_id` | ID du Virtual Network |
| `vpn_gateway_id` | ID du VPN Gateway |
| `vpn_gateway_public_ip` | IP publique du VPN Gateway |
| `bgp_asn` | ASN du VPN Gateway |
| `bgp_peering_address` | Adresse de peering BGP |

## Durée de déploiement

⚠️ **IMPORTANT** : La création d'un VPN Gateway Azure prend **30 à 45 minutes**.

## Coûts estimés

| SKU | Coût/mois (France Central) |
|-----|----------------------------|
| VpnGw1 | ~90-100€ |
| VpnGw2 | ~250-280€ |
| VpnGw3 | ~500-550€ |

## Prérequis

- Terraform >= 1.5.0
- Provider Azure RM >= 3.80
- Authentification Azure CLI (`az login`)

## Exemples

### Configuration minimale

```hcl
module "vpn_gateway" {
  source = "./modules/01-azure-vpn-gateway"

  resource_group_name = "rg-dev-vpn"
  vnet_name           = "vnet-dev-azure"
  vnet_address_space  = "10.1.0.0/16"
  gateway_subnet_cidr = "10.1.255.0/24"
  default_subnet_cidr = "10.1.1.0/24"
  vpn_gateway_name    = "vpngw-dev-azure"
  public_ip_name      = "pip-dev-vpngw"
}
```

### Configuration avec BGP personnalisé

```hcl
module "vpn_gateway" {
  source = "./modules/01-azure-vpn-gateway"

  resource_group_name = "rg-prod-vpn"
  vnet_name           = "vnet-prod-azure"
  vnet_address_space  = "10.1.0.0/16"
  gateway_subnet_cidr = "10.1.255.0/24"
  default_subnet_cidr = "10.1.1.0/24"
  vpn_gateway_name    = "vpngw-prod-azure"
  public_ip_name      = "pip-prod-vpngw"

  enable_bgp = true
  bgp_asn    = 65001

  bgp_peering_addresses = {
    apipa_addresses = ["169.254.21.1", "169.254.22.1"]
  }
}
```

## Sécurité

- L'IP publique utilise le SKU Standard pour plus de sécurité
- Le BGP utilise des adresses APIPA (169.254.x.x) pour isolation
- Les NSG doivent être configurés séparément pour contrôler le trafic

## Notes

- Le nom du subnet de gateway **doit** être `GatewaySubnet`
- Le BGP nécessite un ASN dans la plage privée (64512-65534)
- Le mode Active-Active double les coûts

## Support

Pour toute question, consulter la documentation Azure :
- [VPN Gateway](https://learn.microsoft.com/fr-fr/azure/vpn-gateway/)
- [BGP avec VPN Gateway](https://learn.microsoft.com/fr-fr/azure/vpn-gateway/vpn-gateway-bgp-overview)
