i=
#-flto-toplevel-asm-heuristics ?
[[ "$CXXFLAGS" == *-fipa-reorder-for-locality* ]] && i=-fno-ipa-reorder-for-locality
# kill him
[[ "$CXXFLAGS" == *-ffat-lto-objects* ]] && i=-fno-lto
#gcc --help=common|grep flto-toplevel-asm-heuristics && i=-flto-toplevel-asm-heuristics
[ -n "$i" ] &&
    sed -i -e "s/\(lto-partitions=1['\"]\)/\1,\"$i\"/" "$S"/security/sandbox/linux/moz.build
