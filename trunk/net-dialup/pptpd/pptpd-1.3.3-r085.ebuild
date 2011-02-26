# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

# only server, minimally from gentoo's main

inherit eutils autotools flag-o-matic linux-info

MY_P=accel-pptp-0.8.5
EAPI="3"
DESCRIPTION="Linux Point-to-Point Tunnelling Protocol Server, accelerated"
SRC_URI="mirror://sourceforge/accel-pptp/${MY_P}.tar.bz2"
HOMEPAGE="http://accel-pptp.sourceforge.net/"

SLOT="0"
LICENSE="GPL-2"
KEYWORDS="alpha ~amd64 ~hppa ~ia64 ~ppc ~ppc64 ~sparc x86"
IUSE="tcpd gre-extreme-debug"

DEPEND="net-dialup/ppp
	tcpd? ( sys-apps/tcp-wrappers )"
RDEPEND="${DEPEND}"
S="${WORKDIR}/${MY_P}/${P}"

CONFIG_CHECK="PPTP"

src_prepare() {
	epatch "${FILESDIR}/${PN}-flags.patch"

	#Match pptpd-logwtmp.so's version with pppd's version (#89895)
	#obsoleted?
	local PPPD_VER=`best_version net-dialup/ppp`
	PPPD_VER=${PPPD_VER#*/*-} #reduce it to ${PV}-${PR}
	PPPD_VER=${PPPD_VER%%[_-]*} # main version without beta/pre/patch/revision
	sed -i -e "s:\\(#define[ \\t]*VERSION[ \\t]*\\)\".*\":\\1\"${PPPD_VER}\":" plugins/patchlevel.h pptpd.spec

	eautoreconf
}

src_configure(){
	use gre-extreme-debug && append-flags "-DLOG_DEBUG_GRE_ACCEPTING_PACKET"
	econf --enable-bcrelay $(use tcpd && echo --with-libwrap)
}

src_install () {
	einstall || die "make install failed"

	insinto /etc
	doins "${S}"/../example/etc/pptpd.conf

	insinto /etc/ppp
	doins "${S}"/../example/etc/ppp/options.pptp{,d}

	local i="${S}/../gentoo/net-dialup/accel-pptp/files"
	newinitd "$i/pptpd-init" pptpd
	newconfd "$i/pptpd-confd" pptpd

	dodoc AUTHORS ChangeLog NEWS README* TODO
	docinto samples
	dodoc samples/*
}
