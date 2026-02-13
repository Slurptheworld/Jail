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
if id "user" &>/dev/null; then
    echo "⚠️  L'utilisateur 'user' existe déjà. Suppression et recréation..."
    sudo userdel -r user 2>/dev/null
    sudo rm -rf /home/user 2>/dev/null
fi

sudo useradd -m -d /home/user -s /bin/rbash user
echo "user:password123" | sudo chpasswd  # Définir un mot de passe

# Configuration du répertoire de l'utilisateur avec un environnement restreint
echo "✅ Configuration du home de l'utilisateur..."
sudo mkdir -p /home/user/bin
echo 'export PATH=/home/user/bin' | sudo tee -a /home/user/.bashrc

# Création d'une JAIL minimale
echo "✅ Création de la structure de la JAIL..."
sudo mkdir -p /home/user/{bin,lib,lib64,usr/bin,usr/lib}

# Copie des commandes nécessaires dans la JAIL
echo "✅ Copie des binaires essentiels..."
BINAIRES=(bash rbash ls cat echo mkdir pwd rm touch python3 vim)

for cmd in "${BINAIRES[@]}"; do
    if command -v "$cmd" &> /dev/null; then
        sudo cp "$(command -v $cmd)" /home/user/bin/
    else
        echo "⚠️ Binaire $cmd introuvable, installation peut-être incomplète."
    fi
done

# Copie des bibliothèques nécessaires à `bash`, `python3`, et `vim`
echo "✅ Copie des bibliothèques requises..."
BIN_LIBS=(/bin/bash /usr/bin/python3 /usr/bin/vim)

for bin in "${BIN_LIBS[@]}"; do
    ldd "$bin" | awk '{print $3}' | grep -v '(' | xargs -I '{}' sudo cp -v '{}' /home/user/lib/ 2>/dev/null
done

# Ajout d'une vulnérabilité dans sudoers : Élévation de privilège via `vim`
echo "✅ Ajout d'une faille sudo (élévation de privilège avec vim)..."
echo "user    ALL=(ALL)   NOPASSWD: /usr/bin/vim" | sudo tee -a /etc/sudoers.d/vuln_vim

# Vérification et test de la JAIL vulnérable
echo "✅ Vérification de l'environnement..."
sudo chroot /home/user /bin/bash -c "echo 'Bash fonctionne dans la JAIL !'"

# Correction des permissions finales
sudo chown -R root:root /home/user
sudo chmod -R 755 /home/user

echo "✅ Installation terminée !"
echo "🎯 JAIL vulnérable mise en place avec Python3 et Vim."
echo "👉 Connecte-toi avec : ssh user@<IP>"
echo "💀 Pour sortir de la JAIL : python3 -c 'import pty;pty.spawn(\"/bin/bash\")'"
echo "🔓 Pour devenir root : sudo -u root /usr/bin/vim + ':set shell=/bin/bash|shell'"
