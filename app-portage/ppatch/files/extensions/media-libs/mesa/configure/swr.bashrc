[[ "$IUSE" == *gallium* ]] &&
[[ ${ABI} == amd64 ]] && use gallium && use llvm &&
meson(){
	rm -f "$S/src/gallium/drivers/swr/rasterizer/jitter/gen_builder.hpp"
#	sed -i -e 's:// assume non-Windows is always 64-bit:\&\& !defined(__i386__):' "$S"/src/gallium/drivers/swr/rasterizer/common/simdlib.hpp # || die

	[[ "$*" != *Dswr-arches=* ]] && {
		#set -- "${@//Dgallium-drivers=/Dgallium-drivers=swr,}" -Dswr-arches=knl,skx,avx2,avx

		# https://bugs.freedesktop.org/show_bug.cgi?id=109023
		# build only actual arches while
		for i in knl skx avx2 avx; do
			case $i in
			knl)f=AVX512F;;
			skx)f=AVX512BW;;
			*)f=${i^^};;
			esac
			echo "#ifndef __${f}__
#error
#endif"|$(tc-getCPP) - -o /dev/null ${CFLAGS} 2>/dev/null || continue
			echo "detected $f -> $i"
			swr+=,$i
			#break
		done
		swr=${swr#,}
		[ -n "$swr" ] && set -- "${@//Dgallium-drivers=/Dgallium-drivers=swr,}" -Dswr-arches=${swr#,}
	}

	/usr/bin/meson "${@}"
}
