# Stratégie Failback Zerto - Gestion des Tâches CRON

**Date :** 2025-12-30
**Statut :** ✅ **ACCEPTÉ** - Solution 1 (Mode Pause VMware) adoptée comme standard
**Auteur :** Équipe DevOps / Architecture / Ops PRA
**ADR Associé :** [ADR-2025-12-30 - Stratégie Failback Mode Pause VMware](../adr/2025-12-30-strategie-failback-mode-pause-vmware.md)

---

> **⚠️ IMPORTANT :** Ce document présente la stratégie officielle de failback Zerto basée sur le **Mode Pause VMware Automatique**.
> Pour les détails de la décision, les alternatives rejetées et le plan d'implémentation complet, consulter l'ADR ci-dessus.

---

## 1. Contexte & Problématique

### Situation Actuelle
Les applications déployées sur les VMs (RBX primaire, SBG secours) contiennent des **tâches CRON** critiques. Lors d'un incident et du retour à la normale, une **fenêtre de risque** apparaît :

**Problème identifié :**
- Les VMs sur RBX redémarrent/sont accessibles **avant** la bascule DNS/applicative officielle
- Pendant cette fenêtre, **les CRON tournent en parallèle** sur RBX (site primaire restauré) ET SBG (site de secours encore actif)
- **Risque :** Traitement en double, corruption de données, incohérences métier

---

## 2. Processus PRA Actuel - Analyse Détaillée

### 2.1 Phase 1 : Détection de l'Incident (RBX → SBG)

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

### 2.2 Phase 2 : Retour à la Normale (SBG → RBX) - **ZONE À RISQUE**

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

## 3. Solution Adoptée : **Mode Pause VMware Automatique**

> **✅ SOLUTION STANDARD OFFICIELLE** - Cette approche est désormais la procédure par défaut pour tous les failbacks Zerto.

### Résumé

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

**Justification du choix :**
- ✅ **Sécurité maximale** : Aucun CRON ne démarre avant validation
- ✅ **Simplicité** : Pas de modification applicative
- ✅ **Conformité** : Respect des SLA avec validation avant production
- ✅ **Coût** : Aucun surcoût d'infrastructure

**Note :** L'intervention manuelle est un garde-fou voulu, pas une limitation. Le RTO reste < 30 minutes (compatible avec les SLA).

---

## 4. Alternatives Considérées (Rejetées)

Les solutions suivantes ont été évaluées et rejetées. Pour le détail complet de l'analyse, voir [l'ADR associé](../adr/2025-12-30-strategie-failback-mode-pause-vmware.md).

### Solution 2 (Rejetée) : **Sémaphore Applicatif avec Fichier Lock**

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

**Pourquoi rejetée :**
- ❌ Nécessite modification de **tous** les CRON (dette technique majeure)
- ❌ Risque de régression si un CRON n'est pas modifié
- ❌ Maintenance complexe pour chaque nouvelle tâche CRON

---

### Solution 3 (Rejetée) : **Désactivation Temporaire des CRON via Systemd Timer Override**

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

**Pourquoi rejetée :**
- ❌ Dépendance critique à Consul/etcd (SPOF)
- ❌ Complexité accrue (cluster à maintenir)
- ❌ Coût supplémentaire (3+ VMs Consul)
- ❌ Délai de déploiement : 2-3 semaines vs 3 jours pour Solution 1

---

### Solution 4 (Rejetée) : **Orchestration Zerto avec Pre/Post Scripts uniquement**

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

**Pourquoi rejetée :**
- ❌ **Fenêtre de risque incompressible** : 10-30 secondes entre boot VM et exécution du script
- ❌ Dépendance SSH et réseau (échec si réseau non opérationnel)
- ❌ Race condition possible (CRON démarrent avant le script)

---

## 5. Implémentation de la Solution

### Modifications Infrastructure as Code (Terraform)

**Fichiers modifiés :**
- `modules/06-ovh-vm-docker/main.tf` : Ajout configuration `extra_config` pour mode pause
- `modules/07-ovh-vm-mysql/main.tf` : Ajout configuration `extra_config` pour mode pause
- `modules/06-ovh-vm-docker/variables.tf` : Nouvelles variables `enable_failback_pause_mode`, `failback_site`
- `modules/07-ovh-vm-mysql/variables.tf` : Nouvelles variables `enable_failback_pause_mode`, `failback_site`
- `zerto/terraform/modules/zerto-vpg-vmware/` : Scripts de post-failback suspend

**Variables d'environnement ajoutées :**
```bash
# Failback Mode Pause (Solution 1 - Standard)
export TF_VAR_enable_failback_pause_mode="true"  # 🟢 Activer le mode pause pour failback
export TF_VAR_failback_site="rbx"                # 🟢 Site primaire (rbx ou sbg)
```

### Scripts de Gestion

**Nouveau script d'activation :**
- `scripts/zerto/resume-vms-rbx.sh` : Active (resume) les VMs RBX après validation

**Script Zerto post-failback :**
- `zerto/terraform/modules/zerto-vpg-vmware/scripts/post-failback-suspend.sh` : Suspend automatiquement les VMs après restauration

### Documentation Opérationnelle

**Nouveaux documents créés :**
- `Documentation/zerto/checklist-failback-mode-pause.md` : Checklist de validation obligatoire
- `Documentation/zerto/runbook-failback-mode-pause.md` : Procédure détaillée étape par étape

---

## 6. Procédure Opérationnelle Standard (Résumé)

Pour la procédure détaillée complète, voir le [Runbook Failback Mode Pause](./runbook-failback-mode-pause.md).

### Workflow Simplifié

1. **Restauration** (Automatique) : Zerto restaure les VMs RBX en mode PAUSE
2. **Validation** (Manuelle) : Exécution de la checklist de validation (réseau, DB, montages)
3. **Activation** (Manuelle) : `./scripts/zerto/resume-vms-rbx.sh`
4. **Bascule** (Manuelle) : Modification DNS/LB vers RBX
5. **Désactivation secours** (Manuelle) : Arrêt des VMs SBG

### RTO (Recovery Time Objective)

- **Temps total estimé :** 25-30 minutes
- **Compatible avec SLA :** RTO < 1h ✅

---

## 7. Plan d'Action (Mise à Jour)

### ✅ Sprint 1 : Sécurisation Immédiate (3 jours) - EN COURS

- [x] Créer l'ADR de décision
- [x] Mettre à jour la documentation stratégie failback
- [ ] Modifier les modules Terraform VM
- [ ] Créer les scripts de failback
- [ ] Tester sur VMs de qualification

### Sprint 2 : Tests et Formation (1 semaine)

- [ ] Test failback simulé sur VPG non-critique
- [ ] Formation équipe Ops (2h avec simulation)
- [ ] Mesure RTO réel vs cible
- [ ] Ajustements procédure

### Sprint 3 : Déploiement Production (1 semaine)

- [ ] Déploiement sur VPG Production
- [ ] Activation monitoring (alertes VM suspended)
- [ ] Post-mortem et retours d'expérience

---

## 8. Métriques de Succès

| KPI | Cible | Mesure |
|-----|-------|--------|
| Fenêtre de double exécution | 0 min | Logs CRON (timestamps) |
| Temps de failback | < 30 min | Chrono Zerto |
| Incidents de corruption de données | 0 | Tickets post-PRA |
| Conformité procédure | 100% | Checklist validée |

---

## 9. Annexes

### A. Checklist Failback (Version Manuelle)

```
☐ 1. Vérifier l'état de réplication Zerto (RPO < 5min)
☐ 2. Arrêter les CRON sur SBG (systemctl stop cron)
☐ 3. Lancer la synchronisation finale Zerto
☐ 4. Démarrer les VMs RBX en mode pause (ou vérifier auto-pause)
☐ 5. Reprendre les VMs RBX (resume)
☐ 6. Tester connectivité réseau RBX (ping, curl)
☐ 7. Tester accès base de données RBX (select 1)
☐ 8. Vérifier l'intégrité des montages NFS/Volumes
☐ 9. Lancer 1 CRON manuellement sur RBX (validation)
☐ 10. Basculer le DNS/LB vers RBX
☐ 11. Vérifier absence d'erreurs (logs applicatifs)
☐ 12. Arrêter les VMs SBG
☐ 13. Réactiver la réplication Zerto (RBX → SBG)
☐ 14. Post-mortem (documenter les anomalies)
```

### B. Commandes Utiles

```bash
# Vérifier l'état des CRON
systemctl status cron

# Lister les CRON actifs
crontab -l
ls -la /etc/cron.d/

# Vérifier les logs CRON
grep CRON /var/log/syslog | tail -50

# Pause d'une VM via vSphere CLI
vim-cmd vmsvc/power.suspend <vmid>

# Resume d'une VM
vim-cmd vmsvc/power.on <vmid>
```

---

**Validation requise :** Ce document doit être validé par l'équipe Infra/PRA avant implémentation.