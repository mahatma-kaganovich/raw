[[ "$EBUILD_PHASE" = prepare && " $IUSE " != *' gold '* ]] && sed -i -e 's:^CFG_USE_GOLD_LINKER=auto$:CFG_USE_GOLD_LINKER=no:' "${WORKDIR}"/*/configure
