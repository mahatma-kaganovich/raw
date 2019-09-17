sed -i -e 's:^\(#include <net/netfilter/nf_tables.h>\)$:#ifdef CONFIG_NF_TABLES\n\1\n#endif:' "$S"/net/bridge/netfilter/nf_conntrack_bridge.c
