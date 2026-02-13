#!/bin/bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  VULN SUDO VIM — Active la vulnérabilité Sudo + Vim dans le chroot      ║
# ║                                                                           ║
# ║  Ce script installe sudo dans le chroot et crée une règle sudoers       ║
# ║  permettant à jailed d'exécuter vim en root sans mot de passe.          ║
# ║  PAM, NSS, passwd/group/shadow sont déjà installés par setup_jail.sh.   ║
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
# 3. Configuration sudoers dans le chroot
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
# 4. Monter /proc dans le chroot (sudo en a besoin)
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
# 5. Permissions
# ═══════════════════════════════════════════════════════════════════
# S'assurer que sudo reste SUID après un éventuel chown
chown root:root "$JAIL/bin/sudo"
chmod 4755 "$JAIL/bin/sudo"

# ═══════════════════════════════════════════════════════════════════
# 6. Test : vérifier que sudo fonctionne dans le chroot
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
echo "   • /etc/sudoers + /etc/sudoers.d/vuln_vim"
echo "   • /proc monté"
echo "   (PAM, NSS, passwd/group/shadow déjà présents via setup_jail.sh)"
echo ""
echo "💀 Exploitation attendue (côté élève en SSH) :"
echo "   sudo -l                      → repérer (ALL) NOPASSWD: /bin/vim"
echo "   sudo vim -c ':!/bin/bash'    → shell root"
echo "═══════════════════════════════════════════════════════════════"
