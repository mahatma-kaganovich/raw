# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: blah (ex- /var/cvsroot/gentoo-x86/net-voip/openmcu/openmcu-2.2.1.ebuild,v 1.1 2009/02/13 05:22:23 darkside Exp $)

EAPI="2"

MY_P=h323plus-app-v1_23_0

cvs=""
ECVS_MODULE=""
case "${PVR}" in
9999*)
	cvs=cvs
	ECVS_SERVER="h323plus.cvs.sourceforge.net:/cvsroot/h323plus"
	ECVS_MODULE="applications/openmcu"
	ECVS_USER="anonymous"
	ECVS_PASS=""
;;
*)
	SRC_URI="http://www.h323plus.org/source/download/${MY_P}.tar.gz"
;;
esac

inherit flag-o-matic eutils $cvs

DESCRIPTION="Simple Multi Conference Unit using H.323"
HOMEPAGE="http://www.h323plus.org/"
LICENSE="MPL-1.0"
SLOT="0"
KEYWORDS="~x86 ~amd64"
IUSE="debug ssl"
DEPEND="net-libs/h323plus[debug=]
	net-libs/ptlib[http,ssl?,debug=]"
RDEPEND="${DEPEND}"
S="${WORKDIR}/${ECVS_MODULE:-${MY_P}/${PN}}"

src_prepare() {
	append-cflags `${ROOT}/usr/bin/ptlib-config --ccflags --libs` -DP_SSL=$(use ssl && echo 1 || echo 0)
	ebegin "Fixing pathes"
	sed -i -e 's:"server.pem":"/etc/openmcu/server.pem":' -e 's:"data", "data":"data", "/usr/share/openmcu/data":' -e 's:"html", "html":"html", "/usr/share/openmcu/html":' -e 's:"mcu_log.txt":"/var/log/openmcu/mcu_log.txt":' mcu.cxx
	eend $?
	local i
	for i in "${FILESDIR}"/${PN}-${PVR}-*.patch; do
		[[ -e "$i" ]] && epatch "$i"
	done
}

src_compile() {
	emake OPENH323DIR="${ROOT}/usr/share/openh323" CFLAGS="${CFLAGS}" CXXFLAGS="${CXXFLAGS}" LDFLAGS="${LDFLAGS}" CPPFLAGS="${CPPFLAGS}" $(use debug&&echo debug||echo opt) || die "emake failed"
}

src_install() {
	dosbin obj_*/${PN} || die

	keepdir /usr/share/${PN}/data /usr/share/${PN}/html

	# needed for daemon
	keepdir /var/log/${PN} /var/run/${PN}

	insinto /usr/share/${PN}/sounds
	doins *.wav || die

	insinto /etc/${PN}
	doins server.pem || die "doins server.pem failed"
	doins "${FILESDIR}"/${PN}.ini || die "doins ini file failed"

	doman ${PN}.1 || die
	dodoc ReadMe.txt || die

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
