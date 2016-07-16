# too devel
ETYPE="headers"
H_SUPPORTEDARCH="alpha amd64 arm cris hppa m68k mips ia64 ppc ppc64 s390 sh sparc x86"
inherit kernel-2
KEYWORDS="-* raw"
SYMLINK=true

src_unpack() {
	$SYMLINK && return
	cp /usr/src/linux "${S}" -LRp
}

src_test() {
	$SYMLINK && return
	emake -j1 ARCH=$(tc-arch-kernel) headers_check || die
}

pkg_preinst() {
	$SYMLINK || return
	rm /usr/include/{asm,linux} -Rf
}

built(){
	local e="${ROOT}/var/db/pkg/$1-*"
	[[ "`echo $e`" == "$e" ]] && return 0
	return 1
}

src_install() {
	$SYMLINK || return
	mkdir ${D}/usr/include --parents
	local d="../src/linux"
	dosym "${d}"/include/asm-generic /usr/include/asm-generic
#	built "x11-libs/libdrm" && dosym "${d}"/include/drm /usr/include/drm
	dosym "${d}"/include/linux /usr/include/linux
	dosym "${d}"/include/mtd /usr/include/mtd
	dosym "${d}"/include/rdma /usr/include/rdma
#	built "media-sound/alsa-headers" && dosym "${d}"/include/sound /usr/include/sound
	dosym "${d}"/include/video /usr/include/video
	dosym "${d}"/arch/x86/include/asm  /usr/include/asm
}
