[ "$EBUILD_PHASE" = prepare ] && [[ "$CFLAGS$CFLAGS_BASE" == *-floop-* ]] && {
	sed -i '1i #pragma GCC optimize ("no-loop-nest-optimize")\n#pragma GCC optimize ("no-graphite-identity")' `grep -lFRw exchange "$S" --include getopt.c` "${WORKDIR}"/{Python-*/Objects/obmalloc.c,openjpeg-*/libopenjpeg/tcd.c}
	sed -i '1i #if defined(__i386__)\n#pragma GCC optimize ("no-loop-nest-optimize")\n#pragma GCC optimize ("no-graphite-identity")\n#endif' "$S"/{src/cmspack.c,libdw/dwarf_frame_register.c,libmp3lame/quantize.c,libtwolame/twolame.c,libavcodec/nellymoser}
	true
} 2>/dev/null
