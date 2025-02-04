📌 Plan d'Automatisation :

    Script principal (setup_jail.sh) → Automatisation de la mise en place du chroot SSH.
    Scripts individuels pour les vulnérabilités :
        vuln_suid.sh → Ajoute un binaire avec SUID.
        vuln_passwd.sh → Rend /etc/passwd modifiable.
        vuln_cron.sh → Crée une tâche cron malveillante.
        vuln_ldpreload.sh → Active une élévation via LD_PRELOAD.

📌 Conclusion

🎯 Ces scripts permettent de mettre en place un chroot SSH vulnérable et d’activer plusieurs types d’attaques.
