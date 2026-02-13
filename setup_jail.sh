#!/bin/bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  SETUP JAIL v2 — Installation de la JAIL vulnérable                      ║
# ║                                                                           ║
# ║  Corrections v2 :                                                         ║
# ║   - echo/pwd retirés de la liste (builtins bash, pas de binaire)         ║
# ║   - Installation automatique de vim s'il est absent                      ║
# ║   - Copie des libs avec arborescence complète (fix chroot crash)         ║
# ║   - Copie du linker dynamique (ld-linux-x86-64.so)                      ║
# ║                                                                           ║
# ║  Usage : sudo ./setup_jail.sh                                            ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

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

echo "✅ Redémarrage du service SSH..."
systemctl restart "$SSH_SERVICE"

# ═══════════════════════════════════════════════════════════════════
# 2. Installation des dépendances manquantes (vim, python3)
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
    rm -rf /home/jailed 2>/dev/null
fi

# Création avec shell restreint rbash
useradd -m -d /home/jailed -s /bin/rbash jailed
echo "jailed:password123" | chpasswd

# ═══════════════════════════════════════════════════════════════════
# 4. Configuration du home et du PATH restreint
# ═══════════════════════════════════════════════════════════════════
echo "✅ Configuration du home de l'utilisateur..."
mkdir -p /home/jailed/bin
echo 'export PATH=/home/jailed/bin' | tee -a /home/jailed/.bashrc > /dev/null

# ═══════════════════════════════════════════════════════════════════
# 5. Création de la structure du chroot
# ═══════════════════════════════════════════════════════════════════
echo "✅ Création de la structure de la JAIL..."
mkdir -p /home/jailed/{bin,lib,lib64,usr/bin,usr/lib,tmp,etc,dev}

# ═══════════════════════════════════════════════════════════════════
# 6. Copie des binaires essentiels dans le chroot
# ═══════════════════════════════════════════════════════════════════
echo "✅ Copie des binaires essentiels..."

# IMPORTANT : echo et pwd sont des builtins bash (pas de fichier sur disque)
#             Ils fonctionnent nativement dans bash, inutile de les copier.
BINAIRES=(bash rbash ls cat mkdir rm touch python3 vim env)

for cmd in "${BINAIRES[@]}"; do
    # Récupérer le chemin réel du binaire (ignore les builtins)
    CMD_PATH=$(which "$cmd" 2>/dev/null)

    if [ -n "$CMD_PATH" ] && [ -f "$CMD_PATH" ]; then
        cp "$CMD_PATH" /home/jailed/bin/
        echo "   ✅ $cmd → /home/jailed/bin/"
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
# ═══════════════════════════════════════════════════════════════════
echo "✅ Copie des bibliothèques requises (avec arborescence)..."

# Liste des binaires dont on doit copier les dépendances
BIN_LIBS=(/bin/bash /usr/bin/python3 /usr/bin/vim /usr/bin/env)

for bin in "${BIN_LIBS[@]}"; do
    if [ -f "$bin" ]; then
        # Extraire chaque bibliothèque listée par ldd
        ldd "$bin" 2>/dev/null | awk '{print $3}' | grep -v '^$' | while read -r lib; do
            if [ -f "$lib" ]; then
                # Recréer le chemin complet dans le chroot
                LIB_DIR="/home/jailed$(dirname "$lib")"
                mkdir -p "$LIB_DIR"
                # Copier seulement si pas déjà présente
                if [ ! -f "/home/jailed${lib}" ]; then
                    cp -v "$lib" "/home/jailed${lib}"
                fi
            fi
        done

        # Copier aussi le linker dynamique (ld-linux-x86-64.so.2)
        # Il apparaît dans la première colonne de ldd, pas la troisième
        LINKER=$(ldd "$bin" 2>/dev/null | grep 'ld-linux' | awk '{print $1}')
        if [ -n "$LINKER" ] && [ -f "$LINKER" ]; then
            LINKER_DIR="/home/jailed$(dirname "$LINKER")"
            mkdir -p "$LINKER_DIR"
            if [ ! -f "/home/jailed${LINKER}" ]; then
                cp -v "$LINKER" "/home/jailed${LINKER}"
            fi
        fi
    fi
done

# Copie de secours : aussi dans /home/jailed/lib/ en flat (rétrocompatibilité)
for bin in "${BIN_LIBS[@]}"; do
    if [ -f "$bin" ]; then
        ldd "$bin" 2>/dev/null | awk '{print $3}' | grep -v '^$' | while read -r lib; do
            if [ -f "$lib" ] && [ ! -f "/home/jailed/lib/$(basename "$lib")" ]; then
                cp "$lib" /home/jailed/lib/ 2>/dev/null
            fi
        done
    fi
done

# ═══════════════════════════════════════════════════════════════════
# 8. Création des devices nécessaires
# ═══════════════════════════════════════════════════════════════════
echo "✅ Création des devices..."
mknod -m 666 /home/jailed/dev/null c 1 3 2>/dev/null
mknod -m 666 /home/jailed/dev/tty c 5 0 2>/dev/null
mknod -m 444 /home/jailed/dev/urandom c 1 9 2>/dev/null

# ═══════════════════════════════════════════════════════════════════
# 9. Ajout de la vulnérabilité sudo vim
# ═══════════════════════════════════════════════════════════════════
echo "✅ Ajout d'une faille sudo (élévation de privilège avec vim)..."
echo "jailed    ALL=(ALL)   NOPASSWD: /usr/bin/vim" | tee /etc/sudoers.d/vuln_vim > /dev/null
chmod 440 /etc/sudoers.d/vuln_vim

# ═══════════════════════════════════════════════════════════════════
# 10. Correction des permissions finales
# ═══════════════════════════════════════════════════════════════════
echo "✅ Application des permissions..."
chown -R root:root /home/jailed
chmod -R 755 /home/jailed
chmod 777 /home/jailed/tmp

# ═══════════════════════════════════════════════════════════════════
# 11. Test de validation du chroot
# ═══════════════════════════════════════════════════════════════════
echo "✅ Vérification de l'environnement..."
echo ""

if chroot /home/jailed /bin/bash -c "echo '   🎉 Bash fonctionne dans la JAIL !'"; then
    JAIL_OK=true
else
    JAIL_OK=false
    echo ""
    echo "❌ ERREUR : Le chroot ne démarre pas."
    echo "   Vérifier les bibliothèques avec : ldd /home/jailed/bin/bash"
    echo "   Puis comparer avec : ls -la /home/jailed/lib/"
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
echo "🎯 JAIL vulnérable mise en place avec Python3 et Vim."
echo ""
echo "📋 IDENTIFIANTS :"
echo "   Utilisateur : jailed"
echo "   Mot de passe : password123"
echo ""
echo "👉 Connexion : ssh jailed@<IP>"
echo ""
echo "📦 Binaires disponibles dans le chroot :"
echo "   $(ls /home/jailed/bin/ 2>/dev/null | tr '\n' ' ')"
echo "═══════════════════════════════════════════════════════════════"
