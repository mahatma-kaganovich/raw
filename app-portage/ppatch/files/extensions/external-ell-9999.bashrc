
# force dev-libs/ell-9999 true external

# [temporary] disabled
false &&
[ "$EBUILD_PHASE" = prepare ] &&
[ "${CBUILD:-${CHOST}}" = "${CHOST}" ] &&
([ -e "$S/ell/useful.h" -o -e "$WORKDIR/ell/ell/useful.h" ] || grep -sqw EXTERNAL_ELL "$S"/Makefile* || grep -sqw enable_external_ell "$S"/configure*) &&
if [ "$PN" = ell ]; then
	[[ "$PV" == *9999* ]] && sed -i -e 's:^\(pkginclude_HEADERS = \):\1 ell/useful.h '" $(cd "$S" && echo ell/*-private.h) :" "$S"/Makefile*
elif [ -e /usr/include/ell/useful.h ]; then
		rm "$WORKDIR/ell" "$S/ell" -Rf
		cp -a /usr/include/ell "$S/"
		export enable_external_ell=yes
fi
