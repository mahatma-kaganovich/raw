_trypatch(){
	[ -e "$1" ] || return 1
	elog "AuFS3 patch: $1 (-p1)"
	(patch --dry-run -RNsp1 -d "$S" -i "$1" >/dev/null 2>&1 && echo " - alredy applyed") ||
	(patch -Ntsp1 -d "$S" -i "$1" --dry-run && patch -Ntsp1 -d "$S" -i "$1" >/dev/null 2>&2 )
}

for i in "$PORTDIR"/sys-fs/aufs3/files/aufs3-{base,standalone}; do
	_trypatch "$i-$KV_MINOR.patch" || _trypatch "$i-x-rcN.patch" || die "AuFS3 patch failed!"
done
