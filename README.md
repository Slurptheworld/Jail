### Prérequis ####

## 1 - Installez une Debian.
## 2 - Ajouter l'option serveur SSH
## 3 - Se mettre en Root & Mise à jour 
    su -
    apt update
## 4 - Installer Git
    apt install git
## 5 - Installer dos2unix
    apt install dos2unix
## 6 - Rappatrier le dossier JAIL dans /opt/
    cd /opt
    git clone https://github.com/Slurptheworld/Jail.git
    cd Jail
## 7 - Rendre le fichier lisible setup_jail.sh
    dos2unix setup_jail.sh
## 8 - Mettre les droits d'excution sur le fichier
    chmod +755 setup_jail.sh
## 9 - Lancer l'installation du Jail
    ./setup_jail.sh

## infos
Utilisateur :
    Jailed
Mot de passe : 
    password123
    

📌 Plan d'Automatisation :

    Pensez à passer en dos2unix l'ensemble des scripts .sh :)
    Script principal (setup_jail.sh) → Automatisation de la mise en place du chroot SSH.
    Scripts individuels pour les vulnérabilités :
        vuln_suid.sh → Ajoute un binaire avec SUID.
        vuln_passwd.sh → Rend /etc/passwd modifiable.
        vuln_cron.sh → Crée une tâche cron malveillante.
        vuln_ldpreload.sh → Active une élévation via LD_PRELOAD.

📌 Conclusion

🎯 Ces scripts permettent de mettre en place un chroot SSH vulnérable et d’activer plusieurs types d’attaques.
