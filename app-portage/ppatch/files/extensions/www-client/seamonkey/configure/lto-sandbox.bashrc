i=
[[ "$CXXFLAGS" == *-fipa-reorder-for-locality* ]] && i=-fno-ipa-reorder-for-locality
# kill him
[[ "$CXXFLAGS" == *-ffat-lto-objects* ]] && i=-fno-lto
[ -n "$i" ] &&
    sed -i -e "s/\(lto-partitions=1['\"]\)/\1,\"$i\"/" "$S"/security/sandbox/linux/moz.build
