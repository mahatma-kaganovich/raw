[[ "$PV" == 1.12* ]] && sed -i -e 's:^\(#include "os.h"\):#include "xorg-server.h"\n\1:' "$S"/include/misc.h
