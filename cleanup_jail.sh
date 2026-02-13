#!/bin/bash
#
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                     CLEANUP JAIL v2 — Nettoyage complet                  ║
# ║                                                                           ║
# ║  Ce script supprime toutes les vulnérabilités et fichiers créés par       ║
# ║  le lab Jail pour repartir sur une Debian propre.                         ║
# ║                                                                           ║
# ║  Actions :                                                                ║
# ║   - Démontage de /proc dans le chroot                                    ║
# ║   - Suppression de l'utilisateur jailed                                  ║
# ║   - Suppression du répertoire /home/jailed                               ║
# ║   - Suppression des règles sudoers vulnérables                           ║
# ║   - Suppression du bloc Match User dans sshd_config                      ║
# ║   - Nettoyage des tâches cron et binaires SUID suspects                  ║
# ║                                                                           ║
# ║  Usage : sudo ./cleanup_jail.sh                                           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
#

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           🧹 NETTOYAGE DU LAB JAIL v2 — DÉBUT                    ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Vérification root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Ce script doit être exécuté en root (sudo)${NC}"
    exit 1
fi

# Compteur
CLEANED=0

# ═══════════════════════════════════════════════════════════════════
# 1. Démontage de /proc dans le chroot (AVANT toute suppression)
# ═══════════════════════════════════════════════════════════════════
echo -e "${YELLOW}[1/9] Démontage de /proc dans le chroot...${NC}"
if mountpoint -q /home/jailed/proc 2>/dev/null; then
    umount /home/jailed/proc 2>/dev/null
    echo -e "${GREEN}   ✅ /home/jailed/proc démonté${NC}"
    ((CLEANED++))
else
    echo -e "   ⏭️  /proc non monté dans le chroot (OK)"
fi

# ═══════════════════════════════════════════════════════════════════
# 2. Suppression de l'utilisateur "jailed"
# ═══════════════════════════════════════════════════════════════════
echo -e "${YELLOW}[2/9] Vérification de l'utilisateur 'jailed'...${NC}"
if id "jailed" &>/dev/null; then
    userdel -r jailed 2>/dev/null
    echo -e "${GREEN}   ✅ Utilisateur 'jailed' supprimé${NC}"
    ((CLEANED++))
else
    echo -e "   ⏭️  Utilisateur 'jailed' non trouvé (OK)"
fi

# ═══════════════════════════════════════════════════════════════════
# 3. Suppression des règles sudo vulnérables (hôte)
# ═══════════════════════════════════════════════════════════════════
echo -e "${YELLOW}[3/9] Vérification des règles sudo vulnérables...${NC}"
if [ -f /etc/sudoers.d/vuln_vim ]; then
    rm -f /etc/sudoers.d/vuln_vim
    echo -e "${GREEN}   ✅ /etc/sudoers.d/vuln_vim supprimé${NC}"
    ((CLEANED++))
fi

# Vérifier d'autres règles sudoers suspectes
for f in /etc/sudoers.d/vuln_*; do
    if [ -f "$f" ]; then
        rm -f "$f"
        echo -e "${GREEN}   ✅ $f supprimé${NC}"
        ((CLEANED++))
    fi
done

echo -e "   ⏭️  Règles sudo vérifiées"

# ═══════════════════════════════════════════════════════════════════
# 4. Suppression du bloc Match User dans sshd_config
# ═══════════════════════════════════════════════════════════════════
echo -e "${YELLOW}[4/9] Suppression de la configuration SSH chroot...${NC}"

SSHD_CONFIG="/etc/ssh/sshd_config"
if grep -q "^Match User jailed" "$SSHD_CONFIG" 2>/dev/null; then
    # Supprimer le bloc complet entre les marqueurs
    sed -i '/^# === JAIL CHROOT SSH (ajouté par setup_jail.sh) ===/,/^# === FIN JAIL CHROOT SSH ===/d' "$SSHD_CONFIG"
    # Si les marqueurs ne sont pas présents, supprimer le bloc Match User manuellement
    if grep -q "^Match User jailed" "$SSHD_CONFIG" 2>/dev/null; then
        sed -i '/^Match User jailed/,/^$/d' "$SSHD_CONFIG"
    fi
    echo -e "${GREEN}   ✅ Bloc 'Match User jailed' supprimé de sshd_config${NC}"
    ((CLEANED++))

    # Redémarrer SSH
    if systemctl list-units --type=service | grep -q "ssh.service"; then
        systemctl restart ssh
    else
        systemctl restart sshd
    fi
    echo -e "${GREEN}   ✅ Service SSH redémarré${NC}"
else
    echo -e "   ⏭️  Pas de bloc Match User jailed dans sshd_config (OK)"
fi

# ═══════════════════════════════════════════════════════════════════
# 5. Suppression des répertoires du lab
# ═══════════════════════════════════════════════════════════════════
echo -e "${YELLOW}[5/9] Suppression des répertoires du lab...${NC}"

if [ -d /home/jailed ]; then
    rm -rf /home/jailed
    echo -e "${GREEN}   ✅ /home/jailed supprimé${NC}"
    ((CLEANED++))
else
    echo -e "   ⏭️  /home/jailed non trouvé (OK)"
fi

# ═══════════════════════════════════════════════════════════════════
# 6. Suppression des tâches cron malveillantes
# ═══════════════════════════════════════════════════════════════════
echo -e "${YELLOW}[6/9] Vérification des tâches cron vulnérables...${NC}"

if [ -f /etc/cron.d/vuln_cron ]; then
    rm -f /etc/cron.d/vuln_cron
    echo -e "${GREEN}   ✅ /etc/cron.d/vuln_cron supprimé${NC}"
    ((CLEANED++))
fi

# Chercher d'autres crons suspects
for f in /etc/cron.d/*vuln* /etc/cron.d/*malicious*; do
    if [ -f "$f" ]; then
        rm -f "$f"
        echo -e "${GREEN}   ✅ $f supprimé${NC}"
        ((CLEANED++))
    fi
done

echo -e "   ⏭️  Tâches cron vérifiées"

# ═══════════════════════════════════════════════════════════════════
# 7. Vérification et correction des binaires SUID suspects
# ═══════════════════════════════════════════════════════════════════
echo -e "${YELLOW}[7/9] Recherche de binaires SUID suspects...${NC}"

# Liste des binaires qui ne devraient JAMAIS être SUID
SUSPECT_SUIDS=("/bin/bash" "/usr/bin/bash" "/bin/sh" "/usr/bin/python3" "/usr/bin/python" "/usr/bin/env")

for bin in "${SUSPECT_SUIDS[@]}"; do
    if [ -f "$bin" ] && [ -u "$bin" ]; then
        chmod u-s "$bin"
        echo -e "${GREEN}   ✅ SUID retiré de $bin${NC}"
        ((CLEANED++))
    fi
done

# Recherche générale dans /tmp
for f in /tmp/rootbash /tmp/exploit.so; do
    if [ -f "$f" ]; then
        rm -f "$f"
        echo -e "${GREEN}   ✅ $f supprimé${NC}"
        ((CLEANED++))
    fi
done

echo -e "   ⏭️  Binaires SUID vérifiés"

# ═══════════════════════════════════════════════════════════════════
# 8. Suppression du groupe sshchroot si existant
# ═══════════════════════════════════════════════════════════════════
echo -e "${YELLOW}[8/9] Vérification du groupe sshchroot...${NC}"
if getent group sshchroot &>/dev/null; then
    groupdel sshchroot 2>/dev/null
    echo -e "${GREEN}   ✅ Groupe 'sshchroot' supprimé${NC}"
    ((CLEANED++))
else
    echo -e "   ⏭️  Groupe 'sshchroot' non trouvé (OK)"
fi

# ═══════════════════════════════════════════════════════════════════
# 9. Vérification des permissions /etc/passwd
# ═══════════════════════════════════════════════════════════════════
echo -e "${YELLOW}[9/9] Vérification des permissions /etc/passwd...${NC}"
PASSWD_PERMS=$(stat -c '%a' /etc/passwd)
if [ "$PASSWD_PERMS" != "644" ]; then
    chmod 644 /etc/passwd
    echo -e "${GREEN}   ✅ Permissions /etc/passwd corrigées (644)${NC}"
    ((CLEANED++))
else
    echo -e "   ⏭️  Permissions /etc/passwd OK (644)"
fi

# Vérifier s'il y a un utilisateur "hacker" dans /etc/passwd
if grep -q "^hacker:" /etc/passwd; then
    sed -i '/^hacker:/d' /etc/passwd
    echo -e "${GREEN}   ✅ Utilisateur 'hacker' supprimé de /etc/passwd${NC}"
    ((CLEANED++))
fi

# ═══════════════════════════════════════════════════════════════════
# RÉSUMÉ
# ═══════════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    🎯 NETTOYAGE TERMINÉ                           ║${NC}"
echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════╣${NC}"
if [ $CLEANED -gt 0 ]; then
    echo -e "${CYAN}║${NC}   ${GREEN}✅ $CLEANED élément(s) nettoyé(s)${NC}"
else
    echo -e "${CYAN}║${NC}   ${GREEN}✅ Système déjà propre - rien à nettoyer${NC}"
fi
echo -e "${CYAN}║${NC}"
echo -e "${CYAN}║${NC}   Éléments nettoyés :"
echo -e "${CYAN}║${NC}   • /proc démonté du chroot"
echo -e "${CYAN}║${NC}   • Utilisateur jailed supprimé"
echo -e "${CYAN}║${NC}   • Répertoire /home/jailed supprimé"
echo -e "${CYAN}║${NC}   • Règles sudoers vulnérables supprimées"
echo -e "${CYAN}║${NC}   • Configuration SSH chroot supprimée"
echo -e "${CYAN}║${NC}   • Tâches cron malveillantes supprimées"
echo -e "${CYAN}║${NC}   • Binaires SUID suspects vérifiés"
echo -e "${CYAN}║${NC}"
echo -e "${CYAN}║${NC}   La Debian est maintenant propre."
echo -e "${CYAN}║${NC}   Tu peux relancer ${YELLOW}./setup_jail.sh${NC} pour réinstaller le lab."
echo -e "${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
