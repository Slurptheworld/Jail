# JAIL - Laboratoire de Privilege Escalation Linux

Environnement chroot SSH vulnérable pour l'apprentissage des techniques de privilege escalation sous Linux.

---

## Objectif

Ce lab permet de pratiquer différentes techniques d'élévation de privilèges dans un environnement isolé et contrôlé :
- SUID Bit Exploitation
- Writable /etc/passwd
- Cron Job Hijacking
- LD_PRELOAD Injection
- Sudo Misconfiguration

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    DEBIAN SERVER                        │
│                                                         │
│   ┌─────────────────────────────────────────────────┐   │
│   │              CHROOT JAIL (/home/user)           │   │
│   │                                                 │   │
│   │   /bin/       → Binaires (bash, ls, cat...)    │   │
│   │   /lib/       → Librairies système             │   │
│   │   /etc/       → Configurations                 │   │
│   │   /tmp/       → Fichiers temporaires           │   │
│   │   /dev/       → Devices (null, tty, urandom)   │   │
│   │                                                 │   │
│   │   Utilisateur : user                           │   │
│   │   Mot de passe : password123                   │   │
│   │                                                 │   │
│   └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Installation

### Prérequis

- Debian 11/12 (installation minimale)
- Serveur SSH activé
- Accès root

### Déploiement

```bash
# Passer en root
su -

# Mise à jour du système
apt update && apt upgrade -y

# Installation des dépendances
apt install git dos2unix -y

# Clonage du repository
cd /opt
git clone https://github.com/Slurptheworld/Jail.git
cd Jail

# Conversion des fins de ligne (Windows → Linux)
dos2unix *.sh

# Attribution des droits d'exécution
chmod +x *.sh

# Lancement de l'installation
./setup_jail.sh
```

---

## Identifiants

| Utilisateur | Mot de passe   | Accès         |
|-------------|----------------|---------------|
| `user`      | `password123`  | SSH → Chroot  |

```bash
# Connexion depuis la machine attaquante
ssh user@<IP_DEBIAN>
```

---

## Vulnérabilités disponibles

Chaque script active une vulnérabilité spécifique dans l'environnement chroot :

| Script              | Vulnérabilité              | Exploitation                                    |
|---------------------|----------------------------|-------------------------------------------------|
| `vuln_suid.sh`      | SUID sur bash/python3      | `/home/user/bin/bash -p`                        |
| `vuln_passwd.sh`    | /etc/passwd writable       | Ajout d'un utilisateur root                     |
| `vuln_cron.sh`      | Cron job modifiable        | Injection de commande via script malveillant    |
| `vuln_ldpreload.sh` | LD_PRELOAD exploitable     | Shared library injection                        |

### Activation d'une vulnérabilité

```bash
# En root sur le serveur Debian
sudo ./vuln_suid.sh      # Active SUID
sudo ./vuln_passwd.sh    # Active passwd writable
sudo ./vuln_cron.sh      # Active cron vulnérable
sudo ./vuln_ldpreload.sh # Active LD_PRELOAD
```

---

## Nettoyage

Pour remettre la Debian à zéro et supprimer toutes les vulnérabilités :

```bash
sudo ./cleanup_jail.sh
```

Ce script supprime :
- Utilisateurs `user` et `jailed`
- Règles sudo vulnérables (`/etc/sudoers.d/vuln_*`)
- Répertoires du lab (`/home/user`, `/var/www/html`)
- Tâches cron malveillantes
- Binaires SUID suspects
- Entrées frauduleuses dans `/etc/passwd`

---

## Ressources

- Documentation complète : `jail-lab.html`
- [GTFOBins](https://gtfobins.github.io/) - Liste des binaires exploitables
- [HackTricks - Linux PrivEsc](https://book.hacktricks.xyz/linux-hardening/privilege-escalation)

---

## Avertissement

Ce laboratoire est destiné **uniquement à des fins éducatives** dans un environnement contrôlé.
L'utilisation de ces techniques sur des systèmes sans autorisation est **illégale**.

---

## Auteur

Slurptheworld
