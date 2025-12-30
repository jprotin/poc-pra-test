# Checklist de Validation Failback - Mode Pause VMware

**Version :** 1.0
**Date :** 2025-12-30
**Stratégie :** Mode Pause VMware Automatique
**ADR Associé :** [ADR-2025-12-30](../adr/2025-12-30-strategie-failback-mode-pause-vmware.md)

---

## 📋 Objectif

Cette checklist **OBLIGATOIRE** doit être complétée avant d'activer les VMs RBX après un failback Zerto. Elle garantit que toutes les validations critiques ont été effectuées pour éviter les corruptions de données et assurer un retour à la normale sécurisé.

---

## ⚠️ Instructions Importantes

- ✅ **Compléter TOUTES les étapes** dans l'ordre
- ✅ **Documenter les résultats** de chaque test
- ✅ **Ne PAS activer les VMs** tant que toutes les étapes ne sont pas validées
- ✅ **Conserver cette checklist** pour l'audit post-failback

**Responsable de la validation :** \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
**Date et heure du failback :** \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
**VPG concerné :** \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

---

## Phase 1 : Vérifications Préalables

### ☐ 1. Vérifier l'état de réplication Zerto

**Objectif :** S'assurer que la synchronisation Zerto est terminée et que le RPO est respecté.

**Actions :**
```bash
# Accéder au dashboard Zerto
# Vérifier le VPG : VPG-RBX-TO-SBG (ou VPG-SBG-TO-RBX)
```

**Critères de validation :**
- [ ] RPO actuel < 5 minutes
- [ ] Statut du VPG : "Meeting SLA" (vert)
- [ ] Aucune alerte active sur le VPG
- [ ] Journal Zerto : Aucune erreur de réplication

**Résultat :**
- RPO constaté : \_\_\_\_\_\_ secondes
- Heure de dernier checkpoint : \_\_\_\_\_\_\_\_\_\_\_\_\_\_
- Commentaires : \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

---

### ☐ 2. Confirmer l'état des VMs RBX (SUSPENDED)

**Objectif :** Vérifier que les VMs ont bien démarré en mode suspendu.

**Actions :**
```bash
# Via vSphere Client ou govc
govc vm.info -json VM-DOCKER-APP-A-RBX | jq '.VirtualMachines[0].Runtime.PowerState'
govc vm.info -json VM-MYSQL-APP-A-RBX | jq '.VirtualMachines[0].Runtime.PowerState'
```

**Critères de validation :**
- [ ] VM-DOCKER-APP-A-RBX : PowerState = "suspended"
- [ ] VM-MYSQL-APP-A-RBX : PowerState = "suspended"
- [ ] Aucune VM en état "poweredOn" (les CRON ne doivent PAS tourner)

**Résultat :**
- État VM Docker : \_\_\_\_\_\_\_\_\_\_\_\_\_\_
- État VM MySQL : \_\_\_\_\_\_\_\_\_\_\_\_\_\_
- Commentaires : \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

---

### ☐ 3. Vérifier connectivité réseau RBX (depuis jumpbox/bastion)

**Objectif :** S'assurer que le réseau vRack et les routes sont opérationnels.

**Actions :**
```bash
# Depuis un jumpbox/bastion ayant accès au vRack RBX
ping -c 4 10.100.0.1   # Gateway FortiGate RBX
ping -c 4 10.100.0.10  # IP prévue VM Docker RBX (peut échouer si VM suspended)
ping -c 4 10.100.0.11  # IP prévue VM MySQL RBX (peut échouer si VM suspended)

# Tester résolution DNS
nslookup vm-docker-rbx.prod.local
```

**Critères de validation :**
- [ ] Ping vers gateway RBX (10.100.0.1) : Réussi
- [ ] Route vers VLAN 100 (RBX) : Accessible
- [ ] DNS : Résolution correcte (si applicable)

**Résultat :**
- Ping gateway : \_\_\_\_\_\_ ms
- Connectivité vRack : ✅ OK / ❌ KO
- Commentaires : \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

---

### ☐ 4. Tester accès vRack inter-VM (si applicable)

**Objectif :** Vérifier que les VMs RBX pourront communiquer entre elles une fois activées.

**Actions :**
```bash
# Depuis le jumpbox, tester la connectivité réseau prévue
ping -c 4 10.100.0.10  # VM Docker RBX
ping -c 4 10.100.0.11  # VM MySQL RBX

# Vérifier les règles FortiGate
# Policy 100: allow 10.100.0.10 → 10.100.0.11 tcp/3306
```

**Critères de validation :**
- [ ] Réseau VLAN 100 opérationnel
- [ ] Règles firewall FortiGate actives
- [ ] Aucun blocage réseau détecté

**Résultat :**
- Règles firewall : ✅ Vérifiées / ❌ À corriger
- Commentaires : \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

---

### ☐ 5. Vérifier montages NFS/Volumes (après activation VM temporaire)

**Objectif :** S'assurer que les volumes de stockage sont accessibles.

**Note :** Cette étape peut nécessiter d'activer temporairement UNE VM de test (non Docker/MySQL) pour vérifier les montages.

**Actions :**
```bash
# Après activation temporaire d'une VM de test RBX
ssh vmadmin@<vm-test-rbx>
df -h
mount | grep nfs
ls -la /var/lib/docker  # Pour VM Docker
ls -la /var/lib/mysql   # Pour VM MySQL
```

**Critères de validation :**
- [ ] Montages NFS présents (si utilisés)
- [ ] Volumes Docker accessibles
- [ ] Espace disque suffisant (> 20% libre)

**Résultat :**
- Montages : ✅ OK / ❌ KO
- Espace disque : \_\_\_\_\_\_ % libre
- Commentaires : \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

---

## Phase 2 : Validation Base de Données

### ☐ 6. Valider intégrité base de données MySQL (après activation VM MySQL)

**Objectif :** S'assurer que la base de données est cohérente et accessible.

**Note :** Activer UNIQUEMENT la VM MySQL pour ces tests.

**Actions :**
```bash
# Activer temporairement la VM MySQL
./scripts/zerto/resume-vms-rbx.sh --site rbx --force

# Attendre démarrage MySQL (vérifier logs)
ssh vmadmin@vm-mysql-rbx "sudo systemctl status mysql"

# Tester connexion et intégrité
ssh vmadmin@vm-mysql-rbx "sudo mysql -e 'SELECT 1;'"
ssh vmadmin@vm-mysql-rbx "sudo mysqlcheck --all-databases"
```

**Critères de validation :**
- [ ] MySQL démarré avec succès
- [ ] Connexion MySQL fonctionnelle
- [ ] Aucune corruption de table détectée
- [ ] Schémas applicatifs présents

**Résultat :**
- MySQL status : ✅ OK / ❌ KO
- Intégrité tables : ✅ OK / ❌ KO
- Commentaires : \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

---

### ☐ 7. Vérifier logs Zerto (aucune erreur de synchronisation)

**Objectif :** S'assurer qu'aucune erreur n'est survenue lors de la réplication.

**Actions :**
```bash
# Accéder aux logs Zerto via l'interface web
# Filtrer par VPG et date du failback

# Vérifier les logs sur les VMs
ssh vmadmin@vm-mysql-rbx "sudo tail -100 /var/log/zerto/*.log"
```

**Critères de validation :**
- [ ] Aucune erreur critique dans les logs Zerto
- [ ] Synchronisation complétée à 100%
- [ ] Aucun warning de corruption de données

**Résultat :**
- Logs Zerto : ✅ Clean / ⚠️ Warnings / ❌ Errors
- Commentaires : \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

---

## Phase 3 : Validation Finale (Prêt pour Activation)

### ☐ 8. ✅ Validation équipe Ops : OK pour activation complète

**Objectif :** Confirmation formelle que toutes les vérifications sont OK.

**Critères de validation :**
- [ ] TOUTES les étapes 1 à 7 sont validées
- [ ] Aucun bloquant identifié
- [ ] Équipe Ops disponible pour superviser l'activation

**Responsable validation :** \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
**Date et heure validation :** \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
**Signature/Approbation :** \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

---

## Phase 4 : Activation des VMs RBX

### ☐ 9. Activer les VMs RBX (resume)

**Objectif :** Démarrer toutes les VMs RBX en production.

**Actions :**
```bash
# Activer toutes les VMs du site RBX
./scripts/zerto/resume-vms-rbx.sh --site rbx --vpg-name VPG-RBX-TO-SBG

# Suivre les logs d'activation
tail -f /var/log/zerto/resume-vms.log
```

**Critères de validation :**
- [ ] Toutes les VMs activées avec succès
- [ ] Aucune erreur lors de l'activation

**Résultat :**
- VMs activées : \_\_\_\_\_\_ / \_\_\_\_\_\_
- Heure activation : \_\_\_\_\_\_\_\_\_\_\_\_\_\_
- Commentaires : \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

---

### ☐ 10. Attendre démarrage complet des services (MySQL, Docker)

**Objectif :** S'assurer que tous les services applicatifs sont opérationnels.

**Actions :**
```bash
# Vérifier MySQL
ssh vmadmin@vm-mysql-rbx "sudo systemctl status mysql"

# Vérifier Docker
ssh vmadmin@vm-docker-rbx "sudo systemctl status docker"
ssh vmadmin@vm-docker-rbx "sudo docker ps"
```

**Critères de validation :**
- [ ] MySQL : Active (running)
- [ ] Docker : Active (running)
- [ ] Conteneurs Docker : Démarrés

**Résultat :**
- Temps de démarrage MySQL : \_\_\_\_\_\_ secondes
- Temps de démarrage Docker : \_\_\_\_\_\_ secondes
- Commentaires : \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

---

### ☐ 11. Test healthcheck applicatif (curl endpoints)

**Objectif :** Valider que les applications répondent correctement.

**Actions :**
```bash
# Tester les endpoints de healthcheck
curl -I http://10.100.0.10/health
curl -I http://10.100.0.10:80

# Tester connexion MySQL depuis VM Docker
ssh vmadmin@vm-docker-rbx "mysql -h 10.100.0.11 -u appuser -p -e 'SELECT 1;'"
```

**Critères de validation :**
- [ ] Healthcheck HTTP : 200 OK
- [ ] Connexion MySQL depuis Docker : OK
- [ ] Aucune erreur applicative

**Résultat :**
- Healthcheck : ✅ OK / ❌ KO
- Latence : \_\_\_\_\_\_ ms
- Commentaires : \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

---

## Phase 5 : Bascule Production

### ☐ 12. Basculer DNS/Load Balancer vers RBX

**Objectif :** Rediriger le trafic utilisateur vers le site RBX.

**Actions :**
```bash
# Modifier les enregistrements DNS
# Exemple : app.example.com A 51.xxx.xxx.xxx (IP publique RBX)

# Ou modifier la configuration du Load Balancer
# Backend : RBX (primary), SBG (disabled)
```

**Critères de validation :**
- [ ] DNS propagé (vérifier avec `dig`)
- [ ] Trafic redirigé vers RBX
- [ ] TTL DNS expiré

**Résultat :**
- Heure bascule DNS : \_\_\_\_\_\_\_\_\_\_\_\_\_\_
- TTL : \_\_\_\_\_\_ secondes
- Commentaires : \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

---

### ☐ 13. Vérifier trafic utilisateur sur RBX (logs nginx/haproxy)

**Objectif :** Confirmer que les utilisateurs accèdent bien au site RBX.

**Actions :**
```bash
# Vérifier les logs d'accès
ssh vmadmin@vm-docker-rbx "sudo tail -f /var/log/nginx/access.log"

# Vérifier les métriques
# Dashboard Prometheus/Grafana : Trafic entrant RBX
```

**Critères de validation :**
- [ ] Trafic entrant visible sur RBX
- [ ] Aucun trafic résiduel sur SBG
- [ ] Latence acceptable

**Résultat :**
- Requêtes/s : \_\_\_\_\_\_
- Latence moyenne : \_\_\_\_\_\_ ms
- Commentaires : \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

---

### ☐ 14. Arrêter les VMs SBG

**Objectif :** Désactiver le site de secours maintenant que RBX est actif.

**Actions :**
```bash
# Arrêter proprement les VMs SBG via vSphere
govc vm.power -off VM-DOCKER-APP-B-SBG
govc vm.power -off VM-MYSQL-APP-B-SBG
```

**Critères de validation :**
- [ ] VMs SBG arrêtées
- [ ] Aucun CRON actif sur SBG

**Résultat :**
- Heure arrêt SBG : \_\_\_\_\_\_\_\_\_\_\_\_\_\_
- Commentaires : \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

---

### ☐ 15. Réactiver réplication Zerto (RBX → SBG)

**Objectif :** Remettre en place la protection PRA dans le sens normal.

**Actions :**
```bash
# Via l'interface Zerto
# Activer le VPG : VPG-RBX-TO-SBG
# Vérifier que la réplication démarre
```

**Critères de validation :**
- [ ] VPG activé
- [ ] Réplication en cours
- [ ] RPO initial < 5 minutes

**Résultat :**
- Heure activation VPG : \_\_\_\_\_\_\_\_\_\_\_\_\_\_
- RPO initial : \_\_\_\_\_\_ secondes
- Commentaires : \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

---

## Phase 6 : Post-Mortem et Documentation

### ☐ 16. Post-mortem (documenter les anomalies)

**Objectif :** Documenter les incidents, améliorations et leçons apprises.

**Questions :**
- Des erreurs sont-elles survenues ? Lesquelles ?
- Le RTO cible (< 30 min) a-t-il été respecté ?
- Des améliorations sont-elles nécessaires pour le prochain failback ?

**Résultat :**
- Durée totale du failback : \_\_\_\_\_\_ minutes
- RTO respecté : ✅ Oui / ❌ Non
- Incidents rencontrés : \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
- Actions correctives : \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

---

## Résumé de la Validation

| Étape | Statut | Commentaire |
|-------|--------|-------------|
| 1. Réplication Zerto | ☐ OK ☐ KO | |
| 2. État VMs SUSPENDED | ☐ OK ☐ KO | |
| 3. Connectivité réseau | ☐ OK ☐ KO | |
| 4. Accès vRack | ☐ OK ☐ KO | |
| 5. Montages NFS/Volumes | ☐ OK ☐ KO | |
| 6. Intégrité MySQL | ☐ OK ☐ KO | |
| 7. Logs Zerto | ☐ OK ☐ KO | |
| 8. Validation Ops | ☐ OK ☐ KO | |
| 9. Activation VMs | ☐ OK ☐ KO | |
| 10. Démarrage services | ☐ OK ☐ KO | |
| 11. Healthcheck applicatif | ☐ OK ☐ KO | |
| 12. Bascule DNS | ☐ OK ☐ KO | |
| 13. Trafic utilisateur | ☐ OK ☐ KO | |
| 14. Arrêt VMs SBG | ☐ OK ☐ KO | |
| 15. Réactivation VPG | ☐ OK ☐ KO | |
| 16. Post-mortem | ☐ OK ☐ KO | |

**Validation finale :** ☐ Failback réussi ☐ Failback en échec

**Responsable :** \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
**Date et heure de fin :** \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
**Signature :** \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

---

## 📚 Références

- **ADR Stratégie Failback :** `../adr/2025-12-30-strategie-failback-mode-pause-vmware.md`
- **Runbook détaillé :** `./runbook-failback-mode-pause.md`
- **Script d'activation :** `../../scripts/zerto/resume-vms-rbx.sh`
- **Documentation Zerto :** `./strategie-failback-zerto.md`
