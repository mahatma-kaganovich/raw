[ "$EBUILD_PHASE" = prepare -a -e "$S"/src/compat-api.h ] &&
	! grep '^#define BLOCKHANDLER_ARGS_DECL ScreenPtr arg, pointer pTimeout$' "$S"/src/compat-api.h &&
	patch -tNi /usr/ppatch/x11-drivers/1.19.patch "$S"/src/compat-api.h
true

