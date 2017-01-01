[ "$EBUILD_PHASE" = prepare ] && [[ "$CFLAGS$CFLAGS_BASE" == *-floop-* ]] && {
	i=`grep -lFRw exchange "$S" --include getopt.c` && sed -i '1i #pragma GCC optimize ("no-loop-nest-optimize")\n#pragma GCC optimize ("no-graphite-identity")' $i
	sed -i '1i #if defined(__i386__)\n#pragma GCC optimize ("no-loop-nest-optimize")\n#pragma GCC optimize ("no-graphite-identity")\n#endif' "$S"/src/cmspack.c 2>/dev/null
	true	
}