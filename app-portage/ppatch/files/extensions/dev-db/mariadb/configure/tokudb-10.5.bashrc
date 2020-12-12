[ -e "$S/storage/tokudb" ] && [[ "$IUSE" != *tokudb* ]] && use extraengine && {
einfo "Configure TokuDB"
grep -q '^PLUGIN_TOKUDB:STRING=DYNAMIC' "$BUILD_DIR/CMakeCache.txt" ||
	echo PLUGIN_TOKUDB:STRING=DYNAMIC >>"$BUILD_DIR/CMakeCache.txt"
}


