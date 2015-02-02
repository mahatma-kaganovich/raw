# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

# only server, minimally from gentoo's main

EAPI="5"
inherit eutils autotools flag-o-matic

MY_P=accel-pptp-0.8.5
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
S="${WORKDIR}/${MY_P}"

CONFIG_CHECK="PPTP"

src_prepare() {
	epatch "${FILESDIR}/${PN}"-*.patch

	#Match pptpd-logwtmp.so's version with pppd's version (#89895)
	#obsoleted?
	PPPD=`best_version net-dialup/ppp`
	PPPD=${PPPD#*/*-} #reduce it to ${PV}-${PR}
	export PPPD=${PPPD%%[_-]*} # main version without beta/pre/patch/revision
	sed -i -e 's: module : :g' -e 's: module_install : :g' -e 's: /usr/: $(D)/usr/:' Makefile
	echo 'plugin "pptp.so"' | tee -a {example/etc/ppp,gentoo/net-dialup/accel-pptp/files}/options.pptp* >/dev/null
	cd pptpd-1.3.3 || die
	sed -i -e "s:\\(#define[ \\t]*VERSION[ \\t]*\\)\".*\":\\1\"${PPPD}\":" pptpd.spec

	eautoreconf
	cd "${S}"/pppd_plugin || die
	eautoreconf
}

src_configure(){
	export KDIR=/usr
	use gre-extreme-debug && append-flags "-DLOG_DEBUG_GRE_ACCEPTING_PACKET"
	cd "${S}"/pptpd-1.3.3 && econf --enable-bcrelay $(use tcpd && echo --with-libwrap)
	cd "${S}"/pppd_plugin && econf
}

src_install () {
	cd "${S}"/pptpd-1.3.3 && einstall || die "make install failed"

	insinto "/usr/$(get_libdir)/pppd/${PPPD}"
	newins "${S}"/pppd_plugin/src/.libs/pptp.so.0.0.0 pptp.so

	insinto /etc
	doins "${S}"/example/etc/pptpd.conf

	local i="${S}/gentoo/net-dialup/accel-pptp/files"

	insinto /etc/ppp
	doins "${S}"/example/etc/ppp/options.pptp{,d}

	newinitd "$i/pptpd-init" pptpd
	newconfd "$i/pptpd-confd" pptpd

	dodoc AUTHORS ChangeLog NEWS README* TODO
	docinto samples
	dodoc samples/*
}
