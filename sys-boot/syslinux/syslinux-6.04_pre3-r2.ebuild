# Copyright 1999-2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=5

inherit eutils toolchain-funcs

DESCRIPTION="SYSLINUX, PXELINUX, ISOLINUX, EXTLINUX and MEMDISK bootloaders"
HOMEPAGE="https://www.syslinux.org/"
# Final releases in 6.xx/$PV.tar.* (literal "xx")
# Testing releases in Testing/$PV/$PV.tar.*
SRC_URI_DIR=${PV:0:1}.xx
SRC_URI_TESTING=Testing/${PV:0:4}
[[ ${PV/_alpha} != $PV ]] && SRC_URI_DIR=$SRC_URI_TESTING
[[ ${PV/_beta} != $PV ]] && SRC_URI_DIR=$SRC_URI_TESTING
[[ ${PV/_pre} != $PV ]] && SRC_URI_DIR=$SRC_URI_TESTING
[[ ${PV/_rc} != $PV ]] && SRC_URI_DIR=$SRC_URI_TESTING
SRC_URI="https://www.zytor.com/pub/${PN}/${SRC_URI_DIR}/${P/_/-}.tar.xz
	mirror://kernel/linux/utils/boot/${PN}/${SRC_URI_DIR}/${P/_/-}.tar.xz
	http://cdn-fastly.deb.debian.org/debian/pool/main/s/syslinux/syslinux_6.04~git20190206.bf6db5b4+dfsg1-1~bpo9+2.debian.tar.xz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="-* amd64 x86"
IUSE="custom-cflags"

RDEPEND="sys-fs/mtools
		dev-perl/Crypt-PasswdMD5
		dev-perl/Digest-SHA1"
DEPEND="${RDEPEND}
	app-arch/upx-ucl
	dev-lang/nasm
	>=sys-boot/gnu-efi-3.0u
	virtual/os-headers"

S=${WORKDIR}/${P/_/-}

# These are executables which come precompiled and are run by the boot loader
QA_PREBUILT="usr/share/${PN}/*.c32"

# removed all the unpack/patching stuff since we aren't rebuilding the core stuff anymore

src_prepare() {
	rm -f gethostip #bug 137081

	# loose HPA support!
	rm bios efi32 efi64 -Rf
	epatch "${WORKDIR}"/debian/patches/{0005,0016,0017,0018}-*.patch
	sed -i -e 's:-malign-:-falign-:' mk/*.mk
	sed -i -e 's:$(call gcc_ok,-m64,*):-m64 -fPIC:' -e 's: -m64$: -m64 -march=x86-64:' mk/*.mk gnu-efi/Make.defaults

	# Don't prestrip or override user LDFLAGS, bug #305783
	local SYSLINUX_MAKEFILES="extlinux/Makefile linux/Makefile mtools/Makefile \
		sample/Makefile utils/Makefile"
	sed -i ${SYSLINUX_MAKEFILES} -e '/^LDFLAGS/d' || die "sed failed"

	if use custom-cflags; then
		sed -i ${SYSLINUX_MAKEFILES} \
			-e 's|-g -Os||g' \
			-e 's|-Os||g' \
			-e 's|CFLAGS[[:space:]]\+=|CFLAGS +=|g' \
			|| die "sed custom-cflags failed"
	else
		QA_FLAGS_IGNORED="
			/sbin/extlinux
			/usr/bin/memdiskfind
			/usr/bin/gethostip
			/usr/bin/isohybrid
			/usr/bin/syslinux
			"
	fi

	# building with ld.gold causes problems, bug #563364
	if tc-ld-is-gold; then
		ewarn "Building syslinux with the gold linker may cause problems, see bug #563364"
		if [[ -z "${I_KNOW_WHAT_I_AM_DOING}" ]]; then
			tc-ld-disable-gold
			ewarn "set I_KNOW_WHAT_I_AM_DOING=1 to override this."
		else
			ewarn "Continuing anyway as requested."
		fi
	fi

	epatch_user
}

# keep variables identical everywere
_make(){
	# build system abuses the LDFLAGS variable to pass arguments to ld
	unset LDFLAGS
	emake CC="$(tc-getCC)" LD="$(tc-getLD)" LD="$(tc-getLD)" INSTALLROOT="${D}" MANDIR=/usr/share/man "${@}" # UPX=false
}

src_compile() {
	_make
}

src_install() {
	# parallel install fails sometimes
	_make -j1 install
	dodoc README NEWS doc/*.txt
}

pkg_postinst() {
	# print warning for users upgrading from the previous stable version
	if has 4.07 ${REPLACING_VERSIONS}; then
		ewarn "syslinux now uses dynamically linked ELF executables. Before you reboot,"
		ewarn "ensure that needed dependencies are fulfilled. For example, run from your"
		ewarn "syslinux directory:"
		ewarn
		ewarn "LD_LIBRARY_PATH=\".\" ldd menu.c32"
	fi
}
