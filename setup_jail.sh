#!/bin/bash
# Script de mise en place du chroot SSH avec utilisateur limité

# Création du groupe et de l'utilisateur
groupadd sshchroot
useradd -m -d /var/www/html -s /bin/bash -G sshchroot jailed
echo "jailed:password123" | chpasswd  # Modifie le mot de passe

# Configuration de SSH
echo "Match Group sshchroot
    ChrootDirectory /var/www/html
    AllowTcpForwarding no
    X11Forwarding no
" >> /etc/ssh/sshd_config

systemctl restart sshd

# Création de la structure du chroot
mkdir -p /var/www/html/{bin,lib,lib64,etc,home,tmp,dev}
chown root:root /var/www/html
chmod 755 /var/www/html

# Copie des commandes essentielles
for cmd in bash sh ls cat echo mkdir pwd rm touch; do
    cp /bin/$cmd /var/www/html/bin/
done

# Copie des bibliothèques nécessaires
ldd /bin/bash /bin/ls /bin/cat /bin/echo | awk '{print $3}' | grep -v '(' | xargs -I '{}' cp '{}' /var/www/html/lib/
ldd /bin/bash | awk '{print $3}' | grep -v '(' | xargs -I '{}' cp '{}' /var/www/html/lib64/

# Permissions
chown -R root:root /var/www/html
chmod -R 755 /var/www/html

echo "🚀 Chroot SSH mis en place ! Connecte-toi avec : ssh jailed@<IP>"
