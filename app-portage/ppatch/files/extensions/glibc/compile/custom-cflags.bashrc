use debug || {
	export CFLAGS_BASE
	append-flags -DNDEBUG=1
}
