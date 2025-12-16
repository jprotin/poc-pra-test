# Documentation Fonctionnelle - POC PRA

## 📋 Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Objectifs du POC](#objectifs-du-poc)
3. [Architecture fonctionnelle](#architecture-fonctionnelle)
4. [Cas d'usage](#cas-dusage)
5. [Flux de données](#flux-de-données)
6. [Scénarios de test](#scénarios-de-test)
7. [Bénéfices attendus](#bénéfices-attendus)

---

## Vue d'ensemble

### Contexte

Ce POC (Proof of Concept) démontre la mise en place d'un **Plan de Reprise d'Activité (PRA)** utilisant une infrastructure hybride entre **Azure** (cloud public) et **OVHCloud** (infrastructure privée) avec des tunnels VPN IPsec sécurisés et du routage dynamique BGP.

### Problématique adressée

Les entreprises ont besoin de :
- **Haute disponibilité** : Continuité de service même en cas de panne
- **Résilience géographique** : Sites de secours dans des datacenters différents
- **Basculement automatique** : Failover sans intervention manuelle
- **Sécurité** : Chiffrement des communications inter-sites
- **Flexibilité** : Capacité à utiliser plusieurs clouds (multi-cloud)

### Solution proposée

Une architecture hybride comprenant :
- **Hub Azure** : VPN Gateway avec support BGP pour routage dynamique
- **Site on-premises simulé** : VM StrongSwan pour tests
- **Sites OVHCloud** : 2 datacenters (RBX + SBG) avec FortiGate
- **Tunnels IPsec** : Connexions sécurisées chiffrées
- **BGP** : Routage dynamique avec failover automatique

---

## Objectifs du POC

### Objectifs fonctionnels

1. **Connectivité hybride sécurisée**
   - Établir des tunnels IPsec entre Azure et les sites distants
   - Chiffrement AES-256 pour toutes les communications
   - Authentification par Pre-Shared Key (PSK)

2. **Haute disponibilité géographique**
   - 2 sites OVHCloud : RBX (Roubaix) et SBG (Strasbourg)
   - Redondance géographique en cas de panne datacenter
   - Failover automatique en moins de 2 minutes

3. **Routage dynamique intelligent**
   - Utilisation de BGP pour annoncer les routes
   - Priorité sur RBX (PRIMARY) avec LOCAL_PREF 200
   - Basculement automatique sur SBG (BACKUP) avec LOCAL_PREF 100

4. **Simulation on-premises**
   - VM StrongSwan simulant un site distant
   - Tunnel IPsec statique pour tests de base
   - Validation de la compatibilité inter-vendors

### Objectifs techniques

1. **Infrastructure as Code (IaC)**
   - 100% du code en Terraform pour reproductibilité
   - Provisioning automatisé avec Ansible
   - Scripts de déploiement modulaires

2. **Documentation complète**
   - Guide de déploiement pas à pas
   - Architecture technique détaillée
   - Audit de sécurité complet

3. **Modularité**
   - Modules Terraform indépendants
   - Déploiement par brique fonctionnelle
   - Possibilité de déployer partiellement

---

## Architecture fonctionnelle

### Vue globale

```
┌──────────────────────────────────────────────────────────────┐
│                         INTERNET                              │
└───────┬─────────────────┬────────────────┬────────────────────┘
        │                 │                │
        │                 │                │
┌───────▼─────────┐ ┌─────▼──────┐  ┌─────▼──────┐
│   Azure Cloud   │ │ OVH RBX    │  │  OVH SBG   │
│                 │ │ (Primary)  │  │  (Backup)  │
│  VPN Gateway    │ │            │  │            │
│  BGP: AS 65515  │ │ FortiGate  │  │ FortiGate  │
│                 │ │ BGP AS 6500│  │ BGP AS 6500│
└───────┬─────────┘ └─────┬──────┘  └─────┬──────┘
        │                 │                │
        │  IPsec/BGP      │   IPsec/BGP   │
        └─────────────────┴────────────────┘
                Failover automatique
```

### Composants fonctionnels

| Composant | Rôle | Fonction |
|-----------|------|----------|
| **Azure VPN Gateway** | Hub central | Point de convergence de tous les tunnels |
| **StrongSwan VM** | Site on-prem simulé | Test de compatibilité, validation |
| **FortiGate RBX** | Site primaire | Production normale, priorité haute |
| **FortiGate SBG** | Site backup | Secours automatique en cas de panne RBX |
| **BGP** | Routage dynamique | Failover automatique sans intervention |

---

## Cas d'usage

### Cas d'usage 1 : Fonctionnement normal

**Contexte :** Tous les sites sont opérationnels

**Flux :**
1. Application Azure initie une connexion vers RBX
2. VPN Gateway consulte sa table de routage BGP
3. Route RBX choisie (LOCAL_PREF 200 > 100)
4. Trafic transite par le tunnel Azure ↔ RBX
5. Réponse retourne par le même chemin

**Résultat :** Latence optimale via le chemin primaire

### Cas d'usage 2 : Panne du site RBX

**Contexte :** Datacenter RBX hors service (panne électrique, réseau, etc.)

**Flux :**
1. Tunnel Azure ↔ RBX tombe (DPD détecte en 30s)
2. BGP retire les routes RBX de la table de routage
3. Seules les routes SBG restent disponibles
4. VPN Gateway bascule automatiquement sur SBG
5. Applications continuent de fonctionner via SBG

**Résultat :** Failover automatique en ~60-90 secondes

**Durée d'interruption :** < 2 minutes

### Cas d'usage 3 : Restauration du site RBX

**Contexte :** RBX revient en ligne après maintenance

**Flux :**
1. Tunnel Azure ↔ RBX se rétablit
2. BGP réannonce les routes RBX (LOCAL_PREF 200)
3. VPN Gateway compare : 200 (RBX) > 100 (SBG)
4. Trafic rebascule progressivement sur RBX
5. SBG redevient backup

**Résultat :** Retour automatique sur le site primaire

### Cas d'usage 4 : Test de connectivité depuis on-premises

**Contexte :** Validation du tunnel StrongSwan

**Flux :**
1. VM on-premises envoie un ping vers Azure (10.1.1.10)
2. StrongSwan encapsule le paquet dans IPsec
3. Paquet chiffré transite vers Azure VPN Gateway
4. Gateway déchiffre et route vers le réseau Azure
5. Réponse suit le chemin inverse

**Résultat :** Validation de la connectivité end-to-end

---

## Flux de données

### Flux 1 : Établissement du tunnel IPsec (IKE Phase 1 & 2)

```
┌──────────────┐                           ┌──────────────┐
│  StrongSwan  │                           │ Azure VPN GW │
│  (On-prem)   │                           │              │
└──────┬───────┘                           └──────┬───────┘
       │                                          │
       │ 1. IKE_SA_INIT (proposal, nonce)         │
       │──────────────────────────────────────────>│
       │                                          │
       │ 2. IKE_SA_INIT (accept, nonce)           │
       │<──────────────────────────────────────────│
       │                                          │
       │ 3. IKE_AUTH (ID, AUTH, SA)               │
       │──────────────────────────────────────────>│
       │                                          │
       │ 4. IKE_AUTH (ID, AUTH, SA)               │
       │<──────────────────────────────────────────│
       │                                          │
       │        TUNNEL ÉTABLI (ESTABLISHED)        │
       │<==========================================>│
```

**Étapes :**
1. Échange de propositions cryptographiques
2. Authentification mutuelle avec PSK
3. Création des Security Associations (SA)
4. Tunnel opérationnel

### Flux 2 : Annonce BGP et sélection de route

```
RBX (PRIMARY)              Azure VPN GW          SBG (BACKUP)
AS 65001                   AS 65515              AS 65002
    │                          │                      │
    │ BGP UPDATE               │                      │
    │ Network: 192.168.10.0/24 │                      │
    │ AS-Path: 65001           │                      │
    │ LOCAL_PREF: 200          │                      │
    │─────────────────────────>│                      │
    │                          │                      │
    │                          │   BGP UPDATE         │
    │                          │   Network: 192.168.20│
    │                          │   AS-Path: 65002-65002│
    │                          │   LOCAL_PREF: 100    │
    │                          │<─────────────────────│
    │                          │                      │
    │  SÉLECTION DE ROUTE :    │                      │
    │  200 > 100               │                      │
    │  => RBX CHOISI           │                      │
```

### Flux 3 : Trafic applicatif (Azure → OVH)

```
Application Azure          Tunnel IPsec          Application OVH RBX
10.1.1.10                                        192.168.10.10
    │                                                  │
    │ 1. HTTP Request (10.1.1.10 → 192.168.10.10)     │
    │──────────────────────────────────────────────────>│
    │                                                  │
    │ 2. ESP (encapsulated, encrypted)                │
    │━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━>│
    │                                                  │
    │ 3. HTTP Response (192.168.10.10 → 10.1.1.10)    │
    │<──────────────────────────────────────────────────│
    │                                                  │
    │ 4. ESP (encapsulated, encrypted)                │
    │<━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│
```

**Chiffrement :** Tout le trafic applicatif est chiffré en AES-256

---

## Scénarios de test

### Scénario 1 : Validation de la connectivité de base

**Objectif :** Vérifier que les tunnels s'établissent correctement

**Étapes :**
1. Déployer l'infrastructure (`./deploy.sh --all`)
2. Attendre 45 minutes (création VPN Gateway)
3. Vérifier le statut : `./scripts/test/check-vpn-status.sh`
4. SSH vers StrongSwan : `ssh azureuser@<ip>`
5. Tester le tunnel : `sudo /usr/local/bin/test-ipsec.sh`

**Résultat attendu :**
- ✅ Tunnel StrongSwan : Connected
- ✅ Tunnel RBX : Connected
- ✅ Tunnel SBG : Connected

### Scénario 2 : Test de failover RBX → SBG

**Objectif :** Valider le basculement automatique

**Étapes :**
1. Vérifier routes initiales : `az network vnet-gateway list-learned-routes ...`
2. Générer du trafic continu vers RBX
3. Simuler panne RBX : `./scripts/test/simulate-rbx-failure.sh`
4. Observer le failover (monitoring BGP)
5. Vérifier que SBG devient actif
6. Restaurer RBX : arrêter la simulation
7. Vérifier le retour sur RBX

**Résultat attendu :**
- Failover en < 90 secondes
- Aucune perte de paquets excessive
- Retour automatique sur RBX

### Scénario 3 : Test de performance

**Objectif :** Mesurer débit et latence

**Étapes :**
1. Installer iperf3 sur Azure et OVH
2. Lancer serveur iperf3 sur OVH : `iperf3 -s`
3. Tester depuis Azure : `iperf3 -c 192.168.10.10 -t 60`
4. Mesurer latence : `ping -c 100 192.168.10.10`

**Résultat attendu :**
- Débit : dépend du SKU VPN Gateway (VpnGw1 : ~650 Mbps)
- Latence : ~5-10ms (France Central → Roubaix)

### Scénario 4 : Test de sécurité

**Objectif :** Valider le chiffrement

**Étapes :**
1. Capturer trafic avec tcpdump : `tcpdump -i eth0 -w capture.pcap`
2. Générer du trafic applicatif
3. Analyser avec Wireshark
4. Vérifier que le payload est chiffré (ESP)

**Résultat attendu :**
- Paquets ESP visibles (protocol 50)
- Payload non déchiffrable sans les clés

---

## Bénéfices attendus

### Bénéfices techniques

| Bénéfice | Description | Valeur |
|----------|-------------|--------|
| **Haute disponibilité** | Redondance géographique | 99.9%+ uptime |
| **Failover automatique** | Pas d'intervention manuelle | < 2 minutes |
| **Sécurité** | Chiffrement end-to-end | AES-256 + SHA-256 |
| **Scalabilité** | Ajout facile de nouveaux sites | N sites |
| **Monitoring** | Visibilité complète du réseau | Azure Monitor |

### Bénéfices opérationnels

1. **Réduction des risques**
   - Plan de reprise d'activité testé et fonctionnel
   - Continuité de service garantie
   - Protection contre les pannes datacenter

2. **Automatisation**
   - Déploiement IaC en < 1 heure
   - Configuration automatique Ansible
   - Tests automatisés

3. **Flexibilité multi-cloud**
   - Pas de vendor lock-in
   - Capacité à changer de provider
   - Mix cloud public / privé

4. **Maîtrise des coûts**
   - Infrastructure Azure : ~110€/mois
   - OVH selon besoins
   - Coûts prévisibles

### Bénéfices business

1. **Conformité**
   - RGPD : données en Europe
   - ISO 27001 : best practices sécurité
   - PCI DSS : chiffrement

2. **Agilité**
   - Time to market réduit
   - Capacité à tester rapidement
   - Infrastructure reproductible

3. **Résilience**
   - Business continuity assurée
   - RTO < 2 minutes
   - RPO proche de zéro

---

## Limites et contraintes

### Limites techniques

1. **Bande passante**
   - VpnGw1 : max 650 Mbps
   - VpnGw2 : max 1 Gbps
   - Besoin upgrade si > 1 Gbps

2. **Latence**
   - Latence réseau incompressible (~5-15ms France)
   - Pas adapté applications temps réel strict

3. **Nombre de tunnels**
   - Max 30 tunnels par VPN Gateway
   - Nécessite planification pour grandes architectures

### Contraintes opérationnelles

1. **Gestion des PSK**
   - Rotation manuelle (recommandé tous les 90 jours)
   - Stockage sécurisé requis (Azure Key Vault)

2. **Monitoring**
   - Configuration Azure Monitor requise
   - Alerting à mettre en place

3. **Maintenance**
   - Mises à jour FortiGate
   - Patches StrongSwan
   - Updates Azure

---

## Évolutions futures

### Phase 2 : Production

1. Migration vers Azure Key Vault pour les secrets
2. Déploiement Azure Bastion pour SSH sécurisé
3. Mise en place Azure Sentinel (SIEM)
4. Configuration Log Analytics
5. Alerting automatique

### Phase 3 : Optimisation

1. Upgrade VPN Gateway vers VpnGw2 (si besoin bande passante)
2. Mode Active-Active pour le VPN Gateway
3. Ajout de sites supplémentaires (GRA, WAW, etc.)
4. ExpressRoute pour liaisons dédiées critiques

### Phase 4 : Automatisation avancée

1. CI/CD avec GitHub Actions
2. Tests automatisés (Terratest, InSpec)
3. Drift detection Terraform
4. Auto-scaling basé sur métriques

---

## Conclusion

Ce POC démontre la faisabilité technique d'une architecture hybride multi-cloud avec :
- ✅ Haute disponibilité géographique
- ✅ Failover automatique < 2 minutes
- ✅ Sécurité AES-256
- ✅ Infrastructure as Code complète
- ✅ Coûts maîtrisés (~110-140€/mois)

**Prochaine étape :** Déploiement en production avec renforcements sécurité (voir Documentation/04-SECURITE.md)

---

**Auteur :** Équipe POC PRA
**Version :** 1.0
**Date :** 2025-01-16
