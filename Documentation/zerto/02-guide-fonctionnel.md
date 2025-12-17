# Guide Fonctionnel - Solution Zerto PRA/PRI

## Table des matières

1. [Introduction](#introduction)
2. [Concepts clés](#concepts-clés)
3. [Opérations quotidiennes](#opérations-quotidiennes)
4. [Gestion des incidents](#gestion-des-incidents)
5. [Tests et validation](#tests-et-validation)
6. [Procédures opérationnelles](#procédures-opérationnelles)
7. [FAQ](#faq)

---

## 1. Introduction

### 1.1 Objectif du document

Ce guide fonctionnel est destiné aux équipes opérationnelles (Ops, SRE, administrateurs système) qui gèrent au quotidien la solution de Plan de Reprise d'Activité (PRA) basée sur Zerto.

### 1.2 À qui s'adresse ce guide

- **Administrateurs système** : Gestion quotidienne, monitoring
- **Équipes Ops** : Intervention en cas d'incident
- **SRE** : Optimisation et amélioration continue
- **Managers IT** : Reporting et métriques

### 1.3 Périmètre

Cette solution protège les applications critiques hébergées sur deux sites OVHcloud :

| Site | Rôle | Applications protégées |
|------|------|------------------------|
| **RBX** (Roubaix) | Site primaire / DR | Application de production + Base de données |
| **SBG** (Strasbourg) | Site primaire / DR | Application de production + Base de données |

**Protection bi-directionnelle** : Chaque site peut servir de site principal ou de secours.

---

## 2. Concepts clés

### 2.1 Qu'est-ce que Zerto ?

Zerto est une solution de réplication continue qui permet de :
- **Protéger** les machines virtuelles en temps réel
- **Basculer** rapidement vers un site de secours
- **Revenir** au site principal après résolution de l'incident

### 2.2 RPO et RTO

#### RPO (Recovery Point Objective)
- **Définition** : Quantité maximale de données qu'on accepte de perdre
- **Configuration actuelle** : **5 minutes**
- **Signification** : En cas d'incident, on peut perdre au maximum 5 minutes de données

#### RTO (Recovery Time Objective)
- **Définition** : Temps maximal pour restaurer le service
- **Configuration actuelle** : **15 minutes**
- **Signification** : Le service doit être restauré en moins de 15 minutes

### 2.3 Virtual Protection Group (VPG)

Un VPG est un groupe de machines virtuelles protégées ensemble :

```
VPG-RBX-to-SBG
├── rbx-app-prod-01  (Application)
└── rbx-db-prod-01   (Base de données)
```

**Pourquoi grouper ?**
- Cohérence des données entre app et DB
- Ordre de démarrage contrôlé (DB avant App)
- Failover coordonné

### 2.4 Journal de réplication

Zerto conserve un **journal de 24 heures** :
- Permet de revenir à n'importe quel point dans les dernières 24h
- Utile en cas de corruption de données ou ransomware
- Stocké sur le site de destination

### 2.5 Types d'opérations

| Opération | Quand l'utiliser | Durée | Impact |
|-----------|------------------|-------|--------|
| **Test Failover** | Tests réguliers | 1-2h | Aucun (environnement isolé) |
| **Failover** | Incident majeur sur site source | 10-15 min | Production bascule |
| **Failback** | Retour à la normale | 30-60 min | Production bascule |

---

## 3. Opérations quotidiennes

### 3.1 Vérification de l'état du système

#### Tous les matins

**Console Zerto** : https://zerto.ovhcloud.com

1. Vérifier le **statut des VPGs** :
   - ✅ **Vert (MeetingSLA)** = OK
   - ⚠️ **Orange (Warning)** = À surveiller
   - ❌ **Rouge (Error)** = Intervention requise

2. Vérifier le **RPO actuel** :
   - Doit être < 300 secondes (5 minutes)
   - Si > 600 secondes : Investigation

3. Vérifier le **journal** :
   - Utilisation < 85%
   - Si > 85% : Augmenter la taille

#### Via script automatisé

```bash
cd /home/user/poc-pra-test/zerto
./scripts/monitoring/health-check.sh
```

**Output exemple** :
```
[2025-12-17 09:00:00] Vérification de santé Zerto

✓ VPG-RBX-to-SBG
  Status: MeetingSLA
  RPO: 285 secondes (cible: 300s)
  Journal: 67% (OK)
  Dernière réplication: Il y a 4 minutes

✓ VPG-SBG-to-RBX
  Status: MeetingSLA
  RPO: 290 secondes (cible: 300s)
  Journal: 65% (OK)
  Dernière réplication: Il y a 4 minutes

✓ Réseau
  BGP Peering: Established
  Latence RBX-SBG: 12ms

[OK] Tous les systèmes opérationnels
```

### 3.2 Dashboard Grafana

**URL** : http://monitoring.local:3000/d/zerto-production

#### Métriques à surveiller

1. **RPO en temps réel**
   - Graphique sur 24h
   - Alertes si dépassement

2. **Bande passante de réplication**
   - Pic d'activité normal : 08h-18h
   - Si constamment élevée : Optimisation requise

3. **État des VPGs**
   - Historique des changements d'état
   - Alertes actives

4. **Performance réseau**
   - Latence inter-sites
   - Perte de paquets
   - Utilisation BGP

### 3.3 Alertes et notifications

#### Canaux de notification

- **Email** : ops-team@exemple.com
- **Slack** : #alerts-zerto
- **Téléphone** : Astreinte (incidents critiques)

#### Niveaux de sévérité

| Niveau | Délai d'intervention | Exemple |
|--------|---------------------|---------|
| **INFO** | Aucun | Test réussi |
| **WARNING** | 4h | RPO > 450s |
| **CRITICAL** | Immédiat | VPG en erreur |
| **EMERGENCY** | Immédiat + Escalade | Site indisponible |

### 3.4 Rapports hebdomadaires

#### À générer tous les lundis

```bash
./scripts/generate-weekly-report.sh
```

**Contenu du rapport** :
- État de santé moyen de la semaine
- Incidents et résolutions
- RPO moyen et pics
- Bande passante consommée
- Tests effectués

**Destinataires** :
- Management IT
- Équipe Ops
- Équipe Sécurité

---

## 4. Gestion des incidents

### 4.1 Scénarios d'incidents

#### Scénario 1 : Site RBX indisponible

**Symptômes** :
- VMs RBX inaccessibles
- Perte de connexion réseau à RBX
- Alertes monitoring site RBX down

**Action** : **Failover RBX → SBG**

#### Scénario 2 : Site SBG indisponible

**Symptômes** :
- VMs SBG inaccessibles
- Perte de connexion réseau à SBG
- Alertes monitoring site SBG down

**Action** : **Failover SBG → RBX**

#### Scénario 3 : Corruption de données

**Symptômes** :
- Données corrompues sur l'application
- Suspicion de ransomware
- Erreurs applicatives

**Action** : **Restauration point-in-time** (via journal)

### 4.2 Procédure de failover - Étape par étape

#### AVANT de lancer le failover

**Checklist** :
- [ ] Incident confirmé (site source réellement indisponible)
- [ ] Site cible opérationnel et accessible
- [ ] RPO acceptable (< 10 minutes si possible)
- [ ] Manager IT notifié
- [ ] Équipe applicative en alerte

#### Étape 1 : Évaluation

```bash
# Vérifier l'état des VPGs
./scripts/check-vpg-status.sh

# Vérifier la connectivité au site cible
ping -c 5 10.2.0.1  # Si failover vers SBG
```

#### Étape 2 : Lancement du failover

**Si RBX est down → Failover vers SBG** :
```bash
cd /home/user/poc-pra-test/zerto
./scripts/failover-rbx-to-sbg.sh
```

**Si SBG est down → Failover vers RBX** :
```bash
cd /home/user/poc-pra-test/zerto
./scripts/failover-sbg-to-rbx.sh
```

#### Étape 3 : Pendant le failover

Le script affiche la progression :

```
============================================================================
FAILOVER RBX -> SBG
============================================================================

[09:05:00] Authentification à l'API Zerto...
[09:05:02] Vérification de l'état du VPG: VPG-RBX-to-SBG-production
[09:05:03] État du VPG: MeetingSLA
[09:05:03] RPO actuel: 285 secondes

ATTENTION: Lancement d'un failover réel!
Confirmez-vous le failover? (tapez 'FAILOVER' pour confirmer): FAILOVER

[09:05:15] Lancement du failover du VPG VPG-RBX-to-SBG-production...
[09:05:17] Failover lancé avec succès
[09:05:17] Attente de la fin du failover (timeout: 1800s)...
[09:06:00] État: Initializing
[09:07:00] État: Syncing
[09:09:00] État: FailingOver
[09:12:00] État: FailedOver
[09:12:01] Failover terminé avec succès
[09:12:02] Reconfiguration du routage Fortigate SBG...
[09:13:30] Fortigate SBG reconfiguré avec succès
[09:13:31] Vérification de la continuité de service...

============================================================================
FAILOVER TERMINÉ AVEC SUCCÈS
============================================================================
Les VMs sont maintenant opérationnelles sur SBG
```

**Durée totale estimée** : 10-15 minutes

#### Étape 4 : Vérifications post-failover

1. **Vérifier les VMs** :
   ```bash
   # Se connecter à la console OVH SBG
   # Vérifier que les VMs sont démarrées
   ```

2. **Tester l'application** :
   - Accéder à l'URL de l'application
   - Vérifier la connectivité à la base de données
   - Effectuer quelques opérations de test

3. **Vérifier le routage réseau** :
   ```bash
   # Sur Fortigate SBG
   get router info routing-table all
   ```

4. **Notifier les équipes** :
   - Équipes applicatives : Service restauré
   - Management : Incident géré
   - Utilisateurs : Via canal de communication habituel

### 4.3 Procédure de failback - Retour à la normale

**Quand effectuer le failback ?**
- Site source (RBX ou SBG) de nouveau opérationnel
- Incident résolu et cause identifiée
- Validation technique et applicative effectuée
- Fenêtre de maintenance planifiée (idéalement)

#### Étape 1 : Préparation

**Checklist** :
- [ ] Site source opérationnel confirmé
- [ ] Infrastructure réseau vérifiée
- [ ] RPO acceptable sur le VPG inverse
- [ ] Équipe applicative disponible
- [ ] Fenêtre de maintenance (si possible)

#### Étape 2 : Vérification du site source

```bash
# Vérifier la connectivité au site source
ping -c 10 10.1.0.1  # Si retour vers RBX

# Vérifier l'infrastructure
ssh admin@10.1.0.1  # Se connecter au Fortigate
# Vérifier les services, le stockage, etc.
```

#### Étape 3 : Lancement du failback

**Exemple : Retour de SBG vers RBX**

```bash
cd /home/user/poc-pra-test/zerto
./scripts/failback.sh --from sbg --to rbx
```

**Exemple : Retour de RBX vers SBG**

```bash
./scripts/failback.sh --from rbx --to sbg
```

#### Étape 4 : Pendant le failback

```
============================================================================
FAILBACK SBG -> RBX
============================================================================

[10:00:00] Vérification de la santé du site RBX...
[10:00:05] Site RBX accessible
[10:00:06] Authentification Zerto...
[10:00:08] Vérification du VPG: VPG-RBX-to-SBG-production
[10:00:09] État VPG: MeetingSLA
[10:00:09] RPO actuel: 295s

ATTENTION: Lancement du failback de SBG vers RBX
Confirmez le failback (tapez 'FAILBACK'): FAILBACK

[10:00:20] Lancement du failback...
[10:00:22] Failback lancé avec succès
[10:00:22] Attente de la fin du failback (peut prendre jusqu'à 1 heure)...
[10:15:00] État: Syncing (15m écoulées)
[10:30:00] État: Syncing (30m écoulées)
[10:42:00] État: MeetingSLA
[10:42:01] Failback terminé avec succès
[10:42:02] Reconfiguration réseau pour RBX...
[10:43:30] Réseau reconfiguré
[10:43:31] Vérification de la continuité de service sur RBX...

============================================================================
FAILBACK TERMINÉ AVEC SUCCÈS
============================================================================
Les VMs sont de retour sur RBX
La réplication inverse a été activée
```

**Durée totale estimée** : 30-60 minutes

#### Étape 5 : Post-failback

1. **Vérifier les VMs sur le site source** :
   - VMs démarrées et opérationnelles
   - Application accessible
   - Base de données synchronisée

2. **Vérifier la réplication** :
   - VPG en état "MeetingSLA"
   - RPO dans les limites
   - Réplication inverse active

3. **Documentation** :
   - Logger l'incident dans le système de ticketing
   - Documenter la cause racine
   - Mettre à jour les procédures si nécessaire

---

## 5. Tests et validation

### 5.1 Tests réguliers obligatoires

#### Test mensuel - Test Failover

**Fréquence** : 1er mercredi de chaque mois

**Objectif** : Valider que le failover fonctionne sans impacter la production

**Procédure** :
```bash
# Lancer un test failover (environnement isolé)
./scripts/test-failover.sh --vpg rbx-to-sbg

# Vérifier les VMs de test
# Valider l'application de test
# Nettoyer le test
./scripts/cleanup-test-failover.sh
```

**Durée** : 1-2 heures

**Validation** :
- [ ] VMs de test démarrées correctement
- [ ] Application fonctionnelle
- [ ] Ordre de démarrage respecté (DB avant App)
- [ ] Réseau configuré correctement
- [ ] Pas d'impact sur la production

#### Test trimestriel - Failover réel (hors production)

**Fréquence** : 1 fois par trimestre

**Objectif** : Valider un failover complet dans des conditions réelles

**Planification** :
- Fenêtre de maintenance planifiée
- Équipes applicatives disponibles
- Communication aux utilisateurs

**Procédure** :
1. Basculer la production vers le site secondaire
2. Valider le fonctionnement pendant 4h minimum
3. Effectuer un failback
4. Valider le retour à la normale

### 5.2 Tests de restauration point-in-time

**Scénario** : Restaurer une VM à un point dans le temps

**Procédure** :

1. **Accéder à la console Zerto**

2. **Sélectionner le VPG** concerné

3. **Choisir un checkpoint** (point dans le temps) dans les dernières 24h

4. **Lancer la restauration** sur une VM de test

5. **Valider** les données restaurées

**Cas d'usage** :
- Corruption de données détectée
- Suppression accidentelle
- Test de conformité backup/restore

### 5.3 Validation des performances

#### Métriques à mesurer

| Métrique | Objectif | Méthode |
|----------|----------|---------|
| **Temps de failover** | < 15 min | Chronomètre lors des tests |
| **RPO moyen** | < 5 min | Dashboard Grafana |
| **Temps de démarrage VM** | < 3 min | Console Zerto |
| **Latence réseau** | < 20 ms | ping inter-sites |

#### Rapport de test

À remplir après chaque test :

```
=== RAPPORT DE TEST FAILOVER ===
Date: 2025-01-15
Type: Test mensuel
VPG: VPG-RBX-to-SBG

Résultats:
- Durée du failover: 12 minutes ✓
- Toutes les VMs démarrées: Oui ✓
- Application accessible: Oui ✓
- Ordre de démarrage respecté: Oui ✓
- Réseau fonctionnel: Oui ✓

Problèmes identifiés: Aucun

Actions correctives: Aucune

Validé par: John Doe
```

---

## 6. Procédures opérationnelles

### 6.1 Ajout d'une nouvelle VM à protéger

#### Étape 1 : Identifier la VM

```bash
# Lister les VMs disponibles
openstack --os-region-name=GRA7 server list
```

#### Étape 2 : Modifier la configuration Terraform

```bash
cd /home/user/poc-pra-test/zerto/terraform
nano terraform.tfvars
```

Ajouter la VM dans `rbx_protected_vms` ou `sbg_protected_vms` :

```hcl
rbx_protected_vms = [
  # VMs existantes...
  {
    name           = "rbx-web-prod-01"
    instance_id    = "xxxxx-xxxxx-xxxxx"
    boot_order     = 3
    failover_ip    = "10.1.1.30"
    failover_subnet = "10.1.1.0/24"
    description    = "Serveur Web RBX"
  }
]
```

#### Étape 3 : Appliquer la modification

```bash
terraform plan
terraform apply
```

#### Étape 4 : Vérifier

```bash
# Vérifier que la VM est bien protégée
./scripts/check-vpg-status.sh
```

### 6.2 Modification du RPO

#### Quand modifier le RPO ?

- **Augmenter le RPO** (ex: 5 min → 10 min) :
  - Bande passante limitée
  - Coût de réplication élevé
  - Application tolérante à la perte de données

- **Diminuer le RPO** (ex: 5 min → 2 min) :
  - Application critique
  - Perte de données inacceptable
  - Bande passante suffisante

#### Procédure

```bash
cd /home/user/poc-pra-test/zerto/terraform
nano terraform.tfvars
```

Modifier :
```hcl
zerto_rpo_seconds = 120  # 2 minutes au lieu de 300
```

Appliquer :
```bash
terraform apply
```

### 6.3 Augmentation de la rétention du journal

**Défaut** : 24 heures

**Si besoin de plus** (ex: 72 heures) :

```hcl
zerto_journal_hours = 72
```

**Impact** :
- Espace disque supplémentaire requis
- Coût de stockage augmenté
- Possibilité de restaurer sur 3 jours

### 6.4 Maintenance planifiée

#### Maintenance d'un site (ex: RBX)

**Procédure** :

1. **Planifier une fenêtre de maintenance**

2. **Notifier** :
   - Équipes applicatives
   - Utilisateurs
   - Management

3. **Avant la maintenance** :
   - Vérifier que le site secondaire (SBG) est opérationnel
   - S'assurer que le RPO est à jour

4. **Pendant la maintenance** :
   - Option A : Laisser la réplication active (si réseau maintenu)
   - Option B : Effectuer un failover vers SBG

5. **Après la maintenance** :
   - Vérifier le retour à la normale
   - Si failover effectué : Planifier un failback
   - Valider la réplication

---

## 7. FAQ

### 7.1 Questions générales

#### Q: Que se passe-t-il si les deux sites tombent simultanément ?

**R:** Scénario catastrophique peu probable. Dans ce cas :
- Aucun failover automatique possible
- Dépend de la dernière sauvegarde off-site (si configurée)
- Plan de Continuité d'Activité (PCA) alternatif requis

#### Q: Peut-on faire un failover partiel (une seule VM) ?

**R:** Non, Zerto fonctionne au niveau du VPG. Toutes les VMs d'un VPG basculent ensemble pour maintenir la cohérence des données.

Solution : Créer des VPGs séparés pour des VMs indépendantes.

#### Q: Combien de temps pour synchroniser une nouvelle VM ?

**R:** Dépend de la taille :
- VM de 100 GB : ~2-4 heures
- VM de 500 GB : ~8-12 heures
- VM de 1 TB : ~16-24 heures

### 7.2 Questions techniques

#### Q: Le RPO dépasse régulièrement la cible, que faire ?

**R:** Plusieurs solutions :
1. Activer la compression WAN (si pas déjà fait)
2. Augmenter la bande passante allouée
3. Exclure des disques non critiques
4. Augmenter la cible RPO (5 min → 10 min)
5. Vérifier les performances du stockage source

#### Q: Comment restaurer une seule base de données et pas toute la VM ?

**R:** Deux options :
1. Restaurer la VM complète sur un réseau isolé, extraire la DB
2. Utiliser les outils de backup applicatifs (mysqldump, pg_dump, etc.)

Zerto protège au niveau VM, pas au niveau fichier.

#### Q: Peut-on faire un failover pendant les heures de bureau ?

**R:** Oui, mais déconseillé sauf urgence :
- Impact utilisateurs pendant 10-15 minutes
- Risque de perte de transactions en cours
- Préférer une fenêtre de faible activité

#### Q: Que signifie "Journal usage at 90%" ?

**R:** Le journal de réplication est presque plein :
- **Action immédiate** : Augmenter la taille du journal
- **Risque** : Si 100%, impossibilité de maintenir le RPO
- **Cause** : Changements sur les VMs très importants

### 7.3 Questions opérationnelles

#### Q: Qui peut lancer un failover ?

**R:** Selon la matrice RACI :
- **Niveau 1 Ops** : Peut lancer après approbation manager
- **Niveau 2 SRE** : Peut lancer de manière autonome
- **On-call / Astreinte** : Peut lancer en cas d'urgence

Toujours documenter la décision.

#### Q: Faut-il un failback immédiat après résolution de l'incident ?

**R:** Non, pas nécessairement :
- Si le site secondaire fonctionne bien : Rester dessus temporairement
- Planifier le failback pendant une fenêtre appropriée
- Avantage : Valider complètement la résolution de l'incident

#### Q: Comment annuler un failover en cours ?

**R:** Dépend de l'étape :
- **Avant commit** : Possible via console Zerto (Abort)
- **Après commit** : Impossible, doit effectuer un failback

Utiliser les tests failover pour éviter ce scénario.

---

## 8. Contacts et support

### 8.1 Équipes internes

| Équipe | Contact | Responsabilité |
|--------|---------|----------------|
| **Ops L1** | ops@exemple.com | Monitoring quotidien |
| **SRE L2** | sre@exemple.com | Incidents complexes |
| **Infrastructure** | infra@exemple.com | Architecture |
| **Manager IT** | manager@exemple.com | Validation décisions |
| **Astreinte** | +33 X XX XX XX XX | Incidents hors heures |

### 8.2 Support externe

| Fournisseur | Contact | Sujet |
|-------------|---------|-------|
| **OVH Support** | https://www.ovh.com/manager | Infrastructure cloud |
| **Zerto Support** | support@zerto.com | Problèmes Zerto |
| **Fortigate Support** | support@fortinet.com | Firewall et réseau |

### 8.3 Escalade

**Niveau 1** (0-30 min) :
- Équipe Ops
- Vérifications de base
- Consultation documentation

**Niveau 2** (30 min - 2h) :
- Équipe SRE
- Diagnostic approfondi
- Modifications de configuration

**Niveau 3** (> 2h) :
- Support OVH/Zerto
- Manager IT
- Incident majeur

---

## 9. Annexes

### 9.1 Checklist incident

#### Checklist de réponse à incident

```
[ ] Incident détecté et confirmé
[ ] Équipe Ops notifiée
[ ] Manager IT informé
[ ] Évaluation de la sévérité
[ ] Décision failover prise
[ ] Équipes applicatives alertées
[ ] Communication utilisateurs préparée
[ ] Site cible vérifié opérationnel
[ ] Failover lancé
[ ] Monitoring actif pendant failover
[ ] Vérification post-failover effectuée
[ ] Communication utilisateurs envoyée
[ ] Documentation incident créée
[ ] Post-mortem planifié
```

### 9.2 Modèle de communication incident

**Email aux utilisateurs** :

```
Objet: [INCIDENT] Bascule de l'infrastructure vers le site de secours

Chers utilisateurs,

En raison d'un incident technique sur notre site de Roubaix (RBX),
nous avons activé notre Plan de Reprise d'Activité (PRA) et basculé
l'infrastructure vers notre site de secours de Strasbourg (SBG).

Impact:
- Interruption de service: 12 minutes
- Services de nouveau opérationnels depuis 10h15
- Aucune perte de données

Actions en cours:
- Résolution de l'incident sur le site principal
- Surveillance accrue du site de secours
- Retour à la normale planifié: [DATE/HEURE]

Merci de votre compréhension.

L'équipe IT
```

### 9.3 Métriques et KPIs

#### KPIs mensuels à reporter

| KPI | Cible | Mesure |
|-----|-------|--------|
| Disponibilité globale | 99.9% | Uptime monitoring |
| RPO moyen | < 5 min | Dashboard Zerto |
| Incidents Zerto | 0 | Tickets |
| Tests réalisés | 1/mois | Rapports de test |
| Temps de failover | < 15 min | Chronométrage tests |

---

**Document maintenu par** : Équipe Ops & SRE
**Dernière mise à jour** : 2025-12-17
**Version** : 1.0
**Prochaine révision** : 2025-03-17
