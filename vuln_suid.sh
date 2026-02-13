#!/bin/bash
# Active le bit SUID sur bash et python3 dans le chroot

chmod 4755 /home/user/bin/bash
chmod 4755 /home/user/bin/python3

echo "✅ SUID activé sur /home/user/bin/bash. Exploitation : /home/user/bin/bash -p"
