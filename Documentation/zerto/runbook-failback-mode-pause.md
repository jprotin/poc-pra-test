# Runbook : Failback Zerto - Mode Pause VMware Automatique

**Version :** 1.0
**Date :** 2025-12-30
**Auteur :** Équipe DevOps / Ops PRA
**Stratégie :** Mode Pause VMware Automatique
**ADR Associé :** [ADR-2025-12-30](../adr/2025-12-30-strategie-failback-mode-pause-vmware.md)

---

## 📖 Table des Matières

1. [Vue d'ensemble](#vue-densemble)
2. [Prérequis](#prérequis)
3. [Workflow Failback Complet](#workflow-failback-complet)
4. [Procédure Détaillée](#procédure-détaillée)
5. [Gestion des Incidents](#gestion-des-incidents)
6. [Rollback et Plan B](#rollback-et-plan-b)
7. [Contacts et Escalade](#contacts-et-escalade)

---

## Vue d'ensemble

### Objectif

Ce runbook décrit la procédure opérationnelle **complète** pour exécuter un failback Zerto (retour à la normale SBG → RBX) en utilisant la stratégie **Mode Pause VMware Automatique**.

### Contexte

Après un incident sur le site primaire RBX, les applications tournent sur le site de secours SBG. Une fois l'incident résolu, nous devons retourner en mode de production normal (RBX actif, SBG en standby).

**Problème résolu par ce runbook :** Éviter la double exécution des tâches CRON pendant le failback.

### Périmètre

- **Sites concernés :** RBX (Roubaix) et SBG (Strasbourg)
- **VMs concernées :**
  - VM-DOCKER-APP-A-RBX (10.100.0.10)
  - VM-MYSQL-APP-A-RBX (10.100.0.11)
  - VM-DOCKER-APP-B-SBG (10.200.0.10)
  - VM-MYSQL-APP-B-SBG (10.200.0.11)
- **VPG Zerto :** VPG-RBX-TO-SBG et VPG-SBG-TO-RBX

### Durée Estimée

- **RTO Cible :** < 30 minutes
- **Durée typique :** 25-30 minutes
  - Phase 1 (Restauration) : 5-7 minutes
  - Phase 2 (Validation) : 10-15 minutes
  - Phase 3 (Activation) : 5 minutes
  - Phase 4 (Bascule Production) : 5-8 minutes

---

## Prérequis

### Compétences Requises

- [ ] Accès administrateur vSphere (RBX et SBG)
- [ ] Accès administrateur Zerto
- [ ] Accès SSH aux VMs (utilisateur `vmadmin`)
- [ ] Connaissance des applications déployées
- [ ] Accès au DNS/Load Balancer

### Outils Nécessaires

- [ ] Client vSphere ou govc CLI
- [ ] Interface Zerto (https://zerto-api.ovh.net)
- [ ] Terminal SSH avec accès au jumpbox
- [ ] Accès au dashboard de monitoring (Prometheus/Grafana)
- [ ] Checklist de validation (checklist-failback-mode-pause.md)

### Variables d'Environnement

```bash
# Charger les variables d'environnement
source /path/to/poc-pra-test/.env

# Vérifier que les variables failback sont définies
echo $TF_VAR_enable_failback_pause_mode  # Doit être "true"
echo $TF_VAR_failback_site               # Doit être "rbx"
```

### État Préalable

**Avant de commencer, vérifier que :**
- [ ] L'incident sur RBX est résolu
- [ ] L'infrastructure RBX (réseau, stockage, hyperviseur) est opérationnelle
- [ ] Les applications tournent correctement sur SBG
- [ ] Aucun failover/failback n'est en cours
- [ ] Équipe Ops disponible pour superviser l'opération

---

## Workflow Failback Complet

```
┌─────────────────────────────────────────────────────────────────────┐
│ ÉTAT INITIAL : Applications actives sur SBG (après incident RBX)   │
└─────────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────────┐
│ PHASE 1 : RESTAURATION (Automatique via Zerto)                     │
├─────────────────────────────────────────────────────────────────────┤
│ 1.1 Déclencher failback Zerto (SBG → RBX)                          │
│ 1.2 Synchronisation finale des données                              │
│ 1.3 Démarrage VMs RBX en mode PAUSE (CRON inactifs)                │
│     ✅ État : VMs RBX = SUSPENDED                                   │
│     ✅ État : VMs SBG = RUNNING (applications actives)              │
└─────────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────────┐
│ PHASE 2 : VALIDATION (Manuelle - Checklist obligatoire)            │
├─────────────────────────────────────────────────────────────────────┤
│ 2.1 Vérifier état réplication Zerto (RPO < 5min)                   │
│ 2.2 Confirmer VMs RBX en état SUSPENDED                            │
│ 2.3 Tester connectivité réseau RBX (ping gateway, vRack)           │
│ 2.4 Vérifier montages NFS/Volumes                                  │
│ 2.5 Tester cohérence base de données (select 1, schemas)           │
│ 2.6 Vérifier logs Zerto (aucune erreur)                            │
│     ✅ Validation : OK pour activation RBX                          │
└─────────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────────┐
│ PHASE 3 : ACTIVATION (Manuelle)                                     │
├─────────────────────────────────────────────────────────────────────┤
│ 3.1 ✅ Activation manuelle VMs RBX (Resume)                         │
│     Commande : ./scripts/zerto/resume-vms-rbx.sh --site rbx        │
│ 3.2 Attendre démarrage complet services (MySQL, Docker)            │
│ 3.3 Test applicatif sur RBX (healthcheck endpoints)                │
│     ✅ État : VMs RBX = RUNNING                                     │
│     ⚠️ État : VMs SBG = RUNNING (encore actives)                    │
└─────────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────────┐
│ PHASE 4 : BASCULE PRODUCTION (Manuelle)                             │
├─────────────────────────────────────────────────────────────────────┤
│ 4.1 Modification DNS/Load Balancer → RBX                            │
│ 4.2 Vérification trafic utilisateur sur RBX                         │
│ 4.3 Arrêt propre VMs SBG                                            │
│ 4.4 Réactivation réplication Zerto (RBX → SBG)                     │
│     ✅ État : VMs RBX = RUNNING (production)                        │
│     ✅ État : VMs SBG = OFF (standby)                               │
└─────────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────────┐
│ ÉTAT FINAL : Retour à la normale (RBX actif, SBG standby)          │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Procédure Détaillée

### PHASE 1 : RESTAURATION (Automatique via Zerto)

#### 1.1 Déclencher le Failback Zerto

**Durée :** 2-3 minutes

**Actions :**

1. **Se connecter à l'interface Zerto**
   ```
   URL : https://zerto-api.ovh.net
   Utilisateur : <zerto_admin_user>
   ```

2. **Naviguer vers le VPG concerné**
   - Onglet "VPGs"
   - Sélectionner : `VPG-SBG-TO-RBX` (failback vers RBX)

3. **Vérifier l'état du VPG**
   - Status : "Meeting SLA" (vert)
   - RPO : < 5 minutes
   - Journal : Aucune erreur

4. **Initier le failback**
   - Clic droit sur le VPG → "Failback"
   - **Type :** Commit (production failback)
   - **Direction :** SBG → RBX
   - **Options :**
     - ☑ Reverse protection (inverser la réplication)
     - ☐ Shutdown source VMs (NE PAS cocher - on le fera manuellement)
   - Cliquer "Start Failback"

**Résultat attendu :**
- Zerto commence la synchronisation finale
- Les VMs RBX se préparent à démarrer

---

#### 1.2 Synchronisation Finale des Données

**Durée :** 3-5 minutes (dépend de la taille du delta)

**Actions :**

1. **Surveiller la progression dans Zerto**
   - Onglet "Failback" → Voir la progression
   - Métriques :
     - Data synchronized : 100%
     - Remaining time : 0 min

2. **Vérifier les logs Zerto**
   ```bash
   # Depuis un jumpbox avec accès API Zerto
   curl -H "Authorization: Bearer $ZERTO_API_TOKEN" \
        https://zerto-api.ovh.net/v1/tasks | jq '.tasks[] | select(.Type=="Failback")'
   ```

**Résultat attendu :**
- Synchronisation complétée à 100%
- Status : "Waiting for Commit"

---

#### 1.3 Démarrage VMs RBX en Mode PAUSE

**Durée :** 1-2 minutes

**Actions :**

1. **Zerto démarre automatiquement les VMs RBX**
   - Les VMs démarrent grâce à la configuration `extra_config` Terraform
   - Configuration appliquée :
     ```hcl
     "pra.failback.startup_mode" = "suspended"
     "pra.failback.site"         = "rbx"
     ```

2. **Vérifier que les VMs sont en mode SUSPENDED**
   ```bash
   # Via govc CLI
   govc vm.info -json VM-DOCKER-APP-A-RBX | jq '.VirtualMachines[0].Runtime.PowerState'
   # Résultat attendu : "suspended"

   govc vm.info -json VM-MYSQL-APP-A-RBX | jq '.VirtualMachines[0].Runtime.PowerState'
   # Résultat attendu : "suspended"
   ```

3. **Vérifier que le script post-failback Zerto s'est exécuté**
   ```bash
   # Consulter les logs sur le serveur Zerto
   ssh zerto-server "tail -100 /var/log/zerto/post-failback-suspend.log"
   ```

**Résultat attendu :**
- ✅ VMs RBX en état "suspended"
- ✅ CRON inactifs sur RBX (les VMs sont pausées)
- ✅ VMs SBG toujours actives (applications fonctionnelles)

**⚠️ POINT DE CONTRÔLE CRITIQUE**
> Si les VMs RBX sont en état "poweredOn" au lieu de "suspended", **ARRÊTER IMMÉDIATEMENT**.
> Suspendre manuellement les VMs :
> ```bash
> vim-cmd vmsvc/power.suspend <vmid>
> ```

---

### PHASE 2 : VALIDATION (Manuelle - Checklist Obligatoire)

**Durée :** 10-15 minutes

**Actions :**

Ouvrir le fichier `checklist-failback-mode-pause.md` et compléter **TOUTES** les étapes.

```bash
# Ouvrir la checklist
vim Documentation/zerto/checklist-failback-mode-pause.md

# Ou utiliser un outil de suivi
# Chaque étape doit être marquée comme ☑ avant de continuer
```

**Étapes principales :**
1. ☐ Vérifier RPO Zerto < 5 min
2. ☐ Confirmer VMs RBX en état SUSPENDED
3. ☐ Tester connectivité réseau RBX
4. ☐ Vérifier montages NFS/Volumes
5. ☐ Valider intégrité MySQL
6. ☐ Vérifier logs Zerto
7. ☐ **Validation Ops : OK pour activation**

**Résultat attendu :**
- Toutes les cases cochées
- Validation formelle de l'équipe Ops

**⚠️ Si une étape échoue :**
- Ne pas continuer
- Consulter la section [Gestion des Incidents](#gestion-des-incidents)

---

### PHASE 3 : ACTIVATION (Manuelle)

#### 3.1 Activation Manuelle des VMs RBX

**Durée :** 2-3 minutes

**Actions :**

1. **Exécuter le script d'activation**
   ```bash
   cd /path/to/poc-pra-test

   # Activer toutes les VMs du site RBX
   ./scripts/zerto/resume-vms-rbx.sh \
       --site rbx \
       --vpg-name VPG-SBG-TO-RBX
   ```

2. **Le script affiche la checklist et demande confirmation**
   ```
   ╔══════════════════════════════════════════════════════════════════╗
   ║            CHECKLIST DE VALIDATION FAILBACK                      ║
   ╚══════════════════════════════════════════════════════════════════╝

   Avez-vous complété toute la checklist ? (oui/non) : oui
   Confirmez-vous l'activation des VMs rbx ? (oui/non) : oui
   ```

3. **Suivre les logs d'activation**
   ```bash
   # Dans un autre terminal
   tail -f /var/log/zerto/resume-vms.log
   ```

**Résultat attendu :**
```
✅ VM 'VM-DOCKER-APP-A-RBX' activée avec succès
✅ VM 'VM-MYSQL-APP-A-RBX' activée avec succès
========================================
Résumé de l'opération :
  - VMs activées avec succès : 2
  - VMs en échec : 0
========================================
```

---

#### 3.2 Attendre Démarrage Complet des Services

**Durée :** 2-3 minutes

**Actions :**

1. **Surveiller le démarrage de MySQL**
   ```bash
   ssh vmadmin@10.100.0.11 "sudo systemctl status mysql"
   # Attendre : Active: active (running)

   # Vérifier les logs MySQL
   ssh vmadmin@10.100.0.11 "sudo tail -50 /var/log/mysql/error.log"
   ```

2. **Surveiller le démarrage de Docker**
   ```bash
   ssh vmadmin@10.100.0.10 "sudo systemctl status docker"
   # Attendre : Active: active (running)

   # Vérifier que les conteneurs démarrent
   ssh vmadmin@10.100.0.10 "sudo docker ps"
   ```

**Résultat attendu :**
- MySQL : Active (running)
- Docker : Active (running)
- Conteneurs applicatifs : Up (running)

---

#### 3.3 Test Applicatif sur RBX

**Durée :** 1-2 minutes

**Actions :**

1. **Tester les endpoints de healthcheck**
   ```bash
   # Healthcheck HTTP
   curl -I http://10.100.0.10/health
   # Résultat attendu : HTTP/1.1 200 OK

   # Healthcheck applicatif
   curl http://10.100.0.10/api/status
   # Résultat attendu : {"status":"ok"}
   ```

2. **Tester la connexion MySQL depuis Docker**
   ```bash
   ssh vmadmin@10.100.0.10 \
       "docker exec app-container mysql -h 10.100.0.11 -u appuser -p<password> -e 'SELECT 1;'"
   # Résultat attendu : 1
   ```

3. **Vérifier qu'aucune erreur applicative n'apparaît**
   ```bash
   ssh vmadmin@10.100.0.10 "sudo docker logs app-container --tail 50"
   ```

**Résultat attendu :**
- Tous les tests passent avec succès
- Aucune erreur critique dans les logs

---

### PHASE 4 : BASCULE PRODUCTION (Manuelle)

#### 4.1 Modification DNS/Load Balancer vers RBX

**Durée :** 3-5 minutes

**Actions :**

**Option A : Modification DNS**

1. **Se connecter au gestionnaire DNS**
   - Provider : OVH, Cloudflare, etc.

2. **Modifier l'enregistrement A**
   ```
   Ancien :
   app.example.com  A  51.xxx.xxx.xxx (IP publique SBG)

   Nouveau :
   app.example.com  A  51.yyy.yyy.yyy (IP publique RBX)
   ```

3. **Réduire le TTL (si nécessaire)**
   ```
   TTL : 60 secondes (pour propagation rapide)
   ```

4. **Vérifier la propagation DNS**
   ```bash
   dig app.example.com +short
   # Résultat attendu : 51.yyy.yyy.yyy (IP RBX)

   # Tester depuis différentes localisations
   nslookup app.example.com 8.8.8.8
   ```

**Option B : Modification Load Balancer**

1. **Se connecter au Load Balancer (FortiGate, HAProxy, etc.)**

2. **Modifier la configuration des backends**
   ```
   Backend RBX : Actif (weight 100)
   Backend SBG : Désactivé (weight 0) ou Backup
   ```

3. **Appliquer la configuration**

**Résultat attendu :**
- Nouveau trafic dirigé vers RBX
- Ancien trafic SBG se termine gracieusement

---

#### 4.2 Vérification Trafic Utilisateur sur RBX

**Durée :** 2-3 minutes

**Actions :**

1. **Surveiller les logs d'accès**
   ```bash
   ssh vmadmin@10.100.0.10 "sudo tail -f /var/log/nginx/access.log"
   # Rechercher : nouvelles requêtes entrantes
   ```

2. **Vérifier les métriques Prometheus/Grafana**
   - Dashboard : "Traffic Overview"
   - Métriques :
     - Requests/s RBX : Augmentation
     - Requests/s SBG : Diminution vers 0

3. **Vérifier la latence**
   ```bash
   curl -w "@curl-format.txt" -o /dev/null -s http://app.example.com
   # Vérifier : time_total < 500ms
   ```

**Résultat attendu :**
- Trafic visible sur RBX
- Latence acceptable (< 500ms)
- Aucune erreur 5xx

---

#### 4.3 Arrêt Propre des VMs SBG

**Durée :** 2-3 minutes

**Actions :**

1. **Vérifier qu'il n'y a plus de trafic sur SBG**
   ```bash
   ssh vmadmin@10.200.0.10 "sudo tail -20 /var/log/nginx/access.log"
   # Vérifier : pas de nouvelles requêtes depuis 2-3 minutes
   ```

2. **Arrêter les conteneurs Docker sur SBG**
   ```bash
   ssh vmadmin@10.200.0.10 "sudo docker-compose down"
   ```

3. **Arrêter les VMs SBG via vSphere**
   ```bash
   govc vm.power -off VM-DOCKER-APP-B-SBG
   govc vm.power -off VM-MYSQL-APP-B-SBG
   ```

4. **Vérifier l'arrêt**
   ```bash
   govc vm.info VM-DOCKER-APP-B-SBG | grep "Power state"
   # Résultat attendu : poweredOff
   ```

**Résultat attendu :**
- VMs SBG arrêtées proprement
- Aucun processus actif sur SBG

---

#### 4.4 Réactivation Réplication Zerto (RBX → SBG)

**Durée :** 2-3 minutes

**Actions :**

1. **Se connecter à l'interface Zerto**

2. **Activer le VPG : VPG-RBX-TO-SBG**
   - Onglet "VPGs"
   - Sélectionner `VPG-RBX-TO-SBG`
   - Clic droit → "Start Protection"

3. **Vérifier que la réplication démarre**
   - Status : "Initializing" → "Meeting SLA"
   - RPO initial : < 5 minutes

4. **Vérifier la configuration du VPG**
   - Direction : RBX → SBG ✅
   - VMs protégées :
     - VM-DOCKER-APP-A-RBX ✅
     - VM-MYSQL-APP-A-RBX ✅

**Résultat attendu :**
- Réplication active (RBX → SBG)
- RPO < 5 minutes
- Journal Zerto opérationnel

---

### PHASE 5 : POST-MORTEM ET DOCUMENTATION

#### 5.1 Compléter le Post-Mortem

**Actions :**

1. **Documenter les métriques**
   - Durée totale du failback : \_\_\_\_ minutes
   - RTO respecté (< 30 min) : Oui / Non
   - Incidents rencontrés : [Liste]

2. **Identifier les améliorations**
   - Qu'est-ce qui a bien fonctionné ?
   - Qu'est-ce qui peut être amélioré ?
   - Actions correctives à planifier

3. **Mettre à jour la documentation**
   - Si des étapes ont changé, mettre à jour ce runbook
   - Ajouter des notes dans la section "Leçons Apprises"

---

## Gestion des Incidents

### Incident : VMs RBX ne démarrent pas en mode SUSPENDED

**Symptôme :** Les VMs RBX sont en état "poweredOn" au lieu de "suspended".

**Cause probable :**
- Configuration `extra_config` non appliquée
- Script post-failback Zerto non exécuté

**Action corrective :**

1. **Suspendre manuellement les VMs immédiatement**
   ```bash
   vim-cmd vmsvc/power.suspend <vmid>
   ```

2. **Vérifier la configuration VMware**
   ```bash
   govc vm.info -json VM-DOCKER-APP-A-RBX | \
       jq '.VirtualMachines[0].Config.ExtraConfig[] | select(.Key=="pra.failback.enabled")'
   ```

3. **Si la configuration est absente, la corriger**
   ```bash
   # Appliquer la configuration manuellement via Terraform
   cd terraform/ovh-infrastructure
   terraform apply -var enable_failback_pause_mode=true -var failback_site=rbx
   ```

---

### Incident : Impossibilité de se connecter à MySQL après activation

**Symptôme :** MySQL ne démarre pas ou refuse les connexions.

**Cause probable :**
- Corruption de données MySQL
- Problème de montage du disque de données

**Action corrective :**

1. **Vérifier les logs MySQL**
   ```bash
   ssh vmadmin@10.100.0.11 "sudo tail -100 /var/log/mysql/error.log"
   ```

2. **Vérifier les montages**
   ```bash
   ssh vmadmin@10.100.0.11 "df -h"
   ssh vmadmin@10.100.0.11 "mount | grep mysql"
   ```

3. **Si corruption détectée, restaurer depuis backup**
   ```bash
   # Arrêter MySQL
   ssh vmadmin@10.100.0.11 "sudo systemctl stop mysql"

   # Restaurer depuis le dernier backup Veeam/mysqldump
   # (Procédure détaillée dans emergency-backup runbook)
   ```

4. **Si le problème persiste, considérer le rollback**
   - Voir section [Rollback et Plan B](#rollback-et-plan-b)

---

### Incident : Trafic utilisateur ne bascule pas vers RBX

**Symptôme :** Le trafic continue d'aller vers SBG après modification DNS.

**Cause probable :**
- TTL DNS trop élevé (cache DNS)
- Problème de propagation DNS
- Load Balancer non mis à jour

**Action corrective :**

1. **Vérifier la propagation DNS**
   ```bash
   dig app.example.com +short
   nslookup app.example.com 8.8.8.8
   ```

2. **Attendre l'expiration du TTL**
   - Si TTL = 3600s (1h), attendre jusqu'à 1h

3. **Forcer le rafraîchissement DNS (si possible)**
   - Cloudflare : Purge cache DNS
   - Clients : `ipconfig /flushdns` (Windows) ou `sudo systemd-resolve --flush-caches` (Linux)

4. **En dernier recours : forcer via Load Balancer**
   - Désactiver complètement le backend SBG
   - Toutes les connexions iront vers RBX

---

## Rollback et Plan B

### Scénario : Échec du Failback - Retour Forcé sur SBG

**Quand l'utiliser :**
- Si le failback échoue après Phase 3 (activation VMs RBX)
- Si des erreurs critiques apparaissent sur RBX
- Si le RTO dépasse 45 minutes

**Procédure de Rollback :**

1. **Arrêter immédiatement les VMs RBX**
   ```bash
   govc vm.power -off VM-DOCKER-APP-A-RBX
   govc vm.power -off VM-MYSQL-APP-A-RBX
   ```

2. **S'assurer que SBG est toujours actif**
   ```bash
   ssh vmadmin@10.200.0.10 "sudo systemctl status docker"
   ssh vmadmin@10.200.0.11 "sudo systemctl status mysql"
   ```

3. **Revenir au DNS/LB SBG**
   ```
   app.example.com  A  51.xxx.xxx.xxx (IP SBG)
   ```

4. **Annuler le failback Zerto**
   - Interface Zerto → VPG → "Abort Failback"

5. **Documenter l'échec**
   - Incident ticket
   - Root Cause Analysis (RCA)

**Résultat :**
- Applications redeviennent actives sur SBG
- Failback à retenter après analyse RCA

---

## Contacts et Escalade

### Équipe Ops PRA

| Rôle | Contact | Téléphone | Email |
|------|---------|-----------|-------|
| Lead Ops PRA | [Nom] | +33 X XX XX XX XX | [email] |
| Ops Engineer 1 | [Nom] | +33 X XX XX XX XX | [email] |
| Ops Engineer 2 | [Nom] | +33 X XX XX XX XX | [email] |

### Support Zerto OVH

| Support | Contact | Disponibilité |
|---------|---------|---------------|
| Support OVH Zerto | support-zerto@ovh.com | 24/7 |
| Téléphone | 1007 (depuis un téléphone OVH) | 24/7 |

### Escalade

**Niveau 1 :** Ops Engineer (résolution dans les 15 minutes)
**Niveau 2 :** Lead Ops PRA (résolution dans les 30 minutes)
**Niveau 3 :** Support OVH Zerto (si problème Zerto/Infrastructure)

---

## Annexes

### A. Commandes Utiles

```bash
# Lister toutes les VMs et leur état
govc find / -type m | xargs -I {} govc vm.info {}

# Suspendre une VM
vim-cmd vmsvc/power.suspend <vmid>

# Activer une VM suspendue
vim-cmd vmsvc/power.on <vmid>

# Vérifier RPO Zerto via API
curl -H "Authorization: Bearer $ZERTO_API_TOKEN" \
     https://zerto-api.ovh.net/v1/vpgs | jq '.[] | {name, rpo}'

# Surveiller les CRON actifs
ssh vmadmin@<vm> "ps aux | grep cron"
ssh vmadmin@<vm> "grep CRON /var/log/syslog | tail -20"
```

### B. Checklist Résumée

```
☐ Phase 1 : Restauration (Automatique)
  ☐ Déclencher failback Zerto
  ☐ Attendre synchronisation finale
  ☐ Vérifier VMs RBX en mode SUSPENDED

☐ Phase 2 : Validation (Manuelle)
  ☐ Compléter checklist-failback-mode-pause.md
  ☐ Validation Ops formelle

☐ Phase 3 : Activation (Manuelle)
  ☐ Exécuter resume-vms-rbx.sh
  ☐ Vérifier démarrage services
  ☐ Tests applicatifs

☐ Phase 4 : Bascule Production (Manuelle)
  ☐ Modifier DNS/LB vers RBX
  ☐ Vérifier trafic utilisateur
  ☐ Arrêter VMs SBG
  ☐ Réactiver réplication Zerto

☐ Phase 5 : Post-Mortem
  ☐ Documenter la durée et incidents
  ☐ Identifier améliorations
```

---

**Dernière mise à jour :** 2025-12-30
**Prochaine révision :** Après le premier failback réel en production
