#!/bin/bash

echo "🚀 Début de l'installation du Chroot SSH..."

# Vérification et installation de dos2unix pour éviter les erreurs de format
if ! command -v dos2unix &> /dev/null; then
    echo "⚠️ dos2unix non trouvé. Installation en cours..."
    sudo apt update && sudo apt install -y dos2unix
fi
dos2unix "$0"

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

# Création du groupe et de l'utilisateur po
