sed -i -e 's:^#include:#include "xorg-server.h"\n#include :' "$S"/src/via_3d.c
