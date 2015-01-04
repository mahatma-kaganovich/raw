sed -i -e 's:^#include:#include "xorg-server.h"\n#include :' "$S"/vmwgfx/vmwgfx_overlay.c
