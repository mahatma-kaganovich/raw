# Copyright 1999-2006 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header$

if [[ "${PV}" == *.9999 ]]; then
	OCFS2_BRANCH="${PN}-${PV%.9999}"
	EGIT_COMMIT="refs/remotes/origin/${OCFS2_BRANCH}"
	EGIT_FETCH_CMD="git clone --branch ${OCFS2_BRANCH}"
	EGIT_PROJECT="${OCFS2_BRANCH}"
	# both behaviours are wrong
	EGIT_HAS_SUBMODULES=true
fi

inherit eutils `[[ "${PVR}" == *9999* ]] && echo "git autotools"`

EAPI=3

PV_MAJOR="${PV%%.*}"
PV_MINOR="${PV#*.}"
PV_MINOR="${PV_MINOR%%.*}"
DESCRIPTION="Support programs for the Oracle Cluster Filesystem 2"
HOMEPAGE="http://oss.oracle.com/projects/ocfs2-tools/"
SRC_URI="http://oss.oracle.com/projects/ocfs2-tools/dist/files/source/v${PV_MAJOR}.${PV_MINOR}/${P}.tar.gz"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~x86 ~amd64"
IUSE="X static"
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

if [[ "${PVR}" == *9999* ]]; then
	SRC_URI=""
	EGIT_REPO_URI="git://oss.oracle.com/git/ocfs2-tools.git"
	epatch(){ cat $*|patch -tNp1; }
fi

src_prepare(){
	[[ -e configure ]] || eautoreconf
	use static && sed -i -e 's:PKG_CONFIG --libs :PKG_CONFIG --static --libs :g' configure
	if [[ -e ocfs2cdsl ]]; then
		export ac_config_files="ocfs2cdsl/ocfs2cdsl.8"
		sed -i -e 's:^\(SUBDIRS = .*\)$:\1 ocfs2cdsl:' Makefile
	fi
	epatch "${FILESDIR}"/*.patch
}

src_configure(){
	econf \
		$(use_enable X ocfs2console) \
		$(use_enable !static dynamic-fsck) \
		$(use_enable !static dynamic-ctl) \
		${myconf} \
		|| die "Failed to configure"
}

src_compile() {
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
	use X && mv "${D}"/sbin/ocfs2console "${D}"/usr/sbin/

	newinitd "${FILESDIR}"/ocfs2.init ocfs2
	newconfd "${FILESDIR}"/ocfs2.conf ocfs2

	insinto /etc/ocfs2
	newins "${S}"/documentation/samples/cluster.conf cluster.conf

	# vs. keepdir
	dodir /dlm

}

pkg_postinst() {
	elog "Read ${ROOT}usr/share/doc/${P}/INSTALL.GENTOO* for instructions"
	elog "about how to install, configure and run ocfs2."
}

