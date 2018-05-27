	[[ "$CFLAGS_BASE" == *-fomit-frame-pointer* && "$CFLAGS_BASE" != *-fno-omit-frame-pointer* ]] && CFLAGS_BASE+=' -D__USE_STRING_INLINES'
	export CFLAGS_BASE
	append-flags -DNDEBUG=1
