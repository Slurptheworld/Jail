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

# Création du groupe et de l'utilisateur pour le chroot
echo "✅ Création de l'utilisateur chroot..."
sudo groupadd sshchroot
sudo useradd -m -d /var/www/html -s /bin/bash -G sshchroot jailed
echo "jailed:password123" | sudo chpasswd  # Définir un mot de passe

# Configuration de SSH pour le chroot
echo "✅ Configuration de SSH..."
echo "Match Group sshchroot
    ChrootDirectory /var/www/html
    AllowTcpForwarding no
    X11Forwarding no
" | sudo tee -a /etc/ssh/sshd_config

# Redémarrer SSH pour appliquer les modifications
echo "✅ Redémarrage du service SSH après modification..."
sudo systemctl restart "$SSH_SERVICE"

# Création de la structure du chroot
echo "✅ Création de la structure chroot..."
sudo mkdir -p /var/www/html/{bin,lib,lib64,etc,home,tmp,dev}

# Correction des permissions du chroot
sudo chown root:root /var/www/html
sudo chmod 755 /var/www/html

# Copie des commandes essentielles dans le chroot
echo "✅ Copie des binaires essentiels..."
for cmd in bash sh ls cat echo mkdir pwd rm touch; do
    sudo cp /bin/$cmd /var/www/html/bin/
done

# Copie des bibliothèques nécessaires à `bash`
echo "✅ Copie des bibliothèques requises..."
ldd /bin/bash | awk '{print $3}' | grep -v '(' | xargs -I '{}' sudo cp '{}' /var/www/html/lib/
ldd /bin/bash | awk '{print $3}' | grep -v '(' | xargs -I '{}' sudo cp '{}' /var/www/html/lib64/

# Vérification et ajout de ld-linux-x86-64.so.2 si absent
if [ ! -f "/var/www/html/lib64/ld-linux-x86-64.so.2" ]; then
    echo "⚠️ ld-linux-x86-64.so.2 manquant. Copie en cours..."
    sudo cp /lib64/ld-linux-x86-64.so.2 /var/www/html/lib64/
fi

# Vérification que bash fonctionne dans le chroot
echo "✅ Vérification de l'exécution de bash dans le chroot..."
sudo chroot /var/www/html /bin/bash -c "echo 'Bash fonctionne dans le chroot !'"

# Correction des permissions finales
sudo chown -R root:root /var/www/html
sudo chmod -R 755 /var/www/html

echo "✅ Installation terminée !"
echo "🎯 Chroot SSH mis en place. Connecte-toi avec : ssh jailed@<IP>"
