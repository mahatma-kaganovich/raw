# Copyright 1999-2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI="6"

# dev-libs/klibc ebuild broken, but anymore klibc hard depends
# from kernel sources, so we need just install sources

DESCRIPTION="A minimal libc subset for use with initramfs. Sources only."
HOMEPAGE="https://www.zytor.com/mailman/listinfo/klibc/ https://www.kernel.org/pub/linux/libs/klibc/"
SRC_URI="https://www.kernel.org/pub/linux/libs/klibc/${PV:0:3}/${P/-sources-/-}.tar.xz"
KEYWORDS="~alpha amd64 ~arm ~arm64 ~hppa ia64 -mips ~ppc ~ppc64 ~riscv ~s390 ~sh ~sparc x86"
LICENSE="|| ( GPL-2 LGPL-2 )"
SLOT="0"

S="${WORKDIR}"

src_unpack(){
	cd "$DISTDIR" &&
	cp $A "$S" &&
	cd "$S" || die
}

src_install(){
	local d=/usr/share/klibc
	dodir $d
	mv "$S"/* "$D/$d/" || die
}
