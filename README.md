# JAIL v2 - Laboratoire de Privilege Escalation Linux

Environnement chroot SSH vulnérable pour l'apprentissage des techniques de privilege escalation sous Linux.

---

## Objectif

Ce lab permet de pratiquer différentes techniques d'élévation de privilèges dans un environnement isolé et contrôlé :
- SUID Bit Exploitation
- Writable /etc/passwd
- Cron Job Hijacking
- LD_PRELOAD Injection
- Sudo + Vim Escape (via `vuln_sudo_vim.sh`)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      DEBIAN SERVER                          │
│                                                             │
│   ┌─────────────────────────────────────────────────────┐   │
│   │            CHROOT JAIL (/home/jailed)               │   │
│   │                                                     │   │
│   │   /bin/       → bash, rbash, ls, cat, mkdir, rm,   │   │
│   │                 touch, python3, vim, env, find,     │   │
│   │                 grep, chmod, id, whoami, su, gcc    │   │
│   │   /lib/       → Bibliothèques (arborescence réelle)│   │
│   │   /etc/       → passwd, group, shadow, sudoers,    │   │
│   │                 pam.d, nsswitch.conf, cron.d        │   │
│   │   /tmp/       → Zone d'écriture pour les exploits   │   │
│   │   /proc/      → Monté par vuln_sudo_vim.sh         │   │
│   │   /dev/       → null, tty, urandom                  │   │
│   │                                                     │   │
│   │   Utilisateur : jailed                             │   │
│   │   Mot de passe : password123                       │   │
│   │                                                     │   │
│   └─────────────────────────────────────────────────────┘   │
│                                                             │
│   SSH : Match User jailed → ChrootDirectory /home/jailed   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

Le script `setup_jail.sh` configure automatiquement le **chroot SSH** via un bloc `Match User jailed` dans `/etc/ssh/sshd_config`. L'utilisateur `jailed` est ainsi réellement enfermé dans `/home/jailed` dès la connexion SSH.

---

## Installation

### Prérequis

- Debian 11/12 (installation minimale)
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

> **Note :** Le script `setup_jail.sh` installe automatiquement les dépendances manquantes (vim, python3, gcc) si elles ne sont pas présentes sur le système.

---

## Identifiants

| Utilisateur | Mot de passe   | Accès         |
|-------------|----------------|---------------|
| `jailed`    | `password123`  | SSH → Chroot  |

```bash
# Connexion depuis la machine attaquante
ssh jailed@<IP_DEBIAN>
```

---

## Vulnérabilités disponibles

Chaque script active une vulnérabilité spécifique dans l'environnement chroot :

| Script              | Vulnérabilité              | Exploitation                                    |
|---------------------|----------------------------|-------------------------------------------------|
| `vuln_suid.sh`      | SUID sur bash/python3      | `/bin/bash -p`                                  |
| `vuln_passwd.sh`    | /etc/passwd writable       | Ajout d'un utilisateur root                     |
| `vuln_cron.sh`      | Cron job modifiable        | Injection de commande via script malveillant    |
| `vuln_ldpreload.sh` | LD_PRELOAD exploitable     | Shared library injection                        |
| `vuln_sudo_vim.sh`  | Sudo + Vim escape          | `sudo vim -c ':!/bin/bash'`                     |

### Activation d'une vulnérabilité

```bash
# En root sur le serveur Debian
sudo ./vuln_suid.sh       # Active SUID
sudo ./vuln_passwd.sh     # Active passwd writable
sudo ./vuln_cron.sh       # Active cron vulnérable
sudo ./vuln_ldpreload.sh  # Active LD_PRELOAD
sudo ./vuln_sudo_vim.sh   # Active Sudo + Vim (installe sudo, PAM, NSS dans le chroot)
```

### Binaires disponibles dans le chroot

```
bash  rbash  ls  cat  mkdir  rm  touch  python3  vim  env
find  grep  chmod  id  whoami  su  gcc
```

Ces binaires permettent aux élèves d'effectuer toutes les étapes de reconnaissance et d'exploitation :
- `find` → détecter les binaires SUID
- `grep` → lire `/etc/passwd`, chercher des informations
- `id` / `whoami` → vérifier l'élévation de privilèges
- `su` → basculer sur un autre compte
- `gcc` → compiler les exploits (LD_PRELOAD)

---

## Nettoyage

Pour remettre la Debian à zéro et supprimer toutes les vulnérabilités :

```bash
sudo ./cleanup_jail.sh
```

Ce script supprime :
- `/proc` monté dans le chroot (démontage avant suppression)
- L'utilisateur `jailed`
- Les règles sudo vulnérables (`/etc/sudoers.d/vuln_*`)
- Le répertoire `/home/jailed`
- Le bloc `Match User jailed` dans `/etc/ssh/sshd_config` + redémarrage SSH
- Les tâches cron malveillantes
- Les binaires SUID suspects
- Les entrées frauduleuses dans `/etc/passwd`

---

## Ressources

- Documentation complète : `Tuto.docx`
- Interface web interactive : `jail-lab.html`
- [GTFOBins](https://gtfobins.github.io/) - Liste des binaires exploitables
- [HackTricks - Linux PrivEsc](https://book.hacktricks.xyz/linux-hardening/privilege-escalation)

---

## Avertissement

Ce laboratoire est destiné **uniquement à des fins éducatives** dans un environnement contrôlé.
L'utilisation de ces techniques sur des systèmes sans autorisation est **illégale**.

---

## Auteur

Slurptheworld
