# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: blah (ex- /var/cvsroot/gentoo-x86/net-voip/openmcu/openmcu-2.2.1.ebuild,v 1.1 2009/02/13 05:22:23 darkside Exp $)

EAPI="2"

inherit flag-o-matic eutils
RESTRICT=nomirror

MY_PV=${PV//./_}
DESCRIPTION="Simple Multi Conference Unit using H.323"
# http://www.openh323.org/ looks dead
HOMEPAGE="http://sourceforge.net/projects/openh323/"
#SRC_URI="mirror://sourceforge/openh323/${PN}-v${MY_PV}-src.tar.gz"
SRC_URI="http://www.h323plus.org/source/download/openmcu-v${MY_PV}.tar.gz"

LICENSE="MPL-1.0"
SLOT="0"
KEYWORDS="~x86"
IUSE="debug"

DEPEND="=net-libs/h323plus-1.21.0*
	=net-libs/ptlib-2.4.5*[-ssl,-odbc]" # [ssl=]
RDEPEND="${DEPEND}"

S="${WORKDIR}/${PN}"

src_prepare() {
	append-cflags `${ROOT}/usr/bin/ptlib-config --ccflags --libs`
	sed -i -e 's:"server.pem":"/etc/openmcu/server.pem":' -e 's:"data", "data":"data", "/usr/share/openmcu/data":' -e 's:"html", "html":"html", "/usr/share/openmcu/html":' -e 's:"mcu_log.txt":"/var/log/openmcu/mcu_log.txt":' mcu.cxx
	grep -q systemLogFileName "${ROOT}"/usr/include/svcproc.h || {
		ewarn "Removing LogFileName support to compatibility with latest net-libs/ptlib"
		epatch "${FILESDIR}"/openmcu-nolog.patch
	}
}

src_compile() {
	emake OPENH323DIR="${ROOT}/usr/share/openh323" CFLAGS="${CFLAGS}" CXXFLAGS="${CXXFLAGS}" LDFLAGS="${LDFLAGS}" $(use debug&&echo debug||echo opt) || die "emake failed"
}

src_install() {
	dosbin obj_*_*_*/${PN} || die "dosbin failed"

	keepdir /usr/share/${PN}/data /usr/share/${PN}/html

	# needed for daemon
	keepdir /var/log/${PN} /var/run/${PN}

	insinto /usr/share/${PN}/sounds
	doins *.wav || die "doins wav files failed"

	insinto /etc/${PN}
	doins server.pem || die "doins server.pem failed"
	doins "${FILESDIR}"/${PN}.ini || die "doins ini file failed"

	doman ${PN}.1 || die "doman failed"

#	dodoc ChangeLog ReadMe.txt || die "dodoc failed"
	dodoc ReadMe.txt || die "dodoc failed"

	newinitd "${FILESDIR}"/${PN}.rc6 ${PN}
	newconfd "${FILESDIR}"/${PN}.confd ${PN}
}

pkg_preinst() {
	enewgroup openmcu
	enewuser openmcu -1 -1 /dev/null openmcu
}

pkg_postinst() {
	einfo "Setting permissions..."
	chown -R openmcu:openmcu "${ROOT}"etc/openmcu
	chmod -R u=rwX,g=rX,o=   "${ROOT}"etc/openmcu
	chown -R openmcu:openmcu "${ROOT}"var/{log,run}/openmcu
	chmod -R u=rwX,g=rX,o=   "${ROOT}"var/{log,run}/openmcu

	echo
	elog "This patched version of openmcu stores it's configuration"
	elog "in \"/etc/openmcu/openmcu.ini\""
}
