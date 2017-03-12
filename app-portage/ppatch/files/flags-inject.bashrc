[ "$EBUILD_PHASE" = prepare ] && {

# memo: pragma GCC ignored in C++

_in_ject(){
	[[ "$CFLAGS$CFLAGS_BASE" == *"$1"* ]] || return 1
	shift
	local f n ok=false c="$1" i
	[[ "$c" == *'#'* ]] || {
			c=
			for i in $1; do
				c+='\n#pragma GCC optimize ("'"$i"'")'
			done
			c="${c#??}"
	}
	shift
	for n in "${@}"; do
		for f in `find "${WORKDIR}" -name "${n##*/}"`; do
			[[ "$f" == *"$n" ]] && sed -i "1i $c" "$f" && ok=true
		done
	done
	$ok
}

# mozilla include header into C++, pragma is ignored, 2 workaround
_in_ject fast '#pragma GCC optimize ("no-fast-math")\n#ifdef __FAST_MATH__\n#define FLOAT_APPROX\n#endif' celt/arch.h

[[ "$IUSE" == *system-sqlite* ]] && _in_ject fast no-fast-math sqlite3.c

_in_ject -fschedule-insns no-schedule-insns libttf/cmap.c netxen_nic_hw.c qlcnic_hw.c gf100.c src/css.c

_in_ject -floop- 'no-loop-nest-optimize no-graphite-identity' getopt.c Objects/obmalloc.c libopenjpeg/tcd.c nellymoser.c
_in_ject -floop- '#if defined(__i386__)\n#pragma GCC optimize ("no-loop-nest-optimize")\n#pragma GCC optimize ("no-graphite-identity")\n#endif' src/cmspack.c libdw/dwarf_frame_register.c libmp3lame/quantize.c libtwolame/twolame.c src/secaudit.c

}
