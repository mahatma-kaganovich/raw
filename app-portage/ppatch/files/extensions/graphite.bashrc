[ "$EBUILD_PHASE" = prepare -a -z "${CFLAGS##*-floop-*}" ] && {
	i=`grep -lFRw exchange "$S" --include getopt.c` && sed -i '1i #pragma GCC optimize ("no-loop-nest-optimize")\n#pragma GCC optimize ("no-graphite-identity")' $i
}
