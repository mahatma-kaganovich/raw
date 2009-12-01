# Copyright 1999-2006 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header$

inherit eutils

PV_MAJOR="${PV%%.*}"
PV_MINOR="${PV#*.}"
PV_MINOR="${PV_MINOR%%.*}"
DESCRIPTION="Support programs for the Oracle Cluster Filesystem 2"
HOMEPAGE="http://oss.oracle.com/projects/ocfs2-tools/"
SRC_URI="http://oss.oracle.com/projects/ocfs2-tools/dist/files/source/v${PV_MAJOR}.${PV_MINOR}/${P}.tar.gz"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~x86 ~amd64"
IUSE="X"
# (#142216) build system's broke, always requires glib for debugfs utility
RDEPEND="X? (
		=x11-libs/gtk+-2*
		>=dev-lang/python-2
		>=dev-python/pygtk-2
	)
	>=dev-libs/glib-2.2.3
	sys-fs/e2fsprogs"
DEPEND="${RDEPEND}"

RESTRICT="nomirror"

src_compile() {
	local myconf="--enable-dynamic-fsck --enable-dynamic-ctl"

	econf --prefix=/ \
		$(use_enable X ocfs2console) \
		${myconf} \
		|| die "Failed to configure"

	emake -j1 || die "Failed to compile"
}

src_install() {
	make DESTDIR="${D}" install || die "Failed to install"

	dodoc \
		COPYING CREDITS MAINTAINERS README README.O2CB debugfs.ocfs2/README \
		documentation/users_guide.txt documentation/samples/cluster.conf \
		documentation/ocfs2_faq.txt "${FILESDIR}"/INSTALL.GENTOO \
		vendor/common/o2cb.init vendor/common/o2cb.sysconfig

	# Move programs not needed before /usr is mounted to /usr/sbin/
	mkdir -p "${D}"/usr/sbin
	mv "${D}"/sbin/ocfs2cdsl "${D}"/usr/sbin/
	if use X; then
		mv "${D}"/sbin/ocfs2console "${D}"/usr/sbin/
	fi

	newinitd "${FILESDIR}"/ocfs2.init ocfs2
	newconfd "${FILESDIR}"/ocfs2.conf ocfs2

	insinto /etc/ocfs2
	newins "${S}"/documentation/samples/cluster.conf cluster.conf

	# vs. keepdir
	dodir /dlm

	# FIXME - fix the python lib.
	# pythonians wouldn't like this probably, but I couldn't find better
	# solution.
	mv "${D}"/$(get_libdir) "${D}"/usr
	mv "${D}"/include "${D}"/usr
}

pkg_postinst() {
	elog "Read ${ROOT}usr/share/doc/${P}/INSTALL.GENTOO* for instructions"
	elog "about how to install, configure and run ocfs2."
}

