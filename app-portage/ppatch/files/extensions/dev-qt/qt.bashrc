[ "$EBUILD_PHASE" = prepare ] && {
	[ "${IUSE//qt3support}" = "$IUSE" ] && has_version dev-qt/qtcore:$SLOT[-qt3support] && sed -i -e 's:^CFG_QT3SUPPORT=yes$:CFG_QT3SUPPORT=no:' "${S}/configure"
	cf=`c++ $CXXFLAGS --help=target -v 2>&1`
	for i in mmx 3dnow sse sse2 sse3 ssse3 sse4_1 sse4_2 avx iwmmxt; do
		[ -z "${cf##* -mno-$i *}" -a -n "${cf##* -mno-$i *-m$i *}" ] && sed -i -e "s/^CFG_${i^^}=auto$/CFG_${i^^}=no/" "${S}/configure"
	done
#	[ "$PN" = qtwebkit ] && export QMAKE_CXXFLAGS="-DENABLE_WEBGL=1 -DENABLE_WCSS=1 -DENABLE_ANIMATION_API=1"
}
