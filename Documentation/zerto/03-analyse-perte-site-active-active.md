# Analyse Technique - Scénario de Perte Totale d'un Site (Active/Active)

## Table des matières

1. [Contexte Architecture Active/Active](#contexte-architecture-activeactive)
2. [Description du Scénario d'Incident](#description-du-scénario-dincident)
3. [Comportement Technique Zerto](#comportement-technique-zerto)
4. [Analyse de Risque - Double Peine](#analyse-de-risque---double-peine)
5. [Stratégies de Mitigation](#stratégies-de-mitigation)
6. [Procédure de Retour à la Normale](#procédure-de-retour-à-la-normale)
7. [Recommandations Opérationnelles](#recommandations-opérationnelles)
8. [Annexes](#annexes)

---

## 1. Contexte Architecture Active/Active

### 1.1 Modèle de Déploiement

L'architecture déployée suit un modèle **Active/Active Distribuée** (Cross-Replication) :

```
┌─────────────────────────────────────────────────────────────────┐
│                    ARCHITECTURE ACTIVE/ACTIVE                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────┐    ┌──────────────────────────┐  │
│  │      Site RBX            │    │      Site SBG            │  │
│  │      (ACTIF)             │    │      (ACTIF)             │  │
│  │                          │    │                          │  │
│  │  ┌────────────────────┐  │    │  ┌────────────────────┐  │  │
│  │  │  Application A     │  │    │  │  Application B     │  │  │
│  │  │  Production        │  │    │  │  Production        │  │  │
│  │  │  - VM App A        │  │    │  │  - VM App B        │  │  │
│  │  │  - VM DB A         │  │    │  │  - VM DB B         │  │  │
│  │  └────────┬───────────┘  │    │  └────────┬───────────┘  │  │
│  │           │              │    │           │              │  │
│  │           │Zerto VPG     │    │           │Zerto VPG     │  │
│  │           │RBX→SBG       │    │           │SBG→RBX       │  │
│  │           │              │    │           │              │  │
│  │           ▼              │    │           ▼              │  │
│  │  ┌────────────────────┐  │    │  ┌────────────────────┐  │  │
│  │  │  Réplica App B     │◄─┼────┼──│  Réplica App A     │  │  │
│  │  │  (DR - Passif)     │  │    │  │  (DR - Passif)     │  │  │
│  │  └────────────────────┘  │    │  └────────────────────┘  │  │
│  │                          │    │                          │  │
│  └──────────────────────────┘    └──────────────────────────┘  │
│                                                                  │
│  Réplication Bi-directionnelle Continue (RPO 5 minutes)         │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Caractéristiques Clés

| Caractéristique | Description |
|-----------------|-------------|
| **Mode de fonctionnement** | Active/Active - Deux applications distinctes en production simultanée |
| **Application A** | Production sur RBX, Répliquée vers SBG (VPG-RBX-to-SBG) |
| **Application B** | Production sur SBG, Répliquée vers RBX (VPG-SBG-to-RBX) |
| **RPO configuré** | 5 minutes (300 secondes) |
| **RTO configuré** | 15 minutes |
| **Journal Zerto** | 24 heures de rétention |
| **Type de réplication** | Continue, asynchrone, basée sur journal |

### 1.3 Protection Normale

En situation normale :
- **Application A** (RBX) est protégée → Réplica à SBG (VPG-RBX-to-SBG)
- **Application B** (SBG) est protégée → Réplica à RBX (VPG-SBG-to-RBX)
- Les deux VPGs maintiennent un RPO < 5 minutes
- État des VPGs : `MeetingSLA`

---

## 2. Description du Scénario d'Incident

### 2.1 Scénario : Perte Totale du Site RBX

**Événement déclencheur :** Incident majeur rendant le site RBX totalement indisponible.

**Exemples de causes :**
- Incendie datacenter OVHcloud RBX (référence : incident Strasbourg 2021)
- Panne électrique majeure et prolongée
- Défaillance réseau totale (perte connectivité WAN + vRack)
- Cyberattaque avec corruption infrastructure (ransomware)
- Catastrophe naturelle (inondation, séisme)

### 2.2 Impact Immédiat sur l'Application A

**Application A (Production sur RBX)** :

✅ **Protection efficace - Failover réussi**

1. Application A est **perdue** sur RBX (site primaire)
2. Le réplica de l'Application A existe sur SBG (à jour, RPO < 5 minutes)
3. **Failover automatique** : VPG-RBX-to-SBG bascule les VMs vers SBG
4. Application A redémarre sur SBG avec perte maximale de 5 minutes de données
5. Les utilisateurs accèdent à l'Application A via SBG
6. **Routes statiques** ajoutées sur Fortigate SBG pour routage IPs 10.1.x.x
7. Azure VPN Gateway bascule automatiquement du tunnel RBX vers SBG (BGP backup)

**Résultat :** ✅ **Application A continue de fonctionner sur SBG**

### 2.3 Impact Critique sur l'Application B

**Application B (Production sur SBG)** :

⚠️ **Situation critique - Perte de protection**

1. Application B fonctionne toujours normalement sur SBG (site intact)
2. **MAIS** : Le site cible de réplication (RBX) n'existe plus
3. Les VRAs de RBX sont inaccessibles (timeout, connexion perdue)
4. **Le VPG-SBG-to-RBX passe en état dégradé** : `NotMeetingSLA` ou `RpoNotMeeting`
5. **La réplication s'arrête immédiatement**
6. **Le réplica de l'Application B sur RBX devient obsolète** (ou inaccessible)

**Résultat :** ⚠️ **Application B fonctionne mais n'est PLUS PROTÉGÉE**

---

## 3. Comportement Technique Zerto

### 3.1 Arrêt Immédiat de la Réplication

Lorsque le site cible (RBX) devient inaccessible, Zerto réagit comme suit :

#### 3.1.1 Déconnexion des VRAs

```
Timeline de l'incident :

T+0s     : Perte du site RBX
T+10s    : Timeout des VRAs RBX (keepalive échoue)
T+30s    : VPG-SBG-to-RBX détecte la perte de connectivité
T+45s    : État VPG passe à "RpoNotMeeting"
T+60s    : Arrêt du transfert de données (plus de VRA cible)
T+120s   : Alertes déclenchées (Monitoring)
T+300s   : RPO dépasse le seuil configuré (5 minutes)
```

#### 3.1.2 Passage en Mode "Bitmap Tracking"

Zerto passe automatiquement en mode **Bitmap** :

```
┌────────────────────────────────────────────────────────────┐
│             MODE BITMAP (TRACKING ONLY)                    │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  VMs Application B (SBG)                                   │
│         │                                                  │
│         ▼                                                  │
│  ┌──────────────┐                                          │
│  │  VRA SBG     │                                          │
│  │              │                                          │
│  │  • Tracks    │──► Bitmap File (Local)                  │
│  │  • Logs      │    - Blocs modifiés                     │
│  │  • NO Send   │    - Delta depuis T+0                   │
│  └──────────────┘    - Croissance continue                │
│                                                            │
│  ❌ VRA RBX (INACCESSIBLE)                                 │
│  ❌ Journal Zerto RBX (PERDU)                              │
│  ❌ Transfert réseau (IMPOSSIBLE)                          │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

**Fonctionnement du Bitmap :**
- Zerto continue de **surveiller** les modifications sur les VMs sources (App B)
- Chaque bloc modifié est enregistré dans un fichier **Bitmap local**
- **AUCUNE donnée n'est transférée** vers RBX (impossible)
- Le Bitmap grandit proportionnellement aux écritures sur les disques

### 3.2 Évolution du RPO et du Journal

#### 3.2.1 RPO Infini

```
RPO en situation normale :  ≤ 5 minutes
RPO après T+0 (perte RBX):  ∞ (infini)

┌────────────────────────────────────────────────────┐
│         ÉVOLUTION DU RPO APRÈS PERTE SITE          │
├────────────────────────────────────────────────────┤
│  RPO │                                             │
│  (m) │                                    ∞        │
│  ∞   │                              ┌──────────    │
│  240 │                         ┌────┘              │
│  120 │                    ┌────┘                   │
│   60 │               ┌────┘                        │
│   30 │          ┌────┘                             │
│    5 │──────────┘                                  │
│    0 └──────┬───────────────────────────────►      │
│            T+0   T+1h    T+4h   T+24h   Temps     │
│          (Incident RBX)                            │
└────────────────────────────────────────────────────┘
```

**Explications :**
- **T+0 → T+5min** : RPO commence à augmenter (dernier point de réplication)
- **T+5min** : RPO dépasse le seuil configuré (5 minutes) → Alerte CRITICAL
- **T+5min → T+∞** : RPO augmente indéfiniment tant que RBX est KO
- **Après 24h** : Le RPO est de 24 heures (pas de réplication depuis 1 jour)

#### 3.2.2 Journal Zerto

Le journal Zerto sur le site SBG :
- Continue d'enregistrer les modifications (Write I/O)
- **Mais ne peut plus transférer** vers RBX
- Consomme de l'espace disque localement
- Risque de saturation si l'incident dure trop longtemps

**Recommandation :** Surveillance proactive de l'espace disque du datastore journal.

### 3.3 Application B Continue de Fonctionner

**Point critique :** L'Application B n'est PAS affectée fonctionnellement.

```
┌──────────────────────────────────────────────────────┐
│     APPLICATION B - ÉTAT DURANT L'INCIDENT           │
├──────────────────────────────────────────────────────┤
│                                                      │
│  ✅ VMs actives et opérationnelles                   │
│  ✅ Services disponibles pour les utilisateurs       │
│  ✅ Performances normales                            │
│  ✅ Données persistées correctement sur SBG          │
│                                                      │
│  ❌ Réplication Zerto ARRÊTÉE                        │
│  ❌ Aucun réplica à jour sur RBX                     │
│  ❌ RPO = ∞                                          │
│  ❌ MODE SIMPLEX (Non protégé)                       │
│                                                      │
└──────────────────────────────────────────────────────┘
```

**Conséquence :** L'Application B fonctionne en mode **Simplex** (non redondé).

---

## 4. Analyse de Risque - Double Peine

### 4.1 Définition du Risque "Double Peine"

Le risque **Double Peine** (ou **Double Failure**) survient lorsque :

1. **Premier incident** : Perte du site RBX
2. **Deuxième incident** : Perte du site SBG **pendant** que RBX est toujours hors service

**Résultat catastrophique :** Perte totale et définitive de l'Application B.

### 4.2 Matrice de Risque

#### 4.2.1 Analyse d'Impact

| Scénario | Application A (RBX→SBG) | Application B (SBG→RBX) | Impact Global |
|----------|-------------------------|-------------------------|---------------|
| **Site RBX OK** | ✅ Protégée (Réplica SBG) | ✅ Protégée (Réplica RBX) | ✅ Protection complète |
| **Site RBX KO** | ✅ Failover vers SBG réussi | ⚠️ Fonctionne mais NON protégée | ⚠️ Risque critique sur App B |
| **RBX KO puis SBG KO** | ❌ PERTE TOTALE App A | ❌ PERTE TOTALE App B | 🔴 **CATASTROPHE** |

#### 4.2.2 Évaluation du Risque

**Probabilité d'occurrence :**

| Événement | Probabilité Annuelle | Source |
|-----------|---------------------|--------|
| Panne majeure site unique (RBX ou SBG) | 0,1% - 1% | Statistiques OVHcloud |
| Double panne simultanée (RBX ET SBG) | 0,001% - 0,01% | Calcul indépendance |
| Panne séquentielle (RBX puis SBG < 7 jours) | **0,01% - 0,1%** | **Risque réel** |

**Fenêtre de vulnérabilité :**

```
Duration RBX hors service × Probabilité incident SBG = Risque "Double Peine"

Exemples :
- RBX KO pendant 1 heure  → Risque négligeable
- RBX KO pendant 24 heures → Risque faible
- RBX KO pendant 7 jours   → Risque MODÉRÉ
- RBX KO pendant 30 jours  → Risque ÉLEVÉ
```

#### 4.2.3 Impact Business

| Critère | Sans Mitigation | Avec Backup Local | Avec S3 Immuable |
|---------|-----------------|-------------------|------------------|
| **RTO App B** | ∞ (Perte définitive) | 2-4 heures (Restauration) | 4-8 heures (Restauration) |
| **RPO App B** | Perte complète | Dernière sauvegarde (12-24h) | Dernière sauvegarde (12-24h) |
| **Impact financier** | 🔴 Critique (100%) | 🟡 Modéré (10-30%) | 🟢 Faible (5-15%) |
| **Impact réputationnel** | 🔴 Très élevé | 🟡 Modéré | 🟢 Faible |
| **Conformité réglementaire** | ❌ Non-conforme | ⚠️ Acceptable | ✅ Conforme |

### 4.3 Tableau d'Analyse de Risque Détaillé

```markdown
┌────────────────────────────────────────────────────────────────────────────┐
│              ANALYSE DE RISQUE - DOUBLE PEINE (DOUBLE FAILURE)             │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  PHASE 1: PERTE SITE RBX (T+0)                                            │
│  ────────────────────────────────────────────────────────────────────────  │
│  État Application A:  ✅ Failover vers SBG réussi                          │
│  État Application B:  ⚠️ Fonctionne en SIMPLEX (non protégée)             │
│  RPO Application B:   ∞ (pas de réplication)                              │
│  Fenêtre vulnérabilité: OUVERTE                                           │
│                                                                            │
│  PHASE 2: INCIDENT SUR SBG PENDANT QUE RBX EST KO (T+X jours)            │
│  ────────────────────────────────────────────────────────────────────────  │
│  Scénarios possibles:                                                     │
│                                                                            │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │ Scénario A: Corruption données SBG (ransomware)                   │   │
│  │ ──────────────────────────────────────────────────────────────────│   │
│  │ • Application B: ❌ PERTE DÉFINITIVE                               │   │
│  │ • Réplica RBX: ❌ Inaccessible (site KO)                           │   │
│  │ • Backup local: ✅ SEUL RECOURS                                    │   │
│  │ • Impact: 🔴 CRITIQUE                                              │   │
│  └────────────────────────────────────────────────────────────────────┘   │
│                                                                            │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │ Scénario B: Panne matérielle SBG (hosts ESXi)                     │   │
│  │ ──────────────────────────────────────────────────────────────────│   │
│  │ • Application B: ⏸️ INDISPONIBLE temporaire                        │   │
│  │ • Données SBG: ✅ Intègres (datastore OK)                          │   │
│  │ • Réplica RBX: ❌ Inaccessible                                     │   │
│  │ • Solution: Migration VMs vers hosts sains                         │   │
│  │ • Impact: 🟡 MODÉRÉ (RTO 2-4h)                                     │   │
│  └────────────────────────────────────────────────────────────────────┘   │
│                                                                            │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │ Scénario C: Perte datastore SBG (stockage SAN)                    │   │
│  │ ──────────────────────────────────────────────────────────────────│   │
│  │ • Application B: ❌ PERTE DONNÉES                                  │   │
│  │ • Réplica RBX: ❌ Inaccessible                                     │   │
│  │ • Backup local: ✅ RESTAURATION NÉCESSAIRE                         │   │
│  │ • RPO: Dernière sauvegarde (12-24h)                                │   │
│  │ • Impact: 🔴 CRITIQUE                                              │   │
│  └────────────────────────────────────────────────────────────────────┘   │
│                                                                            │
│  MATRICE DE DÉCISION                                                      │
│  ────────────────────────────────────────────────────────────────────────  │
│                                                                            │
│            │ Probabilité │ Impact      │ Risque      │ Priorité          │
│  ──────────┼─────────────┼─────────────┼─────────────┼──────────────────│
│  Sans      │ 0,01-0,1%   │ 🔴 CRITIQUE │ 🔴 ÉLEVÉ    │ P1 - IMMÉDIAT    │
│  Mitigation│             │ (Perte 100%)│             │                  │
│  ──────────┼─────────────┼─────────────┼─────────────┼──────────────────│
│  Avec      │ 0,01-0,1%   │ 🟡 MODÉRÉ   │ 🟡 MODÉRÉ   │ P2 - PLANIFIÉ    │
│  Backup    │             │ (Perte 10%) │             │                  │
│  Local     │             │             │             │                  │
│  ──────────┼─────────────┼─────────────┼─────────────┼──────────────────│
│  Avec S3   │ 0,01-0,1%   │ 🟢 FAIBLE   │ 🟢 FAIBLE   │ P3 - ACCEPTABLE  │
│  Immuable  │             │ (Perte 5%)  │             │                  │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

### 4.4 Calcul de la Fenêtre de Vulnérabilité

**Formule :**

```
Risque Double Peine = P(Incident SBG) × Durée(RBX KO) × Impact(Perte App B)

Où:
- P(Incident SBG) = Probabilité d'incident sur SBG par jour (0,001%)
- Durée(RBX KO) = Nombre de jours où RBX est hors service
- Impact(Perte App B) = Coût de la perte de l'Application B (€)
```

**Exemple concret :**

```
Hypothèses:
- Coût perte Application B = 1 000 000 €
- Probabilité incident SBG = 0,001% par jour (1 incident tous les 274 ans)
- Durée moyenne rétablissement RBX = 7 jours (estimation pessimiste)

Calcul:
Risque = 0,00001 × 7 jours × 1 000 000 € = 70 €/incident RBX

Mais si RBX reste KO 30 jours:
Risque = 0,00001 × 30 jours × 1 000 000 € = 300 €/incident RBX

Conclusion: Le risque augmente linéairement avec la durée d'indisponibilité de RBX.
```

---

## 5. Stratégies de Mitigation

### 5.1 Vue d'Ensemble des Solutions

```
┌────────────────────────────────────────────────────────────────────────────┐
│                     STRATÉGIES DE MITIGATION                               │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  Objectif: Maintenir une protection de l'Application B même si RBX est KO │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐ │
│  │ Solution 1: BACKUP LOCAL (Priorité P1 - IMMÉDIAT)                   │ │
│  │ ────────────────────────────────────────────────────────────────────│ │
│  │                                                                      │ │
│  │  Principe:                                                           │ │
│  │  • Activer des sauvegardes Veeam Backup vers Repository local SBG   │ │
│  │  • Fréquence: 2x par jour (12h de RPO max)                          │ │
│  │  • Rétention: 7 jours minimum                                       │ │
│  │  • Déclenchement: Automatique dès détection VPG "NotMeetingSLA"     │ │
│  │                                                                      │ │
│  │  Avantages:                                                          │ │
│  │  ✅ Mise en œuvre rapide (1-2 jours)                                 │ │
│  │  ✅ Coût faible (stockage local existant)                            │ │
│  │  ✅ RTO acceptable (2-4h)                                            │ │
│  │  ✅ RPO acceptable (12h max)                                         │ │
│  │                                                                      │ │
│  │  Inconvénients:                                                      │ │
│  │  ⚠️ Backup sur le même site (risque résiduel)                        │ │
│  │  ⚠️ Consomme de l'espace sur SBG                                     │ │
│  │  ⚠️ Pas de protection contre incident site SBG complet               │ │
│  │                                                                      │ │
│  └──────────────────────────────────────────────────────────────────────┘ │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐ │
│  │ Solution 2: S3 OBJECT STORAGE IMMUABLE (Priorité P1 - RECOMMANDÉ)   │ │
│  │ ────────────────────────────────────────────────────────────────────│ │
│  │                                                                      │ │
│  │  Principe:                                                           │ │
│  │  • Backup vers OVHcloud Object Storage S3 (région externe GRA)      │ │
│  │  • Mode Immuable (WORM - Write Once Read Many)                      │ │
│  │  • Fréquence: 2x par jour + rétention immutable 30 jours            │ │
│  │  • Chiffrement AES-256                                              │ │
│  │                                                                      │ │
│  │  Avantages:                                                          │ │
│  │  ✅ Isolation géographique (hors RBX et SBG)                         │ │
│  │  ✅ Protection ransomware (immutabilité)                             │ │
│  │  ✅ Scalabilité illimitée                                            │ │
│  │  ✅ Conformité réglementaire (RGPD, ISO 27001)                       │ │
│  │  ✅ RTO/RPO acceptables (4-8h / 12h)                                 │ │
│  │                                                                      │ │
│  │  Inconvénients:                                                      │ │
│  │  ⚠️ Coût storage S3 (estimé 50-100€/mois)                            │ │
│  │  ⚠️ Bande passante egress (facturation transfert)                    │ │
│  │  ⚠️ RTO plus long que backup local                                   │ │
│  │                                                                      │ │
│  └──────────────────────────────────────────────────────────────────────┘ │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐ │
│  │ Solution 3: SITE TERTIAIRE (Priorité P3 - LONG TERME)               │ │
│  │ ────────────────────────────────────────────────────────────────────│ │
│  │                                                                      │ │
│  │  Principe:                                                           │ │
│  │  • Ajouter un 3ème site (ex: GRA - Gravelines)                      │ │
│  │  • Réplication Zerto tri-site: RBX ⟷ SBG ⟷ GRA                     │ │
│  │  • Mode "Daisy Chain" ou "Hub-and-Spoke"                            │ │
│  │                                                                      │ │
│  │  Avantages:                                                          │ │
│  │  ✅ Protection complète 3 sites                                      │ │
│  │  ✅ RPO maintenu même si 1 site KO                                   │ │
│  │  ✅ Flexibilité géographique                                         │ │
│  │                                                                      │ │
│  │  Inconvénients:                                                      │ │
│  │  ❌ Coût élevé (infrastructure complète)                             │ │
│  │  ❌ Complexité opérationnelle                                        │ │
│  │  ❌ Délai de mise en œuvre (3-6 mois)                                │ │
│  │                                                                      │ │
│  └──────────────────────────────────────────────────────────────────────┘ │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Solution Recommandée : Backup Local + S3 Immuable

**Architecture de mitigation :**

```
┌────────────────────────────────────────────────────────────────────────────┐
│              ARCHITECTURE DE MITIGATION HYBRIDE                            │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  Site SBG (Principal pour App B)                                          │
│  ────────────────────────────────────────────────────────────────────────  │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐ │
│  │  Application B (Production)                                          │ │
│  │  • VM App B (10.2.1.10)                                              │ │
│  │  • VM DB B (10.2.1.20)                                               │ │
│  └─────────┬────────────────────────────────────────────────────────────┘ │
│            │                                                               │
│            │ Réplication Continue (Mode Normal)                            │
│            ▼                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐ │
│  │  Zerto VPG-SBG-to-RBX                                                │ │
│  │  • RPO: 5 minutes                                                    │ │
│  │  • État: ⚠️ NotMeetingSLA (si RBX KO)                                │ │
│  │  • Mode: Bitmap Tracking                                             │ │
│  └─────────┬────────────────────────────────────────────────────────────┘ │
│            │                                                               │
│            ❌ RBX Inaccessible (Incident)                                  │
│                                                                            │
│  Protection Compensatoire (Activée automatiquement)                       │
│  ────────────────────────────────────────────────────────────────────────  │
│                                                                            │
│            ┌─────────────────────┐                                         │
│            │  Ansible Playbook   │                                         │
│            │  Détection VPG KO   │                                         │
│            │  + Activation Backup│                                         │
│            └──────┬──────────────┘                                         │
│                   │                                                        │
│         ┌─────────┴─────────┐                                              │
│         │                   │                                              │
│         ▼                   ▼                                              │
│  ┌─────────────┐     ┌─────────────────┐                                  │
│  │ BACKUP 1:   │     │ BACKUP 2:       │                                  │
│  │ Local SBG   │     │ S3 Immuable GRA │                                  │
│  ├─────────────┤     ├─────────────────┤                                  │
│  │ • Veeam Job│     │ • Veeam S3 Job  │                                  │
│  │ • Toutes   │     │ • Immuable 30j  │                                  │
│  │   les 12h  │     │ • Toutes les 12h│                                  │
│  │ • Rétention│     │ • Chiffré       │                                  │
│  │   7 jours  │     │ • Multi-région  │                                  │
│  │            │     │                 │                                  │
│  │ Repository │     │ S3 Bucket       │                                  │
│  │ /backup    │     │ s3://ovh-dr-gra │                                  │
│  └─────────────┘     └─────────────────┘                                  │
│       ▲                      ▲                                             │
│       │                      │                                             │
│       └──────────┬───────────┘                                             │
│                  │                                                         │
│         Restauration possible                                              │
│         RTO: 2-4h (local) / 4-8h (S3)                                      │
│         RPO: 12 heures maximum                                             │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

### 5.3 Déclenchement Automatique

**Condition d'activation :**

```yaml
Trigger: VPG-SBG-to-RBX.status != "MeetingSLA"
Action:
  1. Alerte monitoring (email + webhook)
  2. Exécution playbook Ansible: activate-emergency-backup.yml
  3. Création job Veeam local (si pas déjà existant)
  4. Création job Veeam S3 (si pas déjà existant)
  5. Démarrage backup immédiat (full backup)
  6. Planification backups récurrents (toutes les 12h)
```

**Code d'activation (Ansible) :**

```yaml
---
# File: zerto/ansible/playbooks/activate-emergency-backup.yml
- name: Activate Emergency Backup for Application B
  hosts: veeam_server
  gather_facts: yes

  vars:
    vpg_name: "VPG-SBG-to-RBX"
    app_name: "Application-B"
    vms_to_backup:
      - "sbg-app-prod-01"
      - "sbg-db-prod-01"

  tasks:
    - name: Check VPG status
      uri:
        url: "{{ zerto_api_endpoint }}/v1/vpgs"
        headers:
          Authorization: "Bearer {{ zerto_api_token }}"
        method: GET
      register: vpg_status

    - name: Detect VPG failure
      set_fact:
        vpg_failed: true
      when:
        - vpg_status.json | selectattr('VpgName', 'equalto', vpg_name) | first | json_query('Status') != 'MeetingSLA'

    - name: Send alert notification
      uri:
        url: "{{ alert_webhook_url }}"
        method: POST
        body_format: json
        body:
          text: "🚨 CRITICAL: {{ vpg_name }} is down. Activating emergency backup for {{ app_name }}"
          priority: "high"
      when: vpg_failed

    - name: Create Veeam local backup job
      veeam_job:
        name: "Emergency-Backup-{{ app_name }}-Local"
        type: "backup"
        vms: "{{ vms_to_backup }}"
        repository: "Local-Repository-SBG"
        schedule:
          enabled: true
          type: "daily"
          time: "02:00,14:00"
        retention:
          type: "days"
          value: 7
        state: present
      when: vpg_failed

    - name: Create Veeam S3 backup job
      veeam_job:
        name: "Emergency-Backup-{{ app_name }}-S3"
        type: "backup_copy"
        source_job: "Emergency-Backup-{{ app_name }}-Local"
        repository: "S3-OVH-GRA"
        immutable: true
        immutable_days: 30
        encryption: true
        schedule:
          enabled: true
          type: "daily"
          time: "04:00,16:00"
        state: present
      when: vpg_failed

    - name: Trigger immediate backup
      veeam_job_run:
        name: "Emergency-Backup-{{ app_name }}-Local"
        type: "full"
        wait: no
      when: vpg_failed
```

### 5.4 Implémentation IaC (Terraform)

Je vais créer les modules Terraform pour provisionner l'infrastructure de backup.

---

## 6. Procédure de Retour à la Normale

### 6.1 Rétablissement du Site RBX

**Timeline de récupération :**

```
┌────────────────────────────────────────────────────────────────────────────┐
│                 PROCÉDURE DE RETOUR À LA NORMALE                           │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  T+0    : Site RBX rétabli (Infrastructure OK)                            │
│  T+10m  : VRAs RBX redémarrent automatiquement                            │
│  T+15m  : Connectivité réseau RBX ↔ SBG validée                           │
│  T+20m  : Zerto détecte le retour de RBX                                  │
│  T+25m  : VPG-SBG-to-RBX passe en "Syncing"                               │
│  T+30m  : Début de la resynchronisation Delta Sync                        │
│  T+X    : Resynchronisation terminée (dépend du bitmap)                   │
│  T+X+5m : VPG-SBG-to-RBX repasse en "MeetingSLA"                          │
│  T+X+10m: Désactivation backups d'urgence (optionnel)                     │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

### 6.2 Resynchronisation Delta Sync

**Principe du Delta Sync :**

Zerto utilise le **Bitmap** accumulé pendant l'indisponibilité de RBX pour ne synchroniser **que les différences**.

```
┌────────────────────────────────────────────────────────────────────────────┐
│                        DELTA SYNC PROCESS                                  │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  1. ANALYSE DU BITMAP                                                     │
│     ────────────────────────────────────────────────────────────────────   │
│     • Zerto lit le Bitmap local (SBG)                                     │
│     • Identifie tous les blocs modifiés depuis T+0                        │
│     • Calcule le volume à transférer                                      │
│                                                                            │
│     Exemple:                                                               │
│     - Taille VM App B: 500 GB                                             │
│     - Durée incident RBX: 7 jours                                         │
│     - Taux de modification: 5% par jour                                   │
│     - Volume à transférer: 500 GB × 5% × 7 = 175 GB                       │
│                                                                            │
│  2. TRANSFERT DELTA                                                       │
│     ────────────────────────────────────────────────────────────────────   │
│     • Zerto transfère UNIQUEMENT les blocs modifiés                       │
│     • Compression WAN activée (ratio ~2:1)                                │
│     • Bande passante utilisée: 175 GB / 2 = 87,5 GB net                  │
│                                                                            │
│     Durée estimée:                                                         │
│     - Bande passante disponible: 1 Gbps                                   │
│     - Vitesse effective: 800 Mbps (80% utilisation)                       │
│     - Temps transfert: 87,5 GB / 100 MB/s = ~15 minutes                   │
│                                                                            │
│  3. RÉAPPLICATION DES CHANGEMENTS                                         │
│     ────────────────────────────────────────────────────────────────────   │
│     • VRA RBX reçoit les blocs                                            │
│     • Mise à jour du réplica sur RBX                                      │
│     • Reconstruction du journal Zerto RBX                                 │
│                                                                            │
│  4. RETOUR EN MODE CONTINU                                                │
│     ────────────────────────────────────────────────────────────────────   │
│     • VPG-SBG-to-RBX repasse en "MeetingSLA"                              │
│     • RPO revient à < 5 minutes                                           │
│     • Mode Bitmap désactivé                                               │
│     • Réplication continue reprend                                        │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

### 6.3 Calcul de la Durée de Resynchronisation

**Formule :**

```
Durée Sync = (Taille VM × Taux Modif × Durée Incident) / (Bande Passante × Compression)

Paramètres:
- Taille VM: Taille totale des disques VM (GB)
- Taux Modif: Pourcentage de changement par jour (%)
- Durée Incident: Nombre de jours RBX hors service
- Bande Passante: Débit réseau disponible (Gbps)
- Compression: Ratio de compression Zerto (~2:1)
```

**Exemples concrets :**

| Scénario | Taille VM | Durée Incident | Taux Modif | Volume Delta | Temps Sync (1Gbps) |
|----------|-----------|----------------|------------|--------------|--------------------|
| Faible   | 200 GB    | 1 jour         | 2%         | 4 GB         | ~1 minute          |
| Moyen    | 500 GB    | 3 jours        | 5%         | 75 GB        | ~10 minutes        |
| Élevé    | 1 TB      | 7 jours        | 10%        | 700 GB       | ~90 minutes        |
| Critique | 2 TB      | 14 jours       | 15%        | 4,2 TB       | ~8 heures          |

### 6.4 Vérifications Post-Resynchronisation

**Checklist :**

```bash
# 1. Vérifier l'état du VPG
curl -H "Authorization: Bearer $ZERTO_API_TOKEN" \
  https://zerto-api.ovh.net/v1/vpgs | jq '.[] | select(.VpgName == "VPG-SBG-to-RBX")'

# Attendu: "Status": "MeetingSLA"

# 2. Vérifier le RPO actuel
# Attendu: < 300 secondes (5 minutes)

# 3. Vérifier le journal Zerto
# Attendu: 24 heures de rétention disponibles

# 4. Tester un checkpoint de test
./zerto/scripts/test-checkpoint.sh VPG-SBG-to-RBX

# 5. Valider l'alerte de retour à la normale
# Attendu: Email/Webhook "VPG-SBG-to-RBX is now MeetingSLA"
```

### 6.5 Désactivation des Backups d'Urgence

**Décision à prendre :**

Option A: **Conserver les backups d'urgence** (Recommandé)
- Coût supplémentaire faible
- Double protection (Zerto + Backup)
- Conformité renforcée

Option B: **Désactiver les backups d'urgence**
- Revenir au mode Zerto seul
- Économie de coûts storage
- Risque accepté

**Procédure de désactivation (si option B) :**

```bash
# Playbook Ansible
ansible-playbook deactivate-emergency-backup.yml \
  -e "vpg_name=VPG-SBG-to-RBX" \
  -e "confirm=yes"

# Vérifie que le VPG est bien revenu en "MeetingSLA" depuis > 24h
```

---

## 7. Recommandations Opérationnelles

### 7.1 Surveillance Proactive

**Métriques à surveiller en permanence :**

| Métrique | Seuil Normal | Seuil Warning | Seuil Critical | Action |
|----------|--------------|---------------|----------------|--------|
| **VPG Status** | MeetingSLA | - | NotMeetingSLA | Activation backup urgence |
| **RPO (secondes)** | < 300s | 300-600s | > 600s | Investigation immédiate |
| **Bitmap Size (GB)** | 0 GB | 1-10 GB | > 50 GB | Vérifier espace disque |
| **Journal Usage (%)** | < 50% | 50-70% | > 85% | Augmenter datastore |
| **Backup Job Status** | N/A (inactif) | - | Failed | Relancer backup |

**Dashboard Monitoring :**

```
┌────────────────────────────────────────────────────────────────────────────┐
│              DASHBOARD ZERTO ACTIVE/ACTIVE MONITORING                      │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  VPG-RBX-to-SBG (App A)                VPG-SBG-to-RBX (App B)             │
│  ┌────────────────────────┐            ┌────────────────────────┐         │
│  │ Status: ✅ MeetingSLA   │            │ Status: ⚠️ NotMeetingSLA│         │
│  │ RPO: 180s              │            │ RPO: ∞                  │         │
│  │ Journal: 42% (10GB)    │            │ Journal: N/A            │         │
│  │ Bandwidth: 350 Mbps    │            │ Bandwidth: 0 Mbps       │         │
│  │ Last Test: OK (J-3)    │            │ Last Test: ⚠️ Skipped   │         │
│  └────────────────────────┘            └────────────────────────┘         │
│                                                                            │
│  Emergency Backup Status (App B)                                          │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │ Local Backup:  ✅ Last run: 2h ago (Success)                        │   │
│  │ S3 Backup:     ✅ Last run: 4h ago (Success)                        │   │
│  │ RPO Backup:    12 hours                                            │   │
│  │ Next run:      in 10 hours                                         │   │
│  └────────────────────────────────────────────────────────────────────┘   │
│                                                                            │
│  🚨 ALERTS ACTIVES                                                         │
│  • [CRITICAL] VPG-SBG-to-RBX: RPO not meeting SLA (since 6h)              │
│  • [WARNING] Emergency backup activated for Application B                 │
│  • [INFO] Site RBX unreachable - Incident ticket #INC-2025-001           │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

### 7.2 Procédures d'Escalade

**Niveaux de réponse :**

```
┌────────────────────────────────────────────────────────────────────────────┐
│                      MATRICE D'ESCALADE                                    │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  Niveau 1 - Équipe Ops (0-30 minutes)                                     │
│  ────────────────────────────────────────────────────────────────────────  │
│  • Détection alerte VPG NotMeetingSLA                                     │
│  • Vérification connectivité site RBX                                     │
│  • Consultation logs Zerto                                                │
│  • Tentative redémarrage VRAs                                             │
│  • Si résolution: Clôture incident                                        │
│  • Si non résolu après 30min: → Escalade Niveau 2                        │
│                                                                            │
│  Niveau 2 - Ingénieurs Infrastructure (30min - 2h)                        │
│  ────────────────────────────────────────────────────────────────────────  │
│  • Diagnostic approfondi infrastructure RBX                               │
│  • Vérification tunnels IPsec/BGP vers Azure                              │
│  • Analyse réseau vRack RBX ↔ SBG                                        │
│  • Activation manuelle backups d'urgence (si pas auto)                    │
│  • Contact Support OVHcloud si nécessaire                                 │
│  • Si incident majeur RBX confirmé: → Escalade Niveau 3                  │
│                                                                            │
│  Niveau 3 - Gestion de Crise (2h+)                                        │
│  ────────────────────────────────────────────────────────────────────────  │
│  • Activation cellule de crise                                            │
│  • Évaluation durée prévisionnelle incident RBX                           │
│  • Décision failover Application A vers SBG                               │
│  • Communication interne/externe                                          │
│  • Suivi quotidien backup Application B                                  │
│  • Planification retour à la normale                                      │
│  • Post-mortem incident                                                   │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

### 7.3 Runbook : Gestion Incident Perte Site

**Fichier : `/zerto/runbooks/runbook-site-loss.md`**

```markdown
# RUNBOOK - Perte Totale d'un Site

## Détection

- Alerte: "VPG-SBG-to-RBX NotMeetingSLA" OU "VPG-RBX-to-SBG NotMeetingSLA"
- Source: Monitoring Zerto, Dashboard Grafana, Email/Webhook

## Phase 1: Diagnostic (0-15 minutes)

### 1.1 Identifier le site KO

bash
# Vérifier connectivité RBX
ping -c 5 10.1.0.1
ssh admin@10.1.0.1 "get system status"

# Vérifier connectivité SBG
ping -c 5 10.2.0.1
ssh admin@10.2.0.1 "get system status"


### 1.2 Vérifier les VPGs

bash
./zerto/scripts/check-vpg-status.sh --all


### 1.3 Déterminer la situation

- **Cas A**: RBX KO → Application A à risque, Application B perd protection
- **Cas B**: SBG KO → Application B à risque, Application A perd protection

## Phase 2: Actions Immédiates (15-60 minutes)

### 2.1 Si RBX KO

bash
# 1. Failover Application A vers SBG
./zerto/scripts/failover-rbx-to-sbg.sh --force --vpg VPG-RBX-to-SBG

# 2. Activer backup urgence Application B
ansible-playbook zerto/ansible/playbooks/activate-emergency-backup.yml \
  -e "app_name=Application-B"

# 3. Notifier les parties prenantes
./scripts/send-incident-notification.sh --incident RBX-DOWN


### 2.2 Si SBG KO

bash
# 1. Failover Application B vers RBX
./zerto/scripts/failover-sbg-to-rbx.sh --force --vpg VPG-SBG-to-RBX

# 2. Activer backup urgence Application A
ansible-playbook zerto/ansible/playbooks/activate-emergency-backup.yml \
  -e "app_name=Application-A"

# 3. Notifier les parties prenantes
./scripts/send-incident-notification.sh --incident SBG-DOWN


## Phase 3: Surveillance Continue (H+1 à résolution)

### 3.1 Vérifications quotidiennes

bash
# Vérifier backups d'urgence
veeam-cli job list | grep Emergency

# Vérifier espace disque site survivant
df -h /vmfs/volumes/datastore*

# Tenter reconnexion site KO
ping <site-ko-ip>


### 3.2 Reporting journalier

- Durée cumulative incident: X jours
- Volume bitmap accumulé: X GB
- Dernière sauvegarde réussie: il y a X heures
- Estimation temps resynchronisation: X heures

## Phase 4: Retour à la Normale

### 4.1 Quand le site revient

bash
# 1. Attendre stabilisation (15 minutes minimum)
sleep 900

# 2. Vérifier état VPGs
./zerto/scripts/check-vpg-status.sh --all

# 3. Surveiller resynchronisation
watch -n 60 './zerto/scripts/check-sync-progress.sh'

# 4. Valider RPO retour à < 5 min
# 5. Post-mortem incident


## Contacts d'Escalade

- Niveau 1 (Ops): ops-team@exemple.com / +33 X XX XX XX XX
- Niveau 2 (Infra): infra-team@exemple.com / +33 X XX XX XX XX
- Niveau 3 (Crisis): cto@exemple.com / +33 X XX XX XX XX
- Support OVH: https://www.ovh.com/manager/
- Support Zerto: support@zerto.com / +1-XXX-XXX-XXXX
```

### 7.4 Tests Réguliers

**Plan de tests :**

| Test | Fréquence | Objectif | Durée |
|------|-----------|----------|-------|
| **Test Failover** | Mensuel | Valider basculement App A et App B | 2h |
| **Test Backup Urgence** | Trimestriel | Valider activation auto backup | 1h |
| **Test Restauration S3** | Semestriel | Valider RTO/RPO depuis S3 | 4h |
| **Simulation Perte Site** | Annuel | Exercice complet (failover + backup) | 1 jour |

---

## 8. Annexes

### 8.1 Glossaire

| Terme | Définition |
|-------|------------|
| **Active/Active** | Architecture où plusieurs sites hébergent des applications en production simultanément |
| **Simplex** | Mode de fonctionnement non redondé (sans réplication active) |
| **Bitmap** | Fichier de suivi des blocs disques modifiés (pour delta sync) |
| **Delta Sync** | Synchronisation incrémentale (uniquement les différences) |
| **Double Peine** | Scénario où deux sites tombent en panne séquentiellement |
| **WORM** | Write Once Read Many - Mode immutable pour backups |
| **RTO** | Recovery Time Objective - Temps maximum de restauration |
| **RPO** | Recovery Point Objective - Perte de données maximale acceptable |

### 8.2 Références

- [Zerto Best Practices - Multi-Site](https://www.zerto.com/myzerto/knowledge-base/)
- [Veeam Backup for VMware](https://helpcenter.veeam.com/docs/backup/vsphere/)
- [OVHcloud Object Storage S3](https://docs.ovh.com/fr/storage/s3/)
- [Active/Active DR Architectures](https://www.gartner.com/en/documents/disaster-recovery)

### 8.3 Historique des Révisions

| Version | Date | Auteur | Changements |
|---------|------|--------|-------------|
| 1.0 | 2025-12-17 | Équipe Infrastructure | Création initiale du document |

---

**Document maintenu par** : Équipe Infrastructure
**Dernière mise à jour** : 2025-12-17
**Classification** : Interne - Confidentiel
**Approbation** : Architecte Infrastructure, Responsable PRA
