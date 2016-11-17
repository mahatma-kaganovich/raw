[ "$EBUILD_PHASE" = prepare -a -e "$S"/src/compat-api.h ] &&
	! grep -Fqs 'SET_ABI_VERSION(23, 0)' "$S"/src/compat-api.h &&
	sed -i -e 's:^\(#define.*\)\(, pointer pReadmask\|, pReadmask\|, pointer read_mask\|, read_mask\)$:#if ABI_VIDEODRV_VERSION >= SET_ABI_VERSION(23, 0)\n\1\n#else\n\1\2\n#endif:' "$S"/src/compat-api.h
true
