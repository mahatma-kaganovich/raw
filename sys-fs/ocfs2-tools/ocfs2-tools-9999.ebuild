# Copyright 1999-2006 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header$

EAPI=5

if [[ "${PV}" == *.9999 ]]; then
	OCFS2_BRANCH="${PN}-${PV%.9999}"
	EGIT_COMMIT="refs/remotes/origin/${OCFS2_BRANCH}"
	EGIT_FETCH_CMD="git clone --branch ${OCFS2_BRANCH}"
	EGIT_PROJECT="${OCFS2_BRANCH}.git"
	# both behaviours are wrong
	EGIT_HAS_SUBMODULES=true
fi

inherit flag-o-matic eutils `[[ "${PVR}" == *9999* ]] && echo "git-r3 autotools"`

vv="${PV%.*}"
PV_MAJOR="${PV%%.*}"
PV_MINOR="${PV#*.}"
PV_MINOR="${PV_MINOR%%.*}"
DESCRIPTION="Support programs for the Oracle Cluster Filesystem 2"
HOMEPAGE="http://oss.oracle.com/projects/ocfs2-tools/"
SRC_URI="http://oss.oracle.com/projects/ocfs2-tools/dist/files/source/v${PV_MAJOR}.${PV_MINOR}/${P}.tar.gz
	doc? ( http://oss.oracle.com/projects/ocfs2/dist/documentation/v${vv}/ocfs2-${vv//./_}-usersguide.pdf )"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~x86 ~amd64"
IUSE="X static doc pacemaker"
# (#142216) build system's broke, always requires glib for debugfs utility
RDEPEND="X? (
		=x11-libs/gtk+-2*
		>=dev-lang/python-2
		>=dev-python/pygtk-2
	)
	pacemaker? (
			sys-cluster/corosync
			sys-cluster/pacemaker
			>=sys-cluster/dlm-lib-3
			dev-libs/libxml2
		)
	>=dev-libs/glib-2.2.3
	sys-fs/e2fsprogs"
[[ "$PV" > "1.7" ]] && RDEPEND+=" dev-libs/libaio"
DEPEND="${RDEPEND}"

RESTRICT="nomirror"

if [[ "${PVR}" == *9999* ]]; then
	SRC_URI=""
	EGIT_REPO_URI="git://oss.oracle.com/git/ocfs2-tools.git"
	epatch(){ cat $*|patch -tNp1; }
else
	src_unpack(){
		for i in ${A}; do
			case ${i} in
				*.pdf)cp "${DISTDIR}/$i" "${WORKDIR}";;
				*)unpack "$i";;
			esac
		done
	}
fi

src_prepare(){
	[[ -e configure ]] || eautoreconf
	use static && sed -i -e 's:PKG_CONFIG --libs :PKG_CONFIG --static --libs :g' configure
	sed -i -e 's:\(log_error.*\)%d\(.*\), CRM_SERVICE:\1\2:' ocfs2_controld/pacemaker.c
	sed -i -e 's:umode_t:__le16:' include/ocfs2-kernel/ocfs2_fs.h
	if [[ -e ocfs2cdsl ]]; then
		export ac_config_files="ocfs2cdsl/ocfs2cdsl.8"
		sed -i -e 's:^\(SUBDIRS = .*\)$:\1 ocfs2cdsl:' Makefile
	fi
	local i
	for i in "${FILESDIR}"/${P}*.patch; do
		[[ -e "$i" ]] && epatch "$i"
	done
	sed -i -e "s:^#include <$i\\.h>:#include <sys/sysmacros.h>\n#include <$i.h>:" `grep -lR "^#include <$i\\.h>" "$S"`
}

src_configure(){
	if use pacemaker; then
		append-ldflags -Wl,--no-as-needed
		export OPTS="${CFLAGS} -I"${ROOT}"/usr/include/libxml2"
	else
		sed -i -e s:BUILD_OCFS2_CONTROLD=yes:BUILD_OCFS2_CONTROLD=no:g configure{,.in}
	fi
	econf \
		$(use_enable X ocfs2console) \
		$(use_enable !static dynamic-fsck) \
		$(use_enable !static dynamic-ctl) \
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
	use doc && dodoc "${WORKDIR}/"*.pdf

	# Move programs not needed before /usr is mounted to /usr/sbin/
	mkdir -p "${D}"/usr/sbin
	use X && mv "${D}"/sbin/ocfs2console "${D}"/usr/sbin/

	newinitd "${FILESDIR}"/ocfs2.init ocfs2
	newconfd "${FILESDIR}"/ocfs2.conf ocfs2

	insinto /etc/ocfs2
	newins "${S}"/documentation/samples/cluster.conf cluster.conf

	# vs. keepdir
#	dodir /dlm

}

pkg_postinst() {
	elog "Read ${ROOT}usr/share/doc/${P}/INSTALL.GENTOO* for instructions"
	elog "about how to install, configure and run ocfs2."
}

