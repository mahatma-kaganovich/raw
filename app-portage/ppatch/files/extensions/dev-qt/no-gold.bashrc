[[ "$EBUILD_PHASE" == prepare && " $IUSE " != *' gold '* ]] && {
	# 5.7
	sed -i -e 's:^CFG_USE_GOLD_LINKER=auto$:CFG_USE_GOLD_LINKER=no:' "${WORKDIR}"/*/configure
	# 5.9
	[[ "$LDFLAGS" == *"-Wl,--sort-section=alignment"* ]] && sed -i -e  's:-fuse-ld=gold:& -Wl,--sort-section=alignment:' "${WORKDIR}"/*/configure.json
}
