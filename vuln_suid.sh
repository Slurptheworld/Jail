#!/bin/bash
# Active le bit SUID sur bash et python3 dans le chroot

chmod 4755 /home/jailed/bin/bash
chmod 4755 /home/jailed/bin/python3

echo "✅ SUID activé sur /home/jailed/bin/bash. Exploitation : /home/jailed/bin/bash -p"
