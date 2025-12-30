# Stratégie de Failback Zerto : Mode Pause VMware Automatique

* **Statut :** Accepté
* **Date :** 2025-12-30
* **Décideurs :** Équipe DevOps / Architecture / Ops PRA
* **Tags :** PRA, Zerto, Failback, VMware, CRON, Data Integrity

## Contexte

### Problématique identifiée

Dans le cadre du Plan de Reprise d'Activité (PRA) entre RBX (site primaire) et SBG (site de secours), nous avons identifié un **risque critique de corruption de données** lors des opérations de failback (retour à la normale SBG → RBX).

**Scénario problématique :**
1. Incident sur RBX → Failover vers SBG (applications actives sur SBG)
2. Retour à la normale → Restauration et démarrage des VMs sur RBX
3. **FENÊTRE DE RISQUE** : Les VMs RBX démarrent automatiquement et les tâches CRON s'exécutent **avant** la bascule DNS/applicative officielle
4. Pendant 30 à 60 minutes, les CRON tournent **en parallèle** sur RBX ET SBG
5. **Conséquence** : Traitement en double, corruption de données, incohérences métier critiques

### Contraintes techniques

- Applications déployées via Docker sur VMs Ubuntu 22.04
- Bases de données MySQL 8.0 avec tâches CRON métier critiques
- Infrastructure VMware vSphere 7.x sur OVH Private Cloud
- Réplication Zerto avec RPO < 5 minutes
- Impératif de conformité : Aucune double exécution de processus métier

### Impact métier

Le risque de double exécution affecte :
- **Intégrité des données** : Transactions financières, commandes, synchronisations
- **Cohérence métier** : Rapports, exports, calculs batch
- **Conformité** : Traçabilité et auditabilité des opérations

## Décision

**Nous adoptons la Solution 1 "Mode Pause VMware Automatique" comme stratégie standard et définitive pour tous les failbacks Zerto.**

### Principe de fonctionnement

Les Virtual Machines sur le site primaire RBX sont configurées pour démarrer dans un **état suspendu (paused)** après restauration par Zerto. Elles ne sont activées qu'après validation manuelle explicite par l'équipe Ops.

### Implémentation technique

#### A. Configuration VMware vSphere

Les VMs RBX critiques (Docker et MySQL) sont provisionnées avec une configuration `extra_config` VMware spécifique :

```hcl
# Terraform - modules/06-ovh-vm-docker/main.tf et modules/07-ovh-vm-mysql/main.tf
resource "vsphere_virtual_machine" "vm" {
  # ... configuration standard ...

  extra_config = {
    # Configuration existante (cloud-init)
    "guestinfo.metadata" = base64encode(local.cloud_init_config)

    # NOUVEAU : Configuration Failback Mode Pause
    "pra.failback.startup_mode" = "suspended"
    "pra.failback.site"         = "rbx"
  }
}
```

#### B. Scripts Zerto Post-Failback

Intégration de scripts Zerto qui, après restauration des VMs RBX :
1. Vérifient l'état de démarrage de chaque VM
2. Si la VM est démarrée (active), exécutent immédiatement : `vim-cmd vmsvc/power.suspend <vmid>`
3. Enregistrent dans les logs Zerto l'état de suspension

Script de référence : `zerto/terraform/modules/zerto-vpg-vmware/scripts/post-failback-suspend.sh`

#### C. Workflow Failback Révisé (Procédure Standard)

```
┌─────────────────────────────────────────────────────────────┐
│ PHASE 1 : RESTAURATION (Automatique)                       │
├─────────────────────────────────────────────────────────────┤
│ 1. Déclenchement failback Zerto (SBG → RBX)                │
│ 2. Synchronisation finale des données                       │
│ 3. Démarrage VMs RBX en mode PAUSE (CRON inactifs)         │
│    ✅ État : VMs RBX = SUSPENDED                            │
│    ✅ État : VMs SBG = RUNNING (applications actives)       │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ PHASE 2 : VALIDATION (Manuelle - Checklist obligatoire)    │
├─────────────────────────────────────────────────────────────┤
│ 4. Tests de connectivité réseau RBX (ping, routes)         │
│ 5. Validation montages NFS/Volumes Docker                   │
│ 6. Tests de cohérence base de données (select 1, schemas)  │
│ 7. Vérification logs Zerto (aucune erreur de sync)         │
│    ✅ Validation : OK pour activation RBX                   │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ PHASE 3 : ACTIVATION (Manuelle)                             │
├─────────────────────────────────────────────────────────────┤
│ 8. ✅ Activation manuelle VMs RBX (Resume)                  │
│    Commande : vim-cmd vmsvc/power.on <vmid>                │
│    ou via script : scripts/zerto/resume-vms-rbx.sh         │
│ 9. Attente démarrage complet services (MySQL, Docker)      │
│ 10. Test applicatif sur RBX (healthcheck endpoints)        │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ PHASE 4 : BASCULE PRODUCTION (Manuelle)                     │
├─────────────────────────────────────────────────────────────┤
│ 11. Modification DNS/Load Balancer → RBX                    │
│ 12. Vérification trafic utilisateur sur RBX                 │
│ 13. Arrêt propre VMs SBG                                    │
│ 14. Réactivation réplication Zerto (RBX → SBG)             │
└─────────────────────────────────────────────────────────────┘
```

### Checklist de Validation Failback

Checklist obligatoire avant activation des VMs RBX (fichier : `Documentation/zerto/checklist-failback-mode-pause.md`)

```markdown
☐ 1. Vérifier l'état de réplication Zerto (RPO < 5min)
☐ 2. Confirmer que les VMs RBX sont en état SUSPENDED
☐ 3. Vérifier connectivité réseau RBX (ping gateway, DNS)
☐ 4. Tester accès vRack (ping inter-VM RBX)
☐ 5. Vérifier montages NFS/Volumes (df -h, mount)
☐ 6. Valider intégrité base de données MySQL (select 1)
☐ 7. Vérifier logs Zerto (aucune erreur de synchronisation)
☐ 8. ✅ Validation équipe Ops : OK pour activation
☐ 9. Activer VMs RBX (resume)
☐ 10. Attendre démarrage MySQL + Docker (systemctl status)
☐ 11. Test healthcheck applicatif (curl endpoints)
☐ 12. Basculer DNS/LB vers RBX
☐ 13. Vérifier trafic utilisateur (logs nginx/haproxy)
☐ 14. Arrêter VMs SBG
☐ 15. Réactiver réplication Zerto RBX → SBG
☐ 16. Post-mortem (documenter anomalies)
```

## Alternatives rejetées

### Alternative 1 : Sémaphore Applicatif avec Fichier Lock

**Principe :** Modifier tous les CRON pour vérifier un fichier `/etc/app/pra-status.lock` avant exécution.

**Rejeté car :**
- ❌ Nécessite modification invasive de **tous** les CRON existants et futurs
- ❌ Risque de régression si un CRON n'est pas modifié
- ❌ Maintenance complexe (wrap chaque nouvelle tâche CRON)
- ❌ Dépendance à la synchronisation correcte du fichier lock entre sites
- ❌ Pas de protection si un développeur oublie le wrapper

**Dette technique évitée :** 50+ CRON à modifier, tests de non-régression sur tous les batch métier.

### Alternative 2 : Systemd Timer Override avec Consul

**Principe :** Service systemd au boot qui désactive les timers CRON en consultant Consul pour l'état PRA.

**Rejeté car :**
- ❌ Dépendance critique à un service externe (Consul/etcd)
- ❌ Complexité accrue (cluster Consul multi-sites à maintenir)
- ❌ Single Point of Failure : si Consul est KO, impossible de valider le failback
- ❌ Coût supplémentaire : 3+ VMs Consul pour HA
- ❌ Délai de déploiement : 2-3 semaines vs 3 jours pour Solution 1

**Dette technique évitée :** Infrastructure Consul, playbooks Ansible de gestion, monitoring Consul.

### Alternative 3 : Zerto Pre/Post Scripts uniquement (sans VMware Pause)

**Principe :** Scripts Zerto qui arrêtent les CRON via SSH après démarrage des VMs.

**Rejeté car :**
- ❌ **Fenêtre de risque incompressible** : délai entre boot VM et exécution du script (10-30 secondes)
- ❌ Dépendance SSH : si le réseau n'est pas encore opérationnel, le script échoue
- ❌ Pas de garantie d'exécution (échec script = CRON actifs)
- ❌ Race condition : un CRON peut démarrer avant l'exécution du script

**Justification refus :** La fenêtre de risque de 10-30 secondes est **inacceptable** pour des processus métier critiques (transactions financières, synchronisations bancaires).

### Alternative 4 : Ne rien faire (accepter le risque)

**Principe :** Documenter le risque et former les Ops à surveiller manuellement.

**Rejeté car :**
- ❌ Risque métier inacceptable (corruptions de données avérées)
- ❌ Non-conformité aux exigences d'intégrité des données
- ❌ Responsabilité juridique en cas d'incident
- ❌ Confiance client dégradée

## Conséquences

### ✅ Impacts positifs

1. **Sécurité maximale**
   - Aucun risque de double exécution de CRON
   - Contrôle total sur le timing d'activation des applications
   - Validation explicite avant mise en production

2. **Simplicité technique**
   - Aucune modification applicative (CRON inchangés)
   - Pas de dépendance externe (Consul, locks distribués)
   - Solution native VMware (supportée et documentée)

3. **Conformité et auditabilité**
   - Checklist formalisée et traçable
   - Logs Zerto enregistrant chaque étape
   - Preuve de validation avant activation (conformité SOC2/ISO27001)

4. **Time to Recovery maîtrisé**
   - Déploiement : 3 jours (vs 2-3 semaines pour Alternative 2)
   - Pas de formation complexe pour les Ops
   - Procédure testable en environnement de qualification

5. **Coût optimisé**
   - Aucun surcoût d'infrastructure
   - Pas de licence additionnelle
   - Maintenance minimale

### ⚠️ Impacts négatifs / Dette technique

1. **Intervention manuelle obligatoire**
   - **Problème :** Le failback n'est pas 100% automatique (activation manuelle requise)
   - **Mitigation :** Script `scripts/zerto/resume-vms-rbx.sh` simplifie l'activation (1 commande)
   - **Justification :** La validation manuelle est un **garde-fou voulu**, pas un bug
   - **Évolution future :** Automatisation partielle possible via webhook Zerto (Q2 2025)

2. **RTO légèrement augmenté**
   - **Problème :** Ajout de 10-15 minutes pour la phase de validation
   - **Impact :** RTO passe de 15 min à 25-30 min
   - **Acceptabilité :** Compatible avec SLA cible (RTO < 1h)
   - **Trade-off :** Préférence pour la sécurité vs vitesse

3. **Formation des équipes Ops**
   - **Problème :** Nouvelle procédure à documenter et tester
   - **Mitigation :**
     - Runbook détaillé : `Documentation/zerto/runbook-failback-mode-pause.md`
     - Formation pratique : 1 session (2h) avec simulation
     - Tests trimestriels obligatoires
   - **Ressources :** 1 jour de formation + 2h/trimestre de tests

4. **Monitoring spécifique**
   - **Problème :** Nécessité d'alerter si une VM reste en état SUSPENDED trop longtemps
   - **Solution :** Ajout d'une sonde Zabbix/Prometheus :
     - Alerte si VM RBX = SUSPENDED > 2h (failback oublié)
     - Alerte si VM RBX + VM SBG = RUNNING simultanément (échec du mode pause)
   - **Dette :** Intégration à faire dans le module `zerto/terraform/modules/zerto-monitoring/`

5. **Documentation à maintenir**
   - **Problème :** Checklist et runbooks doivent rester à jour
   - **Solution :**
     - Revue mensuelle de la documentation PRA
     - Versioning dans Git avec changelog
     - Responsable désigné : Lead Ops PRA

### 📊 Métriques de succès

| KPI | Cible | Mesure |
|-----|-------|--------|
| Fenêtre de double exécution CRON | 0 min | Logs CRON (timestamps) |
| RTO (Recovery Time Objective) | < 30 min | Chrono Zerto + logs |
| RPO (Recovery Point Objective) | < 5 min | Dashboard Zerto |
| Taux de réussite failback | 100% | Tests trimestriels |
| Incidents de corruption de données post-failback | 0 | Tickets support |
| Conformité procédure (checklist complétée) | 100% | Audit logs |

## Plan d'implémentation

### Sprint 1 : Sécurisation Immédiate (3 jours)

**Jour 1 :**
- [x] Créer l'ADR (ce document)
- [ ] Modifier modules Terraform `06-ovh-vm-docker` et `07-ovh-vm-mysql`
- [ ] Ajouter variables `enable_failback_pause_mode` et `failback_site`

**Jour 2 :**
- [ ] Créer script `zerto/terraform/modules/zerto-vpg-vmware/scripts/post-failback-suspend.sh`
- [ ] Créer script d'activation `scripts/zerto/resume-vms-rbx.sh`
- [ ] Tester sur VMs de qualification (hors Zerto)

**Jour 3 :**
- [ ] Créer checklist `Documentation/zerto/checklist-failback-mode-pause.md`
- [ ] Créer runbook `Documentation/zerto/runbook-failback-mode-pause.md`
- [ ] Valider avec équipe Ops

### Sprint 2 : Tests et Formation (1 semaine)

**Semaine 1 :**
- [ ] Test failback simulé sur VPG non-critique
- [ ] Mesure du RTO réel vs cible
- [ ] Formation équipe Ops (2h, avec simulation)
- [ ] Ajustements procédure selon retours

### Sprint 3 : Déploiement Production (1 semaine)

**Semaine 2 :**
- [ ] Déploiement sur VPG Production (RBX ↔ SBG)
- [ ] Mise à jour variables Terraform Production
- [ ] Activation monitoring spécifique (alertes VM suspended)
- [ ] Post-mortem et documentation retours d'expérience

## Prochaines étapes

1. **Immédiat (J+0)** : Valider l'ADR avec équipe DevOps/Ops ✅
2. **Court terme (J+3)** : Implémenter les modifications Terraform et scripts
3. **Moyen terme (J+10)** : Tests en conditions réelles et formation
4. **Long terme (Q2 2025)** : Automatisation partielle via webhooks Zerto (optionnel)

## Références

- [Documentation Zerto - Failback Best Practices](https://www.zerto.com/myzerto/knowledge-base/failback-best-practices/)
- [VMware vSphere API - VM Power States](https://developer.vmware.com/apis/vsphere-automation/latest/vcenter/vm.Power/)
- [OVH Private Cloud - Zerto Integration Guide](https://docs.ovh.com/fr/private-cloud/zerto-virtual-replication-vmware-vsphere-drp/)
- [Documentation interne - Stratégie Failback Zerto](./../../Documentation/zerto/strategie-failback-zerto.md)
- [ISO 27001:2022 - Business Continuity Controls](https://www.iso.org/standard/27001)

## Historique des modifications

| Date | Version | Auteur | Modifications |
|------|---------|--------|---------------|
| 2025-12-30 | 1.0 | Équipe DevOps | Création initiale de l'ADR - Décision Mode Pause VMware |

---

**Statut actuel :** ✅ **ACCEPTÉ** - Implémentation en cours (Sprint 1)
