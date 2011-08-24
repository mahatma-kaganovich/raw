# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: blah (ex- /var/cvsroot/gentoo-x86/net-voip/openmcu/openmcu-2.2.1.ebuild,v 1.1 2009/02/13 05:22:23 darkside Exp $)

EAPI="2"

cvs=""
ECVS_MODULE=""
case "${PVR}" in
9999*)
	cvs=cvs
	ECVS_SERVER="h323plus.cvs.sourceforge.net:/cvsroot/h323plus"
	ECVS_MODULE="applications"
	ECVS_USER="anonymous"
	ECVS_PASS=""
;;
*)
	SRC_URI="http://www.h323plus.org/source/download/${PN}-v${PV//./_}.tar.gz"
;;
esac

inherit flag-o-matic eutils $cvs

DESCRIPTION="H.323 plus applications"
HOMEPAGE="http://www.h323plus.org/"
LICENSE="MPL-1.0"
SLOT="0"
KEYWORDS="~x86 ~amd64"
IUSE="debug ssl opal corrigendum"
DEPEND="net-libs/h323plus[debug=]
	net-libs/ptlib[http,ssl?,debug=]
	opal? ( net-libs/opal )
	!net-voip/openmcu"
RDEPEND="${DEPEND}"
S="${WORKDIR}/applications"

src_prepare() {
	append-cflags `${ROOT}/usr/bin/ptlib-config --ccflags --libs` -DP_SSL=$(use ssl && echo 1 || echo 0)
	ebegin "Fixing pathes"
	sed -i -e 's:"server.pem":"/etc/openmcu/server.pem":' -e 's:"data", "data":"data", "/usr/share/openmcu/data":' -e 's:"html", "html":"html", "/usr/share/openmcu/html":' -e 's:"mcu_log.txt":"/var/log/openmcu/mcu_log.txt":' openmcu/mcu.cxx
	eend $?
	local i
	for i in "${FILESDIR}"/${PN}-${PVR}-*.patch; do
		[[ -e "$i" ]] && epatch "$i"
	done
}

src_compile() {
	for i in "${S}"/*; do
		[ -e "$i/Makefile" ] || continue
		cd "$i" || die
		i="${i##*/}"
		einfo "Making '$i'"
		make323 || die "emake failed"
	done
}

src_install() {
for i in "${S}"/*; do
	[ -e "$i/Makefile" ] || continue
	cd "$i" || die
	local PN="${i##*/}"
	keepdir /var/log/${PN} /var/run/${PN}

	local b="${PN}"
	case "$PN" in
	openmcu)keepdir /usr/share/${PN}/data /usr/share/${PN}/html;;
	simple)b='simph323';;
	esac

#	make323 DESTDIR="${D}" install
	dosbin obj_*/"$b" || die

	for i in *.wav *.sw new_msg */config.* "${PN}".1 README ReadMe.txt "${FILESDIR}/${PN}".rc* "${FILESDIR}/${PN}".confd *.ini *.pem "${FILESDIR}"/*.ini; do
		[ -e "$i" ] && case "$i" in
		*.wav|*.sw)
			insinto "/usr/share/${PN}/sounds"
			doins "$i" || die
		;;
		*.1)doman "$i";;
		*.confd)newconfd "$i" "$PN";;
		*.pem|*.ini|config*)
			insinto "/etc/$PN"
			doins "$i"
		;;
		*.rc*)newinitd "$i" "$PN";;
		*)
			insinto "/usr/share/${PN}"
			doins "$i"
		;;
		esac
	done
done
die
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

make323(){
	unset USE_OPAL OPTIMIZE_CORRIGENDUM_IFP NOTRACE
	emake OPENH323DIR="${ROOT}/usr/share/openh323" CFLAGS="${CFLAGS}" CXXFLAGS="${CXXFLAGS}" LDFLAGS="${LDFLAGS}" CPPFLAGS="${CPPFLAGS}" \
		$(use debug && echo debug||echo opt) \
		$(use opal && echo USE_OPAL=1) \
		$(use corrigendum && echo OPTIMIZE_CORRIGENDUM_IFP=1) \
		"${@}"
	return $?
}
