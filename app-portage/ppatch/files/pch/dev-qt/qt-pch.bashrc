[[ "$EBUILD_PHASE" == prepare && " $IUSE " != *' pch '* ]] && sed -i -e 's:CFG_PRECOMPILE=no:CFG_PRECOMPILE=yes:' -e 's:CFG_PRECOMPILE="$VAL":CFG_PRECOMPILE=yes:' "${WORKDIR}"/*/configure
