# RUNBOOK - Perte Totale d'un Site (Active/Active)

## 🎯 Objectif

Ce runbook décrit la procédure complète de gestion d'un incident de **perte totale d'un site** (RBX ou SBG) dans une architecture Zerto Active/Active.

---

## 📋 Informations Générales

| Attribut | Valeur |
|----------|--------|
| **Runbook ID** | RB-ZERTO-001 |
| **Version** | 1.0 |
| **Date création** | 2025-12-17 |
| **Dernière révision** | 2025-12-17 |
| **Propriétaire** | Équipe Infrastructure |
| **Classification** | CONFIDENTIEL |
| **Temps estimé** | 2-4 heures (phase initiale) |

---

## 🚨 Détection de l'Incident

### Signaux d'Alerte

L'incident peut être détecté par plusieurs sources :

- ✉️ **Email** : Alerte Zerto "VPG NotMeetingSLA"
- 📊 **Dashboard Grafana** : Statut VPG rouge
- 📱 **Slack/Teams** : Webhook automatique
- 🔔 **PagerDuty/Opsgenie** : Incident créé automatiquement
- 👤 **Utilisateurs** : Reports d'indisponibilité

### Vérification Initiale

```bash
# 1. Vérifier les VPGs
./zerto/scripts/check-vpg-status.sh --all --verbose

# 2. Vérifier connectivité sites
ping -c 5 10.1.0.1  # RBX Fortigate
ping -c 5 10.2.0.1  # SBG Fortigate

# 3. Vérifier tunnels Azure
ssh admin@10.1.0.1 "get vpn ipsec tunnel summary"
ssh admin@10.2.0.1 "get vpn ipsec tunnel summary"
```

---

## 🔍 Phase 1: Diagnostic (0-15 minutes)

### 1.1 Identifier le Site KO

**Objectif** : Déterminer quel site est hors service (RBX ou SBG).

```bash
#!/bin/bash
# Script de diagnostic rapide

echo "=== DIAGNOSTIC RAPIDE ==="

# Test RBX
if ping -c 3 -W 2 10.1.0.1 &>/dev/null; then
    echo "✅ RBX: ONLINE"
    RBX_STATUS="UP"
else
    echo "❌ RBX: OFFLINE"
    RBX_STATUS="DOWN"
fi

# Test SBG
if ping -c 3 -W 2 10.2.0.1 &>/dev/null; then
    echo "✅ SBG: ONLINE"
    SBG_STATUS="UP"
else
    echo "❌ SBG: OFFLINE"
    SBG_STATUS="DOWN"
fi

# Déterminer le scénario
if [[ "$RBX_STATUS" == "DOWN" && "$SBG_STATUS" == "UP" ]]; then
    echo ""
    echo "📌 SCÉNARIO: PERTE SITE RBX"
    echo "   - Application A (prod sur RBX): À FAILOVER vers SBG"
    echo "   - Application B (prod sur SBG): FONCTIONNE mais NON PROTÉGÉE"
    SCENARIO="RBX-DOWN"

elif [[ "$SBG_STATUS" == "DOWN" && "$RBX_STATUS" == "UP" ]]; then
    echo ""
    echo "📌 SCÉNARIO: PERTE SITE SBG"
    echo "   - Application B (prod sur SBG): À FAILOVER vers RBX"
    echo "   - Application A (prod sur RBX): FONCTIONNE mais NON PROTÉGÉE"
    SCENARIO="SBG-DOWN"

elif [[ "$RBX_STATUS" == "DOWN" && "$SBG_STATUS" == "DOWN" ]]; then
    echo ""
    echo "🔴 CATASTROPHE: LES DEUX SITES SONT DOWN"
    echo "   ESCALADE IMMÉDIATE NIVEAU 3"
    SCENARIO="BOTH-DOWN"
    exit 2

else
    echo ""
    echo "✅ Tous les sites sont opérationnels"
    echo "   Vérifier la configuration réseau ou les VPGs"
    exit 0
fi

# Sauvegarder l'état pour les phases suivantes
echo "$SCENARIO" > /tmp/zerto-incident-scenario.txt
```

### 1.2 Vérifier l'État des VPGs

```bash
# Récupérer le statut détaillé de tous les VPGs
./zerto/scripts/check-vpg-status.sh --all > /tmp/vpg-status-$(date +%Y%m%d-%H%M%S).txt

# Afficher les VPGs en erreur uniquement
./zerto/scripts/check-vpg-status.sh --all | grep -A 10 "UNHEALTHY"
```

### 1.3 Ouvrir un Ticket d'Incident

```bash
# Créer automatiquement un ticket (adapter selon votre système)
./scripts/create-incident-ticket.sh \
    --title "Perte totale site $(cat /tmp/zerto-incident-scenario.txt | cut -d'-' -f1)" \
    --severity "P1-CRITICAL" \
    --description "Incident Zerto - Site KO détecté" \
    --assignee "ops-team"
```

**Template de ticket :**

```
TITRE: [P1] Perte Totale Site RBX - Architecture Zerto Active/Active

DESCRIPTION:
- Incident détecté: <TIMESTAMP>
- Site KO: RBX
- Site survivant: SBG
- VPGs affectés: VPG-RBX-to-SBG (NotMeetingSLA), VPG-SBG-to-RBX (NotMeetingSLA)
- Applications impactées:
  * Application A: Nécessite failover vers SBG
  * Application B: Fonctionne mais non protégée

ACTIONS IMMÉDIATES:
- [ ] Failover Application A vers SBG
- [ ] Activation backup d'urgence Application B
- [ ] Notification parties prenantes
- [ ] Surveillance continue site RBX

CONTACTS:
- Ops Lead: +33 X XX XX XX XX
- Infrastructure Manager: +33 X XX XX XX XX
- Support OVHcloud: https://www.ovh.com/manager/
```

---

## ⚡ Phase 2: Actions Immédiates (15-60 minutes)

### 2.1 Scénario A: RBX DOWN

#### 2.1.1 Failover Application A (RBX → SBG)

**Objectif** : Basculer l'Application A (production sur RBX) vers SBG.

```bash
#!/bin/bash
set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "FAILOVER APPLICATION A : RBX → SBG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Étape 1: Vérifier l'état du VPG
echo "1️⃣  Vérification VPG-RBX-to-SBG..."
./zerto/scripts/check-vpg-status.sh --vpg VPG-RBX-to-SBG

# Étape 2: Lancer le failover
echo ""
echo "2️⃣  Démarrage du failover vers SBG..."
./zerto/scripts/failover-rbx-to-sbg.sh \
    --force \
    --vpg VPG-RBX-to-SBG \
    --checkpoint latest \
    --commit-policy auto \
    --rollback-on-failure

FAILOVER_EXIT_CODE=$?

if [[ $FAILOVER_EXIT_CODE -eq 0 ]]; then
    echo "✅ Failover réussi"
else
    echo "❌ Échec du failover (code: $FAILOVER_EXIT_CODE)"
    echo "⚠️  Vérifier les logs: /var/log/zerto/failover-rbx-to-sbg.log"
    exit 1
fi

# Étape 3: Valider les VMs sur SBG
echo ""
echo "3️⃣  Validation des VMs sur SBG..."
for vm in "rbx-app-prod-01" "rbx-db-prod-01"; do
    if ssh root@sbg-vcenter.local "vim-cmd vmsvc/power.getstate $vm" | grep -q "Powered on"; then
        echo "  ✅ $vm: Powered On"
    else
        echo "  ❌ $vm: NOT Powered On"
        exit 1
    fi
done

# Étape 4: Tester la connectivité
echo ""
echo "4️⃣  Test de connectivité..."
ping -c 3 10.1.1.10  # IP Application A failovée sur SBG
curl -s -o /dev/null -w "%{http_code}" http://10.1.1.10/health

# Étape 5: Mise à jour routes Fortigate SBG
echo ""
echo "5️⃣  Configuration routes Fortigate SBG..."
ssh admin@10.2.0.1 <<'EOF'
config router static
    edit 0
        set dst 10.1.1.10/32
        set device "internal"
        set comment "VM rbx-app-prod-01 failovée"
    next
    edit 0
        set dst 10.1.1.20/32
        set device "internal"
        set comment "VM rbx-db-prod-01 failovée"
    next
end
EOF

echo ""
echo "✅ Failover Application A terminé avec succès"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

**Temps estimé** : 15-30 minutes

**RTO réel attendu** : < 30 minutes

#### 2.1.2 Activation Backup d'Urgence Application B

**Objectif** : Protéger l'Application B (qui tourne sur SBG survivant) avec des backups.

```bash
#!/bin/bash
set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ACTIVATION BACKUP D'URGENCE - APPLICATION B"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Définir les VMs à protéger
export VMS_TO_PROTECT='["sbg-app-prod-01", "sbg-db-prod-01"]'

# Lancer le playbook Ansible
echo "🚀 Démarrage du playbook Ansible..."
ansible-playbook zerto/ansible/playbooks/activate-emergency-backup.yml \
    -e "app_name=Application-B" \
    -e "site=SBG" \
    -e "vms_to_protect=$VMS_TO_PROTECT" \
    --vault-password-file ~/.ansible/vault_pass.txt \
    --tags "phase1,phase2,phase3,phase4" \
    -v

if [[ $? -eq 0 ]]; then
    echo ""
    echo "✅ Backup d'urgence activé avec succès"
    echo "📊 Planification:"
    echo "   - Backup Local: 02:00 et 14:00 (tous les jours)"
    echo "   - Backup S3: 04:00 et 16:00 (tous les jours)"
    echo "   - Rétention Local: 7 jours"
    echo "   - Rétention S3: 30 jours (immuable)"
else
    echo ""
    echo "❌ Échec activation backup d'urgence"
    echo "⚠️  ACTION MANUELLE REQUISE"
    echo "   Vérifier les logs Ansible et activer manuellement via Veeam Console"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

**Temps estimé** : 30-60 minutes (incluant le premier backup complet)

#### 2.1.3 Notification Parties Prenantes

```bash
#!/bin/bash

# Template notification
cat > /tmp/incident-notification.txt <<EOF
🚨 INCIDENT MAJEUR - Perte Site RBX

Cher(e) Collègue,

Un incident critique affecte notre infrastructure Zerto.

📋 RÉSUMÉ:
• Site RBX: HORS SERVICE (depuis $(date))
• Site SBG: OPÉRATIONNEL

✅ ACTIONS RÉALISÉES:
• Application A: Basculée sur SBG avec succès (RTO: 25 min)
• Application B: Protégée par backup d'urgence (RPO: 12h max)
• Monitoring renforcé activé

⚠️ IMPACT:
• Application A: Disponible (perte < 5 minutes de données)
• Application B: Disponible mais non répliquée en temps réel
• Risque résiduel: Double panne (SBG après RBX)

📊 PROCHAINES ÉTAPES:
• Diagnostic cause racine perte RBX (Support OVH contacté)
• Surveillance continue Application B
• Backups quotidiens automatiques (local + S3)
• Planification retour à la normale

🔗 LIENS:
• Dashboard: http://monitoring.local:3000/d/zerto-emergency
• Ticket: INC-$(date +%Y%m%d)-001

Équipe Infrastructure
$(date '+%Y-%m-%d %H:%M:%S')
EOF

# Envoyer via email
cat /tmp/incident-notification.txt | mail -s "[P1] Incident Zerto - Perte Site RBX" \
    ops-team@example.com,management@example.com

# Envoyer via Slack/Teams
curl -X POST "$ALERT_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{\"text\": \"$(cat /tmp/incident-notification.txt | sed 's/"/\\"/g')\"}"
```

### 2.2 Scénario B: SBG DOWN

**Note** : Procédure similaire mais inversée.

```bash
# Failover Application B (SBG → RBX)
./zerto/scripts/failover-sbg-to-rbx.sh --force --vpg VPG-SBG-to-RBX

# Activation backup d'urgence Application A
ansible-playbook zerto/ansible/playbooks/activate-emergency-backup.yml \
    -e "app_name=Application-A" \
    -e "site=RBX" \
    -e "vms_to_protect=[\"rbx-app-prod-01\", \"rbx-db-prod-01\"]"
```

---

## 🔁 Phase 3: Surveillance Continue (H+1 à Résolution)

### 3.1 Checklist Quotidienne

**À exécuter chaque jour tant que le site est KO :**

```bash
#!/bin/bash
# Daily check during incident

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SURVEILLANCE QUOTIDIENNE - Jour $(cat /tmp/incident-day-count.txt || echo 1)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Vérifier statut site KO
echo "1️⃣  Tentative de reconnexion au site KO..."
SITE_KO=$(cat /tmp/zerto-incident-scenario.txt | cut -d'-' -f1)

if [[ "$SITE_KO" == "RBX" ]]; then
    if ping -c 5 10.1.0.1 &>/dev/null; then
        echo "🎉 SITE RBX EST REVENU EN LIGNE !"
        echo "   → Passer à la Phase 4: Retour à la Normale"
        exit 100  # Code spécial pour déclencher Phase 4
    else
        echo "❌ Site RBX toujours inaccessible"
    fi
fi

# 2. Vérifier les backups d'urgence
echo ""
echo "2️⃣  Vérification des backups d'urgence..."
veeam-cli job info "Emergency-Backup-Application-B-Local" | grep -E "Last Result|Last Run"
veeam-cli job info "Emergency-Backup-Application-B-S3" | grep -E "Last Result|Last Run"

# 3. Vérifier espace disque site survivant
echo ""
echo "3️⃣  Vérification espace disque..."
if [[ "$SITE_KO" == "RBX" ]]; then
    ssh root@sbg-vcenter.local "df -h /vmfs/volumes/datastore*" | grep -E "datastore|Use%"
else
    ssh root@rbx-vcenter.local "df -h /vmfs/volumes/datastore*" | grep -E "datastore|Use%"
fi

# 4. Vérifier journal Zerto (bitmap size)
echo ""
echo "4️⃣  Taille du bitmap Zerto..."
./zerto/scripts/check-bitmap-size.sh --vpg VPG-SBG-to-RBX

# 5. Estimer temps resynchronisation
echo ""
echo "5️⃣  Estimation temps resynchronisation (quand site reviendra)..."
BITMAP_SIZE_GB=$(./zerto/scripts/check-bitmap-size.sh --vpg VPG-SBG-to-RBX --output-only)
BANDWIDTH_GBPS=1
COMPRESSION_RATIO=2

SYNC_TIME_HOURS=$(echo "scale=2; $BITMAP_SIZE_GB / ($BANDWIDTH_GBPS * 100 * $COMPRESSION_RATIO)" | bc)

echo "   Bitmap accumulé: ${BITMAP_SIZE_GB} GB"
echo "   Temps sync estimé: ${SYNC_TIME_HOURS}h (avec bande passante 1 Gbps)"

# 6. Incrémenter compteur jour
CURRENT_DAY=$(cat /tmp/incident-day-count.txt || echo 0)
NEW_DAY=$((CURRENT_DAY + 1))
echo $NEW_DAY > /tmp/incident-day-count.txt

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Jour $NEW_DAY de l'incident - Surveillance continue..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

**Automatiser avec cron :**

```bash
# Ajouter au crontab
crontab -e

# Exécuter tous les jours à 09:00
0 9 * * * /path/to/zerto/scripts/daily-incident-check.sh >> /var/log/zerto/daily-check.log 2>&1
```

### 3.2 Rapport Hebdomadaire

**Template de rapport à envoyer chaque semaine :**

```markdown
# RAPPORT HEBDOMADAIRE - Incident Zerto RBX

**Semaine** : Du XX/XX/2025 au XX/XX/2025
**Jour incident** : 7 jours

## 📊 État des Lieux

| Indicateur | Valeur |
|------------|--------|
| Site RBX | ❌ HORS SERVICE (7 jours) |
| Site SBG | ✅ OPÉRATIONNEL |
| Application A | ✅ Disponible sur SBG (failovée) |
| Application B | ✅ Disponible, protégée par backup |

## 💾 Backups d'Urgence (Application B)

| Backup | Dernière Exécution | Statut | Taille |
|--------|-------------------|--------|--------|
| Local SBG | 17/12/2025 14:00 | ✅ Success | 450 GB |
| S3 GRA | 17/12/2025 16:00 | ✅ Success | 225 GB (compressé) |

**RPO actuel** : 12 heures (dernier backup)

## 📈 Bitmap Accumulé

- **Taille actuelle** : 1,2 TB
- **Évolution** : +170 GB cette semaine
- **Estimation resync** : 14 heures (au retour RBX)

## 🔍 Actions OVHcloud

- Ticket #123456 ouvert le XX/XX/2025
- Statut : Investigation en cours
- Cause identifiée : [À compléter]
- ETA rétablissement : [À compléter]

## ⚠️ Risques Identifiés

1. **Double panne** : Si SBG tombe pendant que RBX est KO → Perte App B
2. **Espace disque SBG** : 68% utilisé (seuil warning à 70%)
3. **Resynchronisation longue** : 14h estimées au retour de RBX

## 📋 Actions Planifiées

- [ ] Contacter OVH pour ETA précis (Lundi)
- [ ] Augmenter datastore SBG si > 70% (Mercredi)
- [ ] Tester restauration depuis S3 (Vendredi)
- [ ] Prévoir fenêtre de maintenance pour resynchronisation

---
**Prochain rapport** : XX/XX/2025
**Contact** : ops-team@example.com
```

---

## ✅ Phase 4: Retour à la Normale

### 4.1 Détection Retour Site

**Automatique via cron ou manuel :**

```bash
# Vérifier si le site est revenu
SITE_KO=$(cat /tmp/zerto-incident-scenario.txt | cut -d'-' -f1)

if [[ "$SITE_KO" == "RBX" ]]; then
    if ping -c 10 -i 1 10.1.0.1; then
        echo "🎉 Site RBX est revenu en ligne !"

        # Attendre stabilisation (15 minutes)
        echo "⏳ Attente stabilisation (15 minutes)..."
        sleep 900

        # Valider que c'est stable
        if ping -c 20 -i 2 10.1.0.1; then
            echo "✅ Site RBX stable"
            # Déclencher retour à la normale
            ./zerto/scripts/restore-normal-operations.sh
        fi
    fi
fi
```

### 4.2 Resynchronisation Zerto

**Processus automatique - Surveillance seulement :**

```bash
#!/bin/bash
# Script: restore-normal-operations.sh

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "RETOUR À LA NORMALE - Site RBX rétabli"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Vérifier l'état des VPGs
echo "1️⃣  Vérification VPGs..."
./zerto/scripts/check-vpg-status.sh --all

# 2. Surveiller la resynchronisation
echo ""
echo "2️⃣  Surveillance resynchronisation VPG-SBG-to-RBX..."

while true; do
    VPG_STATUS=$(./zerto/scripts/check-vpg-status.sh --vpg VPG-SBG-to-RBX --json | jq -r '.Status')

    if [[ "$VPG_STATUS" == "Syncing" ]]; then
        # Afficher progression
        SYNC_PROGRESS=$(./zerto/scripts/check-sync-progress.sh --vpg VPG-SBG-to-RBX)
        echo "   ⏳ Resynchronisation en cours: $SYNC_PROGRESS%"
        sleep 60

    elif [[ "$VPG_STATUS" == "MeetingSLA" ]]; then
        echo "   ✅ Resynchronisation terminée ! VPG en état MeetingSLA"
        break

    else
        echo "   ⚠️  État inattendu: $VPG_STATUS"
        sleep 60
    fi
done

# 3. Valider le RPO
echo ""
echo "3️⃣  Validation du RPO..."
ACTUAL_RPO=$(./zerto/scripts/check-vpg-status.sh --vpg VPG-SBG-to-RBX --json | jq -r '.ActualRPO')

if [[ $ACTUAL_RPO -lt 300 ]]; then
    echo "   ✅ RPO validé: ${ACTUAL_RPO}s (< 5 minutes)"
else
    echo "   ⚠️  RPO élevé: ${ACTUAL_RPO}s (attendre quelques minutes)"
fi

# 4. Décision sur les backups d'urgence
echo ""
echo "4️⃣  Gestion des backups d'urgence..."
echo "   OPTIONS:"
echo "   A) Conserver les backups (Recommandé - double protection)"
echo "   B) Désactiver les backups (économie coûts)"

read -p "   Choix (A/B): " CHOICE

if [[ "$CHOICE" == "B" ]]; then
    echo "   ⚙️  Désactivation des backups d'urgence..."
    ansible-playbook zerto/ansible/playbooks/deactivate-emergency-backup.yml \
        -e "app_name=Application-B" \
        -e "confirm=yes"
else
    echo "   ✅ Backups d'urgence conservés (double protection active)"
fi

# 5. Notification équipe
echo ""
echo "5️⃣  Envoi notification retour à la normale..."
curl -X POST "$ALERT_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d '{
        "text": "✅ **RETOUR À LA NORMALE**\n\nSite RBX rétabli.\nVPG-SBG-to-RBX: MeetingSLA\nRPO: '"$ACTUAL_RPO"'s\n\nIncident clos.",
        "priority": "info"
    }'

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ RETOUR À LA NORMALE TERMINÉ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

### 4.3 Post-Mortem

**Dans les 48h suivant la résolution :**

```markdown
# POST-MORTEM - Incident Perte Site RBX

## Informations Générales

- **Incident ID** : INC-2025-001
- **Date début** : 10/12/2025 14:35 UTC
- **Date fin** : 17/12/2025 09:20 UTC
- **Durée totale** : 7 jours, 19 heures
- **Gravité** : P1 - CRITICAL

## Timeline

| Heure | Événement |
|-------|-----------|
| 14:35 | Alerte VPG-RBX-to-SBG NotMeetingSLA |
| 14:40 | Confirmation perte site RBX |
| 14:50 | Début failover Application A |
| 15:15 | Failover Application A réussi (RTO: 25 min) |
| 15:30 | Activation backup d'urgence Application B |
| 16:45 | Premier backup complet Application B terminé |
| ... | Surveillance quotidienne |
| 17/12 09:00 | Site RBX rétabli |
| 17/12 09:20 | Resynchronisation terminée |

## Cause Racine

[À compléter après investigation OVH]

## Impact

- **Application A** : Indisponibilité de 25 minutes, perte < 5 min de données
- **Application B** : Aucune interruption, protection dégradée (RPO 12h vs 5 min)
- **Impact financier** : [À calculer]
- **Impact utilisateurs** : [À documenter]

## Ce qui a bien fonctionné ✅

1. Détection automatique (alertes en < 5 min)
2. Failover Application A réussi (RTO < 30 min)
3. Activation backup d'urgence automatisée
4. Communication équipe efficace
5. Runbook suivi correctement

## Points d'amélioration ⚠️

1. [À identifier]
2. [À identifier]
3. [À identifier]

## Actions Correctives

| Action | Priorité | Responsable | Date Cible |
|--------|----------|-------------|------------|
| [À définir] | P1 | [Nom] | [Date] |
| [À définir] | P2 | [Nom] | [Date] |

## Leçons Apprises

[À compléter]

---
**Rédigé par** : Équipe Infrastructure
**Date** : 19/12/2025
**Approuvé par** : [Manager]
```

---

## 📞 Contacts d'Escalade

### Niveau 1 - Ops Team (0-30 min)

- **Email** : ops-team@example.com
- **Téléphone** : +33 X XX XX XX XX
- **Slack** : #ops-incidents
- **Disponibilité** : 24/7

**Responsabilités :**
- Détection et diagnostic initial
- Vérifications basiques
- Escalade si non résolu en 30 min

### Niveau 2 - Infrastructure (30 min - 2h)

- **Email** : infra-team@example.com
- **Téléphone** : +33 X XX XX XX XX
- **Slack** : #infra-critical
- **Disponibilité** : 24/7

**Responsabilités :**
- Failover des applications
- Activation backups d'urgence
- Diagnostic approfondi
- Contact Support OVH

### Niveau 3 - Management / Crise (2h+)

- **Email** : cto@example.com
- **Téléphone** : +33 X XX XX XX XX
- **Disponibilité** : Sur appel

**Responsabilités :**
- Gestion de crise
- Communication externe
- Décisions stratégiques
- Coordination support OVH/Zerto

### Support Externe

**OVHcloud Support :**
- URL : https://www.ovh.com/manager/dedicated/#/support
- Téléphone : +33 9 72 10 10 07
- Email : support@ovh.com
- Contrat : Premium Support 24/7

**Zerto Support :**
- URL : https://www.zerto.com/support/
- Email : support@zerto.com
- Téléphone : +1-617-456-9200
- Contrat : Enterprise Support

---

## 📚 Annexes

### Annexe A: Checklist Complète

```
[ ] Phase 1: Diagnostic (0-15 min)
    [ ] Identifier site KO
    [ ] Vérifier VPGs
    [ ] Ouvrir ticket incident
    [ ] Notifier équipe

[ ] Phase 2: Actions Immédiates (15-60 min)
    [ ] Failover application vers site survivant
    [ ] Activer backup d'urgence application survivante
    [ ] Valider applications opérationnelles
    [ ] Configurer routes Fortigate
    [ ] Notification parties prenantes

[ ] Phase 3: Surveillance Continue (Quotidien)
    [ ] Vérifier site KO (tentative reconnexion)
    [ ] Valider backups d'urgence
    [ ] Surveiller espace disque
    [ ] Vérifier bitmap Zerto
    [ ] Rapport hebdomadaire

[ ] Phase 4: Retour Normal (Quand site revient)
    [ ] Attendre stabilisation (15 min)
    [ ] Surveiller resynchronisation
    [ ] Valider RPO < 5 min
    [ ] Décider conservation/désactivation backups
    [ ] Notification retour normal
    [ ] Post-mortem (48h)
```

### Annexe B: Commandes Utiles

```bash
# Vérifier VPGs
./zerto/scripts/check-vpg-status.sh --all --verbose

# Lancer failover
./zerto/scripts/failover-rbx-to-sbg.sh --force --vpg VPG-RBX-to-SBG

# Activer backup urgence
ansible-playbook zerto/ansible/playbooks/activate-emergency-backup.yml

# Vérifier backup Veeam
veeam-cli job list | grep Emergency

# Surveiller resynchronisation
watch -n 60 './zerto/scripts/check-sync-progress.sh'

# Taille bitmap
./zerto/scripts/check-bitmap-size.sh --vpg VPG-SBG-to-RBX
```

---

**Fin du Runbook**

**Version** : 1.0
**Dernière mise à jour** : 2025-12-17
**Prochaine révision** : 2026-01-17 (mensuel)
