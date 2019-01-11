[[ ${ABI} == amd64 ]] && use gallium && use llvm &&
meson(){
	rm -f "$S/src/gallium/drivers/swr/rasterizer/jitter/gen_builder.hpp"
#	sed -i -e 's:// assume non-Windows is always 64-bit:\&\& !defined(__i386__):' "$S"/src/gallium/drivers/swr/rasterizer/common/simdlib.hpp # || die
	[[ "$*" != *Dswr-arches=* ]] && set -- "${@//Dgallium-drivers=/Dgallium-drivers=swr,}" -Dswr-arches=knl,skx,avx2,avx
	/usr/bin/meson "${@}"
}
