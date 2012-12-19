_dirtyaufs3(){
	[ -e "$1" ] || return 1
	elog "AuFS3 trying dirty $1"
	local i f=
	while read i; do
		case "$i" in
		---\ *);;
		+++\ *)
			f="$S/${i#+++ ?/}"
			echo "
/* AuFS3 */" >>"$f" || return 1
		;;
		+*)
			i="${i#+}"
			grep -qF "$i" "$f" || echo "$i" >>"$f" || return 1
		;;
		-*)
			return 1
		;;
		esac
	done <"$1"
}

_tryaufs3(){
	[ -e "$1" ] || return 1
	elog "AuFS3 patch: $1 (-p1)"
	(patch --dry-run -RNsp1 -d "$S" -i "$1" >/dev/null 2>&1 && echo " - alredy applyed") ||
	(patch -Ntsp1 -d "$S" -i "$1" --dry-run && patch -Ntsp1 -d "$S" -i "$1" >/dev/null 2>&2 )
}

for i in "$PORTDIR"/sys-fs/aufs3/files/aufs3-{base,standalone}; do
	_tryaufs3 "$i-$KV_MINOR.patch" || _tryaufs3 "$i-x-rcN.patch" || _dirtyaufs3 "$i-x-rcN.patch" || die "AuFS3 patch failed!"
done
