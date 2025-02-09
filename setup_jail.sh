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

# Modification du fichier sshd_config pour éviter les conflits
echo "✅ Modification de sshd_config..."
sudo sed -i 's/^Subsystem sftp.*/#Subsystem sftp disabled/g' /etc/ssh/sshd_config
sudo sed -i 's/^X11Forwarding yes/X11Forwarding no/g' /etc/ssh/sshd_config
sudo sed -i 's/^UsePAM yes/UsePAM no/g' /etc/ssh/sshd_config

# Ajout de la configuration du chroot
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
sudo mkdir -p /var/www/html/{bin,lib,lib64,etc,home,tmp,dev,usr/bin,usr/lib,usr/share}

# Correction des permissions du chroot
sudo chown root:root /var/www/html
sudo chmod 755 /var/www/html

# Installation de Python3 et Vim si absent
echo "✅ Installation de Python3 et Vim..."
sudo apt update
sudo apt install -y python3 vim

# Copie des binaires essentiels dans le chroot
echo "✅ Copie des binaires essentiels..."
BINAIRES=(bash sh ls cat echo mkdir pwd rm touch python3 vim)

for cmd in "${BINAIRES[@]}"; do
    if command -v "$cmd" &> /dev/null; then
        sudo cp "$(command -v $cmd)" /var/www/html/bin/
    else
        echo "⚠️ Binaire $cmd introuvable, installation peut-être incomplète."
    fi
done

# Copie des bibliothèques nécessaires à `bash`, `python3` et `vim`
echo "✅ Copie des bibliothèques requises..."
BIN_LIBS=(/bin/bash /usr/bin/python3 /usr/bin/vim)

for bin in "${BIN_LIBS[@]}"; do
    ldd "$bin" | awk '{print $3}' | grep -v '(' | xargs -I '{}' sudo cp -v '{}' /var/www/html/lib/ 2>/dev/null
done

# Vérification et copie de `ld-linux-x86-64.so.2` (si absent)
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
echo "🎯 Chroot SSH mis en place avec Python3 et Vim ! Connecte-toi avec : ssh jailed@<IP>"
