#!/bin/bash

echo "🚀 Début de l'installation de la JAIL vulnérable..."

# Vérification et installation d'OpenSSH si absent
if ! command -v sshd &> /dev/null; then
    echo "⚠️ OpenSSH Server non trouvé. Installation en cours..."
    sudo apt update && sudo apt install -y openssh-server
    sudo systemctl enable ssh
    sudo systemctl start ssh
fi

# Vérification et redémarrage du bon service SSH
if systemctl list-units --type=service | grep -q "ssh.service"; then
    SSH_SERVICE="ssh"
else
    SSH_SERVICE="sshd"
fi

echo "✅ Redémarrage du service SSH..."
sudo systemctl restart "$SSH_SERVICE"

# Création du groupe et de l'utilisateur pour la JAIL
echo "✅ Création de l'utilisateur JAIL vulnérable..."

# Vérifier si l'utilisateur existe déjà
if id "jailed" &>/dev/null; then
    echo "⚠️  L'utilisateur 'jailed' existe déjà. Suppression et recréation..."
    sudo userdel -r jailed 2>/dev/null
    sudo rm -rf /home/jailed 2>/dev/null
fi

sudo useradd -m -d /home/jailed -s /bin/rbash jailed
echo "jailed:password123" | sudo chpasswd

# Configuration du répertoire de l'utilisateur avec un environnement restreint
echo "✅ Configuration du home de l'utilisateur..."
sudo mkdir -p /home/jailed/bin
echo 'export PATH=/home/jailed/bin' | sudo tee -a /home/jailed/.bashrc

# Création d'une JAIL minimale
echo "✅ Création de la structure de la JAIL..."
sudo mkdir -p /home/jailed/{bin,lib,lib64,usr/bin,usr/lib,tmp,etc,dev}

# Copie des commandes nécessaires dans la JAIL
echo "✅ Copie des binaires essentiels..."
BINAIRES=(bash rbash ls cat echo mkdir pwd rm touch python3 vim env)

for cmd in "${BINAIRES[@]}"; do
    if command -v "$cmd" &> /dev/null; then
        sudo cp "$(command -v $cmd)" /home/jailed/bin/
    else
        echo "⚠️ Binaire $cmd introuvable, installation peut-être incomplète."
    fi
done

# Copie des bibliothèques nécessaires à `bash`, `python3`, et `vim`
echo "✅ Copie des bibliothèques requises..."
BIN_LIBS=(/bin/bash /usr/bin/python3 /usr/bin/vim /usr/bin/env)

for bin in "${BIN_LIBS[@]}"; do
    if [ -f "$bin" ]; then
        ldd "$bin" 2>/dev/null | awk '{print $3}' | grep -v '(' | xargs -I '{}' sudo cp -v '{}' /home/jailed/lib/ 2>/dev/null
    fi
done

# Création des devices nécessaires
echo "✅ Création des devices..."
sudo mknod -m 666 /home/jailed/dev/null c 1 3 2>/dev/null
sudo mknod -m 666 /home/jailed/dev/tty c 5 0 2>/dev/null
sudo mknod -m 444 /home/jailed/dev/urandom c 1 9 2>/dev/null

# Ajout d'une vulnérabilité dans sudoers : Élévation de privilège via `vim`
echo "✅ Ajout d'une faille sudo (élévation de privilège avec vim)..."
echo "jailed    ALL=(ALL)   NOPASSWD: /usr/bin/vim" | sudo tee /etc/sudoers.d/vuln_vim

# Vérification et test de la JAIL vulnérable
echo "✅ Vérification de l'environnement..."
sudo chroot /home/jailed /bin/bash -c "echo 'Bash fonctionne dans la JAIL !'"

# Correction des permissions finales
sudo chown -R root:root /home/jailed
sudo chmod -R 755 /home/jailed
sudo chmod 777 /home/jailed/tmp

echo ""
echo "✅ Installation terminée !"
echo "═══════════════════════════════════════════════════════════════"
echo "🎯 JAIL vulnérable mise en place avec Python3 et Vim."
echo ""
echo "📋 IDENTIFIANTS :"
echo "   Utilisateur : jailed"
echo "   Mot de passe : password123"
echo ""
echo "👉 Connexion : ssh jailed@<IP>"
echo "═══════════════════════════════════════════════════════════════"
