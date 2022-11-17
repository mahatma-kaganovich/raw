[ "$EBUILD_PHASE" = prepare ] && (

# memo: pragma GCC ignored in C++

inj(){
	[[ "$CFLAGS$CFLAGS_BASE" == *"$2"* ]] || return 1
	local n c="$1" i
	[[ "$c" == *'#'* ]] || {
			c=
			for i in $1; do
				c+='\n#pragma GCC optimize ("'"$i"'")'
			done
			c="${c#??}"
	}
	sed -i "1i $c" "$f" && einfo "flags-inject: $PN ${f#$WORKDIR/}"
}

cv=`LANG=C gcc -dumpversion`
: ${cv:=0}

find "${WORKDIR}"|while read f; do case "$f" in
# mozilla include header into C++, pragma is ignored, 2 workaround
*celt/arch.h)
	inj '#pragma GCC optimize ("no-fast-math")\n#ifdef __FAST_MATH__\n#define FLOAT_APPROX\n#endif' fast
;;
*/sqlite3.c)
	[[ "$IUSE" == *system-sqlite* ]] && inj no-fast-math fast
;;
*libttf/cmap.c|*/netxen_nic_hw.c|*/qlcnic_hw.c|*/gf100.c|*src/css.c|*/*/Frontend/CompilerInvocation.cpp)
	[[ $cv == 7.* ]] && inj no-schedule-insns -fschedule-insns
;;
# gcc 7?
*vp8/encoder/encodemv.c|*v8/src/code-stub-assembler.cc)
	[[ $cv == 7.* ]] && inj '#if defined(__i386__)\n#pragma GCC optimize ("no-schedule-insns")\n#endif' -fschedule-insns
;;
*/getopt.c|*Objects/obmalloc.c|*libopenjpeg/tcd.c|*/nellymoser.c|*/libfreerdp/codec/nsc_encode.c|*/r819xU_cmdpkt.c|*/sharedbook.c|*/openjp2/dwt.c)
	[[ $cv == 7.* ]] && inj 'no-loop-nest-optimize no-graphite-identity' -floop-
;;
*src/cmspack.c|*libdw/dwarf_frame_register.c|*libmp3lame/quantize.c|*libtwolame/twolame.c|*src/secaudit.c)
	[[ $cv == 7.* ]] && inj '#if defined(__i386__)\n#pragma GCC optimize ("no-loop-nest-optimize")\n#pragma GCC optimize ("no-graphite-identity")\n#endif' -floop-
;;
# gcc 7 ICE
*src/osd/ECBackend.cc|*src/osd/OSD.cc|*src/osd/Watch.cc)
	[[ $cv == 7.* ]] && inj no-devirtualize
;;
# gcc 7.2 python 3.6.1
*/cmathmodule.c)
	[[ $cv == 7.* ]] && inj '#if defined(__i386__)\n#pragma GCC target ("no-sse2")\n#endif'
;;
# mozilla,chromuim [gcc 8] ICE [x86]
#*profiler/core/shared-libraries-linux.cc|
*seccomp-bpf/syscall.cc|*common/linux/file_id.cc|bits/vector.tcc)
	# ??
	[[ $cv == [89].* ]] && use amd64 || inj no-tree-vectorize
;;
# gcc 12: -fno-trapping-math --param={ipa-cp,inline}-unit-growth=0
*/minilua.c)
#	inj trapping-math fast
	inj no-fast-math fast
;;
esac
done

)
