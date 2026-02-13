#!/bin/bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  SETUP JAIL v2 — Installation de la JAIL vulnérable                      ║
# ║                                                                           ║
# ║  Ce script crée un environnement chroot SSH isolé avec un jeu limité     ║
# ║  de binaires pour pratiquer l'élévation de privilèges Linux.             ║
# ║                                                                           ║
# ║  Corrections v2 :                                                         ║
# ║   - echo/pwd retirés (builtins bash, pas de binaire sur disque)          ║
# ║   - Installation automatique de vim, python3 et gcc si absents           ║
# ║   - Copie des libs avec arborescence complète (fix chroot crash)         ║
# ║   - Copie du linker dynamique (ld-linux-x86-64.so)                      ║
# ║   - Copie des libs de TOUS les binaires (pas seulement bash/python/vim)  ║
# ║   - Ajout des binaires manquants (find, grep, chmod, id, whoami, su, gcc)║
# ║   - Configuration automatique du chroot SSH (Match User dans sshd_config)║
# ║   - Retrait de la règle sudoers vim (déplacée dans vuln_sudo_vim.sh)     ║
# ║                                                                           ║
# ║  Usage : sudo ./setup_jail.sh                                            ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

JAIL="/home/jailed"

echo "🚀 Début de l'installation de la JAIL vulnérable..."

# ═══════════════════════════════════════════════════════════════════
# 0. Vérification root
# ═══════════════════════════════════════════════════════════════════
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ce script doit être exécuté en root (sudo ./setup_jail.sh)"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════
# 1. Vérification et installation d'OpenSSH si absent
# ═══════════════════════════════════════════════════════════════════
if ! command -v sshd &> /dev/null; then
    echo "⚠️ OpenSSH Server non trouvé. Installation en cours..."
    apt update && apt install -y openssh-server
    systemctl enable ssh
    systemctl start ssh
fi

# Détection du nom du service SSH (ssh ou sshd selon la distro)
if systemctl list-units --type=service | grep -q "ssh.service"; then
    SSH_SERVICE="ssh"
else
    SSH_SERVICE="sshd"
fi

# ═══════════════════════════════════════════════════════════════════
# 2. Installation des dépendances manquantes (vim, python3, gcc)
# ═══════════════════════════════════════════════════════════════════
echo "✅ Vérification des dépendances..."

DEPS_MANQUANTES=()

# Vérifier vim
if ! command -v vim &> /dev/null; then
    DEPS_MANQUANTES+=(vim)
fi

# Vérifier python3
if ! command -v python3 &> /dev/null; then
    DEPS_MANQUANTES+=(python3)
fi

# Vérifier gcc
if ! command -v gcc &> /dev/null; then
    DEPS_MANQUANTES+=(gcc)
fi

# Installer les dépendances manquantes si nécessaire
if [ ${#DEPS_MANQUANTES[@]} -gt 0 ]; then
    echo "⚠️ Paquets manquants : ${DEPS_MANQUANTES[*]}. Installation..."
    apt update && apt install -y "${DEPS_MANQUANTES[@]}"
fi

# ═══════════════════════════════════════════════════════════════════
# 3. Création de l'utilisateur jailed
# ═══════════════════════════════════════════════════════════════════
echo "✅ Création de l'utilisateur JAIL vulnérable..."

# Supprimer si l'utilisateur existe déjà (réinstallation propre)
if id "jailed" &>/dev/null; then
    echo "⚠️  L'utilisateur 'jailed' existe déjà. Suppression et recréation..."
    userdel -r jailed 2>/dev/null
    # Démonter /proc si monté dans le chroot (cas de réinstallation)
    umount "$JAIL/proc" 2>/dev/null
    rm -rf "$JAIL" 2>/dev/null
fi

# Création avec bash (l'isolation est assurée par le chroot SSH, pas par rbash)
useradd -m -d "$JAIL" -s /bin/bash jailed
echo "jailed:password123" | chpasswd

# ═══════════════════════════════════════════════════════════════════
# 4. Configuration du home et du PATH
# ═══════════════════════════════════════════════════════════════════
echo "✅ Configuration du home de l'utilisateur..."
mkdir -p "$JAIL/bin"
echo 'export PATH=/bin:/usr/bin' | tee -a "$JAIL/.bashrc" > /dev/null

# ═══════════════════════════════════════════════════════════════════
# 5. Création de la structure du chroot
# ═══════════════════════════════════════════════════════════════════
echo "✅ Création de la structure de la JAIL..."
mkdir -p "$JAIL"/{bin,lib,lib64,usr/bin,usr/lib,tmp,etc,dev}

# ═══════════════════════════════════════════════════════════════════
# 6. Copie des binaires essentiels dans le chroot
# ═══════════════════════════════════════════════════════════════════
echo "✅ Copie des binaires essentiels..."

# IMPORTANT : echo et pwd sont des builtins bash (pas de fichier sur disque)
#             Ils fonctionnent nativement dans bash, inutile de les copier.
# Liste complète incluant les outils nécessaires aux exploitations :
#   find  → détecter les SUID
#   grep  → lire passwd, chercher des infos
#   chmod → préparer les payloads
#   id/whoami → vérifier l'élévation de privilèges
#   su    → basculer sur un autre compte
#   gcc   → compiler les exploits (LD_PRELOAD)
BINAIRES=(bash ls cat mkdir rm touch python3 vim env find grep chmod id whoami su gcc)

for cmd in "${BINAIRES[@]}"; do
    # Récupérer le chemin réel du binaire (ignore les builtins)
    CMD_PATH=$(which "$cmd" 2>/dev/null)

    if [ -n "$CMD_PATH" ] && [ -f "$CMD_PATH" ]; then
        cp "$CMD_PATH" "$JAIL/bin/"
        echo "   ✅ $cmd → $JAIL/bin/"
    else
        echo "   ⚠️ Binaire $cmd introuvable — ignoré"
    fi
done

# ═══════════════════════════════════════════════════════════════════
# 7. Copie des bibliothèques avec arborescence complète
# ═══════════════════════════════════════════════════════════════════
# FIX v2 : Le chroot a besoin que les libs soient au même chemin
#           que sur le système hôte, sinon le linker dynamique ne
#           les trouve pas → "No such file or directory" sur bash.
#
# On copie les dépendances de TOUS les binaires de la liste,
# pas seulement bash/python3/vim/env.
# ═══════════════════════════════════════════════════════════════════
echo "✅ Copie des bibliothèques requises (avec arborescence)..."

# Fonction pour copier les libs d'un binaire avec arborescence complète
copier_libs() {
    local bin="$1"
    if [ ! -f "$bin" ]; then
        return
    fi

    # Extraire les bibliothèques listées en colonne 3 de ldd
    ldd "$bin" 2>/dev/null | awk '{print $3}' | grep -v '^$' | while read -r lib; do
        if [ -f "$lib" ]; then
            # Recréer le chemin complet dans le chroot
            mkdir -p "$JAIL$(dirname "$lib")"
            # Copier seulement si pas déjà présente
            if [ ! -f "$JAIL${lib}" ]; then
                cp "$lib" "$JAIL${lib}"
            fi
        fi
    done

    # Copier aussi le linker dynamique (ld-linux-x86-64.so.2)
    # Il apparaît dans la première colonne de ldd, pas la troisième
    local LINKER
    LINKER=$(ldd "$bin" 2>/dev/null | grep 'ld-linux' | awk '{print $1}')
    if [ -n "$LINKER" ] && [ -f "$LINKER" ]; then
        mkdir -p "$JAIL$(dirname "$LINKER")"
        if [ ! -f "$JAIL${LINKER}" ]; then
            cp "$LINKER" "$JAIL${LINKER}"
        fi
    fi
}

# Copier les libs de TOUS les binaires de la liste
for cmd in "${BINAIRES[@]}"; do
    CMD_PATH=$(which "$cmd" 2>/dev/null)
    if [ -n "$CMD_PATH" ] && [ -f "$CMD_PATH" ]; then
        copier_libs "$CMD_PATH"
    fi
done

echo "   ✅ Bibliothèques copiées avec arborescence complète"

# ═══════════════════════════════════════════════════════════════════
# 8. Création des devices nécessaires
# ═══════════════════════════════════════════════════════════════════
echo "✅ Création des devices..."
mknod -m 666 "$JAIL/dev/null" c 1 3 2>/dev/null
mknod -m 666 "$JAIL/dev/tty" c 5 0 2>/dev/null
mknod -m 444 "$JAIL/dev/urandom" c 1 9 2>/dev/null

# ═══════════════════════════════════════════════════════════════════
# 9. Correction des permissions finales
# ═══════════════════════════════════════════════════════════════════
echo "✅ Application des permissions..."
# IMPORTANT : Pour que ChrootDirectory SSH fonctionne,
# /home/jailed et tous ses parents doivent appartenir à root:root
# et ne pas être writable par le groupe/others (755)
chown -R root:root "$JAIL"
chmod -R 755 "$JAIL"
chmod 777 "$JAIL/tmp"

# ═══════════════════════════════════════════════════════════════════
# 10. Configuration du chroot SSH (Match User)
# ═══════════════════════════════════════════════════════════════════
# FIX v2 : Sans cette configuration, l'utilisateur jailed se connecte
#           en SSH et arrive sur le système COMPLET au lieu d'être
#           enfermé dans /home/jailed. C'est le bug le plus critique.
# ═══════════════════════════════════════════════════════════════════
echo "✅ Configuration du chroot SSH..."

SSHD_CONFIG="/etc/ssh/sshd_config"

# Vérifier que le bloc Match User n'existe pas déjà (idempotence)
if ! grep -q "^Match User jailed" "$SSHD_CONFIG" 2>/dev/null; then
    cat >> "$SSHD_CONFIG" <<'EOF'

# === JAIL CHROOT SSH (ajouté par setup_jail.sh) ===
Match User jailed
    ChrootDirectory /home/jailed
    ForceCommand /bin/bash
    AllowTcpForwarding no
    X11Forwarding no
# === FIN JAIL CHROOT SSH ===
EOF
    echo "   ✅ Bloc 'Match User jailed' ajouté dans $SSHD_CONFIG"
else
    echo "   ⏭️  Bloc 'Match User jailed' déjà présent dans $SSHD_CONFIG"
fi

# Redémarrer SSH pour appliquer la configuration
systemctl restart "$SSH_SERVICE"
echo "   ✅ Service SSH redémarré"

# ═══════════════════════════════════════════════════════════════════
# 11. Test de validation du chroot
# ═══════════════════════════════════════════════════════════════════
echo "✅ Vérification de l'environnement..."
echo ""

if chroot "$JAIL" /bin/bash -c "echo '   🎉 Bash fonctionne dans la JAIL !'"; then
    JAIL_OK=true
else
    JAIL_OK=false
    echo ""
    echo "❌ ERREUR : Le chroot ne démarre pas."
    echo "   Diagnostic :"
    echo "   1. Vérifier les bibliothèques : ldd $JAIL/bin/bash"
    echo "   2. Vérifier le linker : ls -la $JAIL/lib64/"
    echo "   3. Comparer avec : ldd /bin/bash"
    echo ""
    echo "   Libs manquantes :"
    ldd "$JAIL/bin/bash" 2>&1 | grep "not found" || echo "   (aucune lib manquante détectée)"
fi

# ═══════════════════════════════════════════════════════════════════
# RÉSUMÉ FINAL
# ═══════════════════════════════════════════════════════════════════
echo ""
echo "═══════════════════════════════════════════════════════════════"

if [ "$JAIL_OK" = true ]; then
    echo "✅ Installation terminée avec succès !"
else
    echo "⚠️  Installation terminée AVEC ERREURS — voir ci-dessus"
fi

echo "═══════════════════════════════════════════════════════════════"
echo "🎯 JAIL vulnérable v2 mise en place."
echo ""
echo "📋 IDENTIFIANTS :"
echo "   Utilisateur : jailed"
echo "   Mot de passe : password123"
echo ""
echo "👉 Connexion : ssh jailed@<IP>"
echo ""
echo "🔒 Chroot SSH : activé (Match User jailed dans sshd_config)"
echo ""
echo "📦 Binaires disponibles dans le chroot :"
echo "   $(ls "$JAIL/bin/" 2>/dev/null | tr '\n' ' ')"
echo ""
echo "📂 Vulnérabilités disponibles :"
echo "   sudo ./vuln_suid.sh       → SUID sur bash/python3"
echo "   sudo ./vuln_passwd.sh     → /etc/passwd writable"
echo "   sudo ./vuln_cron.sh       → Cron job modifiable"
echo "   sudo ./vuln_ldpreload.sh  → LD_PRELOAD injection"
echo "   sudo ./vuln_sudo_vim.sh   → Sudo + Vim escape"
echo "═══════════════════════════════════════════════════════════════"
