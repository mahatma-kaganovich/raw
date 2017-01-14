[ "$EBUILD_PHASE" = prepare ] && {

_in_ject(){
	local f n ok=false c="$1"
	shift
	for n in "${@}"; do
		for f in `find "${WORKDIR}" -name "${n##*/}"`; do
			[[ "$f" == *"$n" ]] && sed -i "1i $c" "$f" && ok=true
		done
	done
	$ok
}

[[ "$IUSE" == *system-sqlite* ]] && {
#	_in_ject '#ifdef __FAST_MATH__\n#pragma GCC optimize ("no-fast-math")\n#undef __FAST_MATH__\n#endif' sqlite3.c celt/arch.h
	_in_ject '#ifdef __FAST_MATH__\n#pragma GCC optimize ("no-fast-math")\n#endif' sqlite3.c celt/arch.h
}

}
