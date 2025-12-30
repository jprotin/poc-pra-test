# Stratégie Failback Zerto - Gestion des Tâches CRON

**Date :** 2025-12-29
**Statut :** Proposition
**Auteur :** Analyse Technique PRA

---

## 1. Infrastructure Actuelle

### Configuration Zerto en Production

**Plateforme :**
- **Hébergeur :** OVH Cloud
- **Hyperviseur :** VMware vSphere
- **Solution PRA :** Zerto Virtual Replication

**Périmètre de Protection :**
- **Site Primaire (RBX)** : 36 VMs protégées
- **Site Secours (SBG)** : 16 VMs (réplicas + services annexes)
- **Total :** 52 VMs sous surveillance Zerto

**Performances Réplication :**
- **RPO Moyen :** 8 secondes ⭐ (objectif standard : 5 minutes)
- **Mode :** Continuous Data Protection (CDP) - Réplication de blocs en continu
- **Consistance :** Crash Consistent (par défaut)

### Architecture des Bases de Données

Les bases de données sont **installées directement sur les VMs** (non externalisées). Types de DB concernés :
- MySQL/MariaDB (applications métier)
- PostgreSQL (backoffice, analytics)
- MongoDB (caching, sessions)

**Mode de réplication :** Crash Consistent au niveau bloc (pas de coordination applicative).

---

## 2. Analyse Technique : Crash Consistent vs Application Consistent

### Qu'est-ce que le "Crash Consistent" ?

Zerto capture les **I/O disque en continu** au niveau bloc, sans coordination avec les applications. C'est comme si :
- On coupait l'alimentation de la VM brutalement
- On redémarrait la VM depuis le dernier snapshot (≈8s avant l'incident)

**Pour les bases de données, cela signifie :**
- Les données écrites sur disque sont cohérentes (pas de blocs corrompus)
- Les transactions en mémoire (buffers non flushés) peuvent être perdues
- La DB effectue un **recovery automatique** au démarrage (replay des WAL/redo logs)

### Avantages du Mode Crash Consistent

✅ **Performance :** Aucun overhead sur les VMs en production (pas de VSS, pas de scripts)
✅ **Simplicité :** Pas de configuration applicative requise
✅ **Compatibilité :** Fonctionne avec toutes les applications
✅ **RPO Optimal :** 8s de perte de données maximum (excellent)

### Risques Identifiés pour les Bases de Données

| Risque | Impact | Probabilité | Mitigation |
|--------|--------|-------------|------------|
| **Perte de transactions en cours** | 🟡 Moyen | 🟢 Faible (8s de fenêtre) | Acceptable pour données non critiques |
| **Temps de recovery long** | 🟡 Moyen | 🟡 Moyen (dépend de la charge) | Prévoir +2-5min au démarrage |
| **Incohérence si opération critique** | 🔴 Élevé | 🟢 Très faible | Monitoring des opérations longues (VACUUM, REINDEX) |
| **Corruption si DB mal configurée** | 🔴 Critique | 🟢 Très faible | ✅ Vérifier journaling activé (InnoDB, WAL) |

### Évaluation par Type de DB

| Base de Données | Crash Consistent Safe ? | Justification | Recommandation |
|-----------------|:-----------------------:|---------------|----------------|
| **PostgreSQL** | ✅ OUI | WAL assure la cohérence, recovery automatique rapide | Crash Consistent OK |
| **MySQL (InnoDB)** | ✅ OUI | InnoDB log buffer + doublewrite buffer | Crash Consistent OK |
| **MySQL (MyISAM)** | ⚠️ RISQUÉ | Pas de transactions, risque de corruption | **Migrer vers InnoDB** ou Application Consistent |
| **MongoDB** | ✅ OUI | Journaling activé par défaut (WiredTiger) | Crash Consistent OK si `journal=true` |
| **Oracle** | ✅ OUI | Redo logs + checkpoint automatique | Crash Consistent OK mais Application Consistent préférable |
| **SQL Server** | ✅ OUI | Transaction log assure la cohérence | Crash Consistent OK |

### Quand Passer en Application Consistent ?

Envisager le mode **Application Consistent** (avec VSS/scripts) si :

❌ **Vous avez des DB MyISAM** (risque de corruption)
❌ **Opérations batch longues** (> 1h) qui ne doivent pas être interrompues
❌ **Exigence RPO = 0** (aucune perte tolérée)
❌ **Réglementations strictes** (finance, santé) nécessitant des recovery garanties

⚠️ **Inconvénients de l'Application Consistent :**
- Impact performance (VSS freeze les I/O temporairement)
- Complexité (scripts à maintenir pour chaque DB)
- RPO dégradé (snapshots toutes les 5-15min au lieu de 8s)

### Verdict pour la Configuration Actuelle

🟢 **Crash Consistent avec RPO 8s est ADAPTÉ** si :
- ✅ Les DB utilisent des moteurs transactionnels (InnoDB, PostgreSQL WAL, MongoDB WiredTiger)
- ✅ La perte de 8s de transactions est acceptable métier
- ✅ Les applications gèrent les retry/idempotence

🔴 **Action requise :**
- [ ] **Vérifier** que toutes les DB MySQL utilisent InnoDB (pas MyISAM)
- [ ] **Tester** un failover réel pour mesurer le temps de recovery des DB
- [ ] **Documenter** le RPO métier acceptable par application (8s OK ?)

---

## 3. Contexte & Problématique - Gestion des CRON

### Situation Actuelle
Les applications déployées sur les VMs (RBX primaire, SBG secours) contiennent des **tâches CRON** critiques. Lors d'un incident et du retour à la normale, une **fenêtre de risque** apparaît :

**Problème identifié :**
- Les VMs sur RBX redémarrent/sont accessibles **avant** la bascule DNS/applicative officielle
- Pendant cette fenêtre, **les CRON tournent en parallèle** sur RBX (site primaire restauré) ET SBG (site de secours encore actif)
- **Risque :** Traitement en double, corruption de données, incohérences métier

---

## 4. Processus PRA Actuel - Analyse Détaillée

### 4.1 Phase 1 : Détection de l'Incident (RBX → SBG)

| Étape | Action | Responsable | Durée |
|-------|--------|-------------|-------|
| **1. Détection** | Alerte monitoring (sonde, Zerto, supervision) détecte l'indisponibilité RBX | Automatique / Astreinte | T+0 à T+5min |
| **2. Décision Failover** | Validation de la nécessité de basculer vers SBG | Responsable Technique | T+5min à T+15min |
| **3. Exécution Failover** | Activation du VPG Zerto : bascule des VMs vers SBG | Opérateur / Zerto | T+15min à T+30min |
| **4. Vérification Santé** | Tests de disponibilité des services sur SBG (HTTP, DB, CRON) | Équipe Ops | T+30min à T+45min |
| **5. Bascule DNS/Réseau** | Modification des enregistrements DNS/Load Balancer vers SBG | Équipe Réseau | T+45min à T+60min |
| **6. Communication** | Notification aux équipes et utilisateurs | Support | T+60min |

**État stable :** Les applications tournent sur SBG. RBX est hors-ligne ou en état dégradé.

---

### 4.2 Phase 2 : Retour à la Normale (SBG → RBX) - **ZONE À RISQUE**

| Étape | Action | État des CRON | Risque |
|-------|--------|---------------|--------|
| **7. Restauration RBX** | VMware vSphere restaure les VMs RBX (hyperviseur, réseau, stockage) | ❌ RBX : Inactifs<br>✅ SBG : Actifs | Aucun |
| **8. Synchronisation Zerto** | Zerto synchronise les données SBG → RBX (delta depuis incident) | ❌ RBX : Inactifs<br>✅ SBG : Actifs | Aucun |
| **9. Démarrage VMs RBX** | ⚠️ **POINT CRITIQUE** : VMs RBX démarrent automatiquement | ⚠️ **RBX : ACTIFS**<br>✅ SBG : Actifs | **DOUBLE EXÉCUTION** |
| **10. Validation Services RBX** | Tests applicatifs sur RBX (peut prendre 15-30min) | ⚠️ **RBX : ACTIFS**<br>✅ SBG : Actifs | **DOUBLE EXÉCUTION** |
| **11. Failback Zerto** | Exécution du failback Zerto (commit du retour vers RBX) | ⚠️ **RBX : ACTIFS**<br>✅ SBG : Actifs | **DOUBLE EXÉCUTION** |
| **12. Bascule DNS/Réseau** | Modification DNS/LB pour pointer vers RBX | ✅ RBX : Actifs<br>⚠️ SBG : Encore actifs | **DOUBLE EXÉCUTION** |
| **13. Arrêt SBG** | Arrêt propre des VMs SBG (après validation RBX stable) | ✅ RBX : Actifs<br>❌ SBG : Arrêt | Fin du risque |

**Fenêtre de risque :** Entre l'étape 9 et 13 (potentiellement **30 à 60 minutes**).

---

## 5. Solutions Proposées

### Solution 1 : **Mode Pause VMware Automatique** (Recommandée)

#### Principe
Configurer les VMs RBX pour qu'elles démarrent en **état "suspendu" (paused)** après restauration, et ne les activer qu'après validation manuelle.

#### Implémentation

**A. Configuration VMware (vSphere)**
- Modifier le paramètre de démarrage des VMs RBX critiques :
  - `powerOnBehavior = "suspended"` ou utiliser un script vSphere PowerCLI
  - Les VMs démarrent mais sont immédiatement mises en pause

**B. Workflow Failback Révisé**
```
1. Restauration RBX → VMs démarrent en mode PAUSE (CRON inactifs)
2. Synchronisation Zerto → Données à jour
3. Validation manuelle :
   - Tests de connectivité réseau
   - Tests de cohérence DB
   - Vérification des montages NFS/Storage
4. ✅ Activation manuelle des VMs RBX (resume)
5. Bascule DNS vers RBX
6. Arrêt VMs SBG
```

**Avantages :**
- ✅ Contrôle total, aucun CRON ne démarre avant validation
- ✅ Pas de modification applicative
- ✅ Respect des SLA (validation avant production)

**Inconvénients :**
- ❌ Nécessite intervention manuelle (automatisable via script)
- ❌ Dépend de la configuration VMware

---

### Solution 2 : **Sémaphore Applicatif avec Fichier Lock**

#### Principe
Implémenter un **verrou logiciel** que chaque CRON vérifie avant exécution.

#### Implémentation

**A. Fichier de configuration central**
- Créer un fichier `/etc/app/pra-status.lock` sur chaque VM
- Contenu : `ACTIVE_SITE=SBG` ou `ACTIVE_SITE=RBX`

**B. Modification des CRON**
```bash
#!/bin/bash
# Exemple : /usr/local/bin/safe-cron-wrapper.sh

ACTIVE_SITE=$(cat /etc/app/pra-status.lock | grep ACTIVE_SITE | cut -d= -f2)
CURRENT_SITE=$(hostname | grep -oE 'rbx|sbg')

if [ "$ACTIVE_SITE" != "$CURRENT_SITE" ]; then
  echo "CRON bloqué : site actif=$ACTIVE_SITE, site actuel=$CURRENT_SITE"
  exit 0
fi

# Exécuter la vraie tâche CRON
/usr/local/bin/ma-tache-metier.sh
```

**C. Workflow Failback Révisé**
```
1. RBX démarre → CRON vérifient /etc/app/pra-status.lock → Trouve "SBG" → Exit silencieux
2. Validation RBX complète
3. ✅ Script Ansible/SSH met à jour pra-status.lock sur RBX : "ACTIVE_SITE=RBX"
4. Bascule DNS
5. Mise à jour pra-status.lock sur SBG : "ACTIVE_SITE=NONE" (sécurité)
6. Arrêt SBG
```

**Avantages :**
- ✅ Solution logicielle, indépendante de l'hyperviseur
- ✅ Traçabilité (logs applicatifs)
- ✅ Automatisable via Ansible/Chef/Puppet

**Inconvénients :**
- ❌ Nécessite modification de **tous** les CRON
- ❌ Risque si le fichier lock est mal synchronisé
- ❌ Maintenance (wrap chaque CRON)

---

### Solution 3 : **Désactivation Temporaire des CRON via Systemd Timer Override**

#### Principe
Utiliser un service systemd qui désactive dynamiquement les timers CRON au boot.

#### Implémentation

**A. Service Systemd "PRA Guard"**
Créer `/etc/systemd/system/pra-guard.service` :
```ini
[Unit]
Description=PRA Guard - Disable CRON on Standby Site
Before=cron.service
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/pra-guard-check.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

**B. Script de vérification**
```bash
#!/bin/bash
# /usr/local/bin/pra-guard-check.sh

CONSUL_KEY="pra/active-site"
ACTIVE_SITE=$(curl -s http://consul.local:8500/v1/kv/$CONSUL_KEY?raw)
CURRENT_SITE=$(hostname | grep -oE 'rbx|sbg')

if [ "$ACTIVE_SITE" != "$CURRENT_SITE" ]; then
  systemctl stop cron.service
  systemctl mask cron.service
  echo "CRON désactivé : site standby"
else
  systemctl unmask cron.service
  systemctl start cron.service
  echo "CRON activé : site actif"
fi
```

**C. Workflow Failback Révisé**
```
1. RBX démarre → pra-guard.service s'exécute → Lit Consul → CRON masqué
2. Validation RBX
3. ✅ Mise à jour Consul : "pra/active-site=RBX"
4. Redémarrage pra-guard.service sur RBX → CRON activé
5. Bascule DNS
6. Mise à jour Consul → SBG passe en standby
7. Arrêt SBG
```

**Avantages :**
- ✅ Centralisé (pas de modification des CRON)
- ✅ Utilise Consul/etcd pour état distribué
- ✅ Réutilisable pour autres services (non seulement CRON)

**Inconvénients :**
- ❌ Dépendance à un service externe (Consul)
- ❌ Complexité de setup initial

---

### Solution 4 : **Orchestration Zerto avec Pre/Post Scripts**

#### Principe
Utiliser les **scripts Zerto** (Pre-failback / Post-failback) pour automatiser la désactivation/activation des CRON.

#### Implémentation

**A. Script Zerto Pre-Failback (Côté RBX)**
Exécuté juste avant le démarrage des VMs RBX :
```bash
#!/bin/bash
# Exécuté sur l'hôte vSphere avant boot des VMs RBX
for vm in $(zerto-cli list-vms --vpg=PROD-RBX); do
  ssh root@$vm "systemctl stop cron && touch /var/lock/pra-failback-in-progress"
done
```

**B. Script Zerto Post-Failback (Après validation)**
```bash
#!/bin/bash
# Exécuté après commit du failback
for vm in $(zerto-cli list-vms --vpg=PROD-RBX); do
  ssh root@$vm "rm /var/lock/pra-failback-in-progress && systemctl start cron"
done
```

**Avantages :**
- ✅ Natif Zerto (intégré au workflow PRA)
- ✅ Automatique

**Inconvénients :**
- ❌ Dépend de la version Zerto et de la licence
- ❌ Nécessite accès SSH entre Zerto et VMs (sécurité)

---

## 6. Matrice de Comparaison

| Critère | Solution 1<br>(VMware Pause) | Solution 2<br>(Fichier Lock) | Solution 3<br>(Systemd + Consul) | Solution 4<br>(Zerto Scripts) |
|---------|:---:|:---:|:---:|:---:|
| **Complexité** | 🟢 Faible | 🟡 Moyenne | 🔴 Élevée | 🟡 Moyenne |
| **Modification Apps** | 🟢 Aucune | 🔴 Tous les CRON | 🟢 Aucune | 🟢 Aucune |
| **Automatisation** | 🟡 Partielle | 🟢 Totale | 🟢 Totale | 🟢 Totale |
| **Dépendances** | VMware API | Aucune | Consul/etcd | Zerto Scripting |
| **Réversibilité** | 🟢 Immédiate | 🟢 Immédiate | 🟢 Immédiate | 🟢 Immédiate |
| **Coût** | 🟢 Nul | 🟢 Nul | 🟡 Setup Consul | 🟢 Inclus Zerto |
| **Risque Erreur** | 🟢 Faible | 🟡 Moyen | 🟡 Moyen | 🟢 Faible |

---

## 7. Recommandation Finale

### Approche Hybride : **Solution 1 + Solution 2**

**Phase 1 (Court terme - 1 semaine) :**
- Implémenter **Solution 1** (VMware Pause) pour sécuriser immédiatement les failbacks
- Créer une procédure manuelle validée

**Phase 2 (Moyen terme - 1 mois) :**
- Déployer **Solution 2** (Fichier Lock) sur les CRON critiques
- Automatiser via Ansible/Terraform

**Pourquoi cette approche ?**
- ✅ Protection immédiate (VMware Pause)
- ✅ Redondance logicielle (Lock File) en cas d'échec VMware
- ✅ Pas de dépendance externe (Consul)
- ✅ Progressif (permet de tester)

---

## 8. Plan d'Action

### Sprint 1 : Sécurisation Immédiate (3 jours)
- [ ] Configurer les VMs RBX avec démarrage en mode suspendu
- [ ] Créer la checklist de validation failback
- [ ] Tester sur un VPG non-critique
- [ ] Former les équipes Ops

### Sprint 2 : Automatisation (2 semaines)
- [ ] Développer le wrapper CRON avec fichier lock
- [ ] Déployer sur 3 CRON pilotes
- [ ] Mesurer l'impact (logs, métriques)
- [ ] Rollout progressif (20% → 50% → 100%)

### Sprint 3 : Industrialisation (1 mois)
- [ ] Intégrer dans l'outillage Zerto (scripts post-failback)
- [ ] Ajouter monitoring (alerte si CRON bloqué > 2h)
- [ ] Documenter la runbook complète
- [ ] Simuler un failback en conditions réelles

---

## 9. Métriques de Succès

| KPI | Cible | Mesure |
|-----|-------|--------|
| Fenêtre de double exécution | 0 min | Logs CRON (timestamps) |
| Temps de failback | < 30 min | Chrono Zerto |
| Incidents de corruption de données | 0 | Tickets post-PRA |
| Conformité procédure | 100% | Checklist validée |

---

## 10. Annexes

### A. Checklist Failback (Version Manuelle)

```
☐ 1. Vérifier l'état de réplication Zerto (RPO < 10s, target : 8s)
☐ 2. Arrêter les CRON sur SBG (systemctl stop cron)
☐ 3. Lancer la synchronisation finale Zerto
☐ 4. Démarrer les VMs RBX en mode pause (ou vérifier auto-pause)
☐ 5. Reprendre les VMs RBX (resume)
☐ 6. Tester connectivité réseau RBX (ping, curl)
☐ 7. Vérifier les logs de recovery des DB (PostgreSQL, MySQL, MongoDB)
    - PostgreSQL : grep "database system is ready" /var/log/postgresql/*.log
    - MySQL : grep "ready for connections" /var/log/mysql/error.log
    - MongoDB : grep "WiredTiger recovery" /var/log/mongodb/mongod.log
☐ 8. Tester accès base de données RBX (select 1, insert test)
☐ 9. Vérifier l'intégrité des montages NFS/Volumes
☐ 10. Lancer 1 CRON manuellement sur RBX (validation)
☐ 11. Basculer le DNS/LB vers RBX
☐ 12. Vérifier absence d'erreurs (logs applicatifs)
☐ 13. Arrêter les VMs SBG
☐ 14. Réactiver la réplication Zerto (RBX → SBG)
☐ 15. Post-mortem (documenter les anomalies, temps de recovery DB)
```

### B. Commandes Utiles

#### Gestion des VMs

```bash
# Pause d'une VM via vSphere CLI
vim-cmd vmsvc/power.suspend <vmid>

# Resume d'une VM
vim-cmd vmsvc/power.on <vmid>

# Lister les VMs et leur état
vim-cmd vmsvc/getallvms
```

#### Gestion des CRON

```bash
# Vérifier l'état des CRON
systemctl status cron

# Lister les CRON actifs
crontab -l
ls -la /etc/cron.d/

# Vérifier les logs CRON
grep CRON /var/log/syslog | tail -50

# Arrêter temporairement les CRON
systemctl stop cron
systemctl mask cron   # Empêche le redémarrage automatique
```

#### Vérification des Bases de Données

```bash
# PostgreSQL - Vérifier le mode recovery
psql -U postgres -c "SELECT pg_is_in_recovery();"

# PostgreSQL - Vérifier le WAL (Write-Ahead Log)
psql -U postgres -c "SELECT pg_current_wal_lsn();"

# MySQL - Vérifier le moteur de stockage (InnoDB recommandé)
mysql -e "SELECT TABLE_SCHEMA, TABLE_NAME, ENGINE FROM information_schema.TABLES WHERE ENGINE='MyISAM';"

# MySQL - Vérifier le statut InnoDB
mysql -e "SHOW ENGINE INNODB STATUS\G" | grep -A 20 "LOG"

# MongoDB - Vérifier le journaling
mongo --eval "db.serverStatus().storageEngine.persistent"
mongo --eval "db.adminCommand({getCmdLineOpts: 1}).parsed.storage.journal.enabled"

# Temps de recovery après crash (vérifier les logs)
# PostgreSQL
grep "database system was interrupted" /var/log/postgresql/postgresql-*.log -A 10

# MySQL
grep "InnoDB: Starting crash recovery" /var/log/mysql/error.log -A 10

# MongoDB
grep "WiredTiger recovery" /var/log/mongodb/mongod.log -A 10
```

#### Monitoring Zerto

```bash
# Vérifier le RPO actuel (via API Zerto si disponible)
curl -k -u admin:password https://zerto-vra:9669/v1/vpgs | jq '.[] | {name: .VpgName, rpo: .ActualRPO}'

# Vérifier l'état de réplication
# (remplacer par la commande spécifique à votre setup Zerto/OVH)
```

### C. Points de Vigilance - Crash Consistent

**À vérifier impérativement avant un failover :**

1. **MySQL :**
   - ✅ Toutes les tables en InnoDB (pas de MyISAM)
   - ✅ `innodb_flush_log_at_trx_commit = 1` (durabilité ACID)
   - ✅ `innodb_doublewrite = ON` (protection contre corruption)

2. **PostgreSQL :**
   - ✅ `fsync = on` (garantie écriture sur disque)
   - ✅ `full_page_writes = on` (protection WAL)
   - ✅ Archivage WAL configuré pour PITR (Point-In-Time Recovery)

3. **MongoDB :**
   - ✅ `storage.journal.enabled = true` (obligatoire pour WiredTiger)
   - ✅ `writeConcern` configuré pour durabilité (w: majority)

**Commandes de validation :**

```bash
# MySQL
mysql -e "SHOW VARIABLES LIKE 'innodb_flush_log_at_trx_commit';"
mysql -e "SHOW VARIABLES LIKE 'innodb_doublewrite';"

# PostgreSQL
psql -U postgres -c "SHOW fsync;"
psql -U postgres -c "SHOW full_page_writes;"

# MongoDB
mongo --eval "db.serverCmdLineOpts().parsed.storage.journal"
```

---

**Validation requise :** Ce document doit être validé par l'équipe Infra/PRA avant implémentation.