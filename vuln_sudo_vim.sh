#!/bin/bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  VULN SUDO VIM — Active la vulnérabilité Sudo + Vim dans le chroot      ║
# ║                                                                           ║
# ║  Ce script installe sudo dans le chroot avec toutes ses dépendances      ║
# ║  (PAM, NSS, passwd/group/shadow) et crée une règle sudoers permettant   ║
# ║  à l'utilisateur jailed d'exécuter vim en tant que root sans mot de     ║
# ║  passe. L'élève doit découvrir et exploiter cette misconfiguration.      ║
# ║                                                                           ║
# ║  Exploitation attendue :                                                  ║
# ║    sudo -l                     → repérer vim                             ║
# ║    sudo vim -c ':!/bin/bash'   → shell root                             ║
# ║                                                                           ║
# ║  Usage : sudo ./vuln_sudo_vim.sh                                         ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

JAIL="/home/jailed"

# ═══════════════════════════════════════════════════════════════════
# 0. Vérification root
# ═══════════════════════════════════════════════════════════════════
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ce script doit être exécuté en root (sudo ./vuln_sudo_vim.sh)"
    exit 1
fi

echo "🔧 Activation de la vulnérabilité Sudo + Vim dans le chroot..."

# ═══════════════════════════════════════════════════════════════════
# 1. Vérifier que le chroot existe
# ═══════════════════════════════════════════════════════════════════
if [ ! -d "$JAIL/bin" ]; then
    echo "❌ Le chroot $JAIL n'existe pas. Lancez d'abord ./setup_jail.sh"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════
# Fonction utilitaire : copier les libs d'un binaire dans le chroot
# ═══════════════════════════════════════════════════════════════════
copier_libs() {
    local bin="$1"
    if [ ! -f "$bin" ]; then
        return
    fi
    # Libs en colonne 3 de ldd
    ldd "$bin" 2>/dev/null | awk '{print $3}' | grep -v '^$' | while read -r lib; do
        if [ -f "$lib" ]; then
            mkdir -p "$JAIL$(dirname "$lib")"
            if [ ! -f "$JAIL${lib}" ]; then
                cp "$lib" "$JAIL${lib}"
            fi
        fi
    done
    # Linker dynamique (colonne 1 de ldd)
    local LINKER
    LINKER=$(ldd "$bin" 2>/dev/null | grep 'ld-linux' | awk '{print $1}')
    if [ -n "$LINKER" ] && [ -f "$LINKER" ]; then
        mkdir -p "$JAIL$(dirname "$LINKER")"
        if [ ! -f "$JAIL${LINKER}" ]; then
            cp "$LINKER" "$JAIL${LINKER}"
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════════
# 2. Copier le binaire sudo dans le chroot
# ═══════════════════════════════════════════════════════════════════
echo "   ✅ Copie de sudo dans le chroot..."
SUDO_PATH=$(which sudo 2>/dev/null)
if [ -z "$SUDO_PATH" ] || [ ! -f "$SUDO_PATH" ]; then
    echo "❌ sudo introuvable sur le système. Installation..."
    apt install -y sudo
    SUDO_PATH=$(which sudo 2>/dev/null)
fi

cp "$SUDO_PATH" "$JAIL/bin/sudo"
# SUID obligatoire pour que sudo fonctionne
chmod 4755 "$JAIL/bin/sudo"

# Copier les bibliothèques de sudo
copier_libs "$SUDO_PATH"

# ═══════════════════════════════════════════════════════════════════
# 3. Configuration PAM minimale (nécessaire pour sudo)
# ═══════════════════════════════════════════════════════════════════
echo "   ✅ Configuration PAM..."
mkdir -p "$JAIL/etc/pam.d"

# PAM config pour sudo : pam_permit autorise tout (suffisant car NOPASSWD)
cat > "$JAIL/etc/pam.d/sudo" <<'EOF'
auth       sufficient   pam_permit.so
account    sufficient   pam_permit.so
session    sufficient   pam_permit.so
EOF

cat > "$JAIL/etc/pam.d/other" <<'EOF'
auth       sufficient   pam_permit.so
account    sufficient   pam_permit.so
session    sufficient   pam_permit.so
EOF

# Copier les modules PAM nécessaires
PAM_DIR=$(dirname "$(find /lib /usr/lib -name "pam_permit.so" 2>/dev/null | head -1)" 2>/dev/null)
if [ -n "$PAM_DIR" ] && [ -d "$PAM_DIR" ]; then
    mkdir -p "$JAIL$PAM_DIR"
    for pam_mod in pam_permit.so pam_deny.so pam_unix.so; do
        if [ -f "$PAM_DIR/$pam_mod" ]; then
            cp "$PAM_DIR/$pam_mod" "$JAIL$PAM_DIR/"
            # Copier les dépendances de chaque module PAM
            copier_libs "$PAM_DIR/$pam_mod"
        fi
    done
    echo "   ✅ Modules PAM copiés depuis $PAM_DIR"
fi

# ═══════════════════════════════════════════════════════════════════
# 4. Configuration NSS (Name Service Switch)
# ═══════════════════════════════════════════════════════════════════
echo "   ✅ Configuration NSS..."

# nsswitch.conf minimal : résolution par fichiers locaux uniquement
cat > "$JAIL/etc/nsswitch.conf" <<'EOF'
passwd:     files
group:      files
shadow:     files
EOF

# Copier les bibliothèques NSS nécessaires
for nss_lib in libnss_files.so.2 libnss_compat.so.2; do
    NSS_PATH=$(find /lib /usr/lib -name "$nss_lib" 2>/dev/null | head -1)
    if [ -n "$NSS_PATH" ] && [ -f "$NSS_PATH" ]; then
        mkdir -p "$JAIL$(dirname "$NSS_PATH")"
        cp "$NSS_PATH" "$JAIL$NSS_PATH" 2>/dev/null
        copier_libs "$NSS_PATH"
    fi
done

# ═══════════════════════════════════════════════════════════════════
# 5. Création des fichiers passwd/group/shadow dans le chroot
# ═══════════════════════════════════════════════════════════════════
echo "   ✅ Création des fichiers d'authentification..."

# Récupérer les vrais UID/GID de l'utilisateur jailed
JAILED_UID=$(id -u jailed 2>/dev/null)
JAILED_GID=$(id -g jailed 2>/dev/null)

# /etc/passwd dans le chroot
cat > "$JAIL/etc/passwd" <<EOF
root:x:0:0:root:/root:/bin/bash
jailed:x:${JAILED_UID}:${JAILED_GID}:jailed:/home/jailed:/bin/bash
EOF

# /etc/group dans le chroot
cat > "$JAIL/etc/group" <<EOF
root:x:0:
jailed:x:${JAILED_GID}:
EOF

# /etc/shadow dans le chroot (mot de passe verrouillé, sudo est NOPASSWD)
cat > "$JAIL/etc/shadow" <<EOF
root:*:19000:0:99999:7:::
jailed:*:19000:0:99999:7:::
EOF

chmod 644 "$JAIL/etc/passwd"
chmod 644 "$JAIL/etc/group"
chmod 640 "$JAIL/etc/shadow"

# ═══════════════════════════════════════════════════════════════════
# 6. Configuration sudoers dans le chroot
# ═══════════════════════════════════════════════════════════════════
echo "   ✅ Configuration sudoers dans le chroot..."
mkdir -p "$JAIL/etc/sudoers.d"

# Fichier sudoers principal
cat > "$JAIL/etc/sudoers" <<'EOF'
# Sudoers file for the chroot jail
root    ALL=(ALL:ALL) ALL
#includedir /etc/sudoers.d
EOF

# Règle vulnérable : jailed peut lancer vim en root sans mot de passe
# IMPORTANT : chemin /bin/vim (dans le chroot, pas /usr/bin/vim)
cat > "$JAIL/etc/sudoers.d/vuln_vim" <<'EOF'
jailed    ALL=(ALL)   NOPASSWD: /bin/vim
EOF

chmod 440 "$JAIL/etc/sudoers"
chmod 440 "$JAIL/etc/sudoers.d/vuln_vim"

# ═══════════════════════════════════════════════════════════════════
# 7. Monter /proc dans le chroot (sudo en a besoin)
# ═══════════════════════════════════════════════════════════════════
echo "   ✅ Montage de /proc dans le chroot..."
mkdir -p "$JAIL/proc"
if ! mountpoint -q "$JAIL/proc" 2>/dev/null; then
    mount -t proc proc "$JAIL/proc"
    echo "   ✅ /proc monté dans $JAIL/proc"
else
    echo "   ⏭️  /proc déjà monté"
fi

# ═══════════════════════════════════════════════════════════════════
# 8. Permissions
# ═══════════════════════════════════════════════════════════════════
# S'assurer que sudo reste SUID après le chown global
chown root:root "$JAIL/bin/sudo"
chmod 4755 "$JAIL/bin/sudo"

# ═══════════════════════════════════════════════════════════════════
# 9. Test : vérifier que sudo fonctionne dans le chroot
# ═══════════════════════════════════════════════════════════════════
echo ""
echo "✅ Test de sudo dans le chroot..."
if chroot "$JAIL" /bin/bash -c "sudo -l -U jailed 2>/dev/null" | grep -q "vim"; then
    echo "   🎉 sudo -l fonctionne ! La règle vim est active."
else
    echo "   ⚠️  sudo -l n'a pas retourné la règle vim."
    echo "   Le test peut échouer en dehors du contexte SSH."
    echo "   Vérification manuelle : chroot $JAIL /bin/bash puis sudo -l"
fi

# ═══════════════════════════════════════════════════════════════════
# RÉSUMÉ
# ═══════════════════════════════════════════════════════════════════
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✅ Vulnérabilité Sudo + Vim activée !"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "📋 Ce qui a été installé dans le chroot :"
echo "   • sudo (SUID root)"
echo "   • PAM (pam_permit.so)"
echo "   • NSS (nsswitch.conf + libnss_files)"
echo "   • /etc/passwd, /etc/group, /etc/shadow"
echo "   • /etc/sudoers + /etc/sudoers.d/vuln_vim"
echo "   • /proc monté"
echo ""
echo "💀 Exploitation attendue (côté élève en SSH) :"
echo "   sudo -l                      → repérer (ALL) NOPASSWD: /bin/vim"
echo "   sudo vim -c ':!/bin/bash'    → shell root"
echo "═══════════════════════════════════════════════════════════════"
