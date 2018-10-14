[[ "$EBUILD_PHASE" == prepare && " $IUSE " != *' gold '* ]] && {
	# 5.7
	sed -i -e 's:^CFG_USE_GOLD_LINKER=auto$:CFG_USE_GOLD_LINKER=no:' "${WORKDIR}"/*/configure
	# 5.9
	for i in -Wl,--sort-section=alignment -Wl,--reduce-memory-overheads; do
	[[ "$LDFLAGS" == *"$i"* ]] && {
		sed -i -e  's:-fuse-ld=gold:& $i:' "${WORKDIR}"/*/configure.json
		sed -i -e  's: -fuse-ld=gold: :' "${WORKDIR}"/*/Source/cmake/OptionsCommon.cmake
	}
	done
}
