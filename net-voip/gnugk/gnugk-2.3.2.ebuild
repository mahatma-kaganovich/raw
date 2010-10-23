# Copyright 1999-2010 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/net-voip/gnugk/gnugk-2.2.8.ebuild,v 1.2 2010/06/17 20:58:55 patrick Exp $

EAPI="2"

cvs=""
case "${PVR}" in
9999*)
	cvs=cvs
	ECVS_SERVER="openh323gk.cvs.sourceforge.net:/cvsroot/openh323gk"
	ECVS_MODULE="openh323gk"
	ECVS_USER="anonymous"
	ECVS_PASS=""
	S="${WORKDIR}/openh323gk"
;;
*)SRC_URI="mirror://sourceforge/openh323gk/${P}.tar.gz";;
esac

inherit flag-o-matic eutils ${cvs}

DESCRIPTION="GNU H.323 gatekeeper"
HOMEPAGE="http://www.gnugk.org/"

LICENSE="GPL-2"
SLOT="0"
# dev-db/firebird isn't keyworded for ppc but firebird IUSE is masked for ppc
KEYWORDS="~amd64 ~ppc ~x86"
IUSE="doc firebird mysql odbc postgres radius sqlite linguas_en linguas_es linguas_fr
	h46018 +h46023"

# TODO: when h323plus will be in portage tree, add it as || dep with openh323
RDEPEND="net-libs/ptlib
	net-libs/h323plus
	dev-libs/openssl
	firebird? ( dev-db/firebird )
	mysql? ( virtual/mysql )
	odbc? ( dev-db/unixODBC )
	postgres? ( dev-db/postgresql-base )
	sqlite? ( dev-db/sqlite:3 )"
DEPEND="${RDEPEND}
	doc? ( app-text/linuxdoc-tools )"

pkg_setup() {
	if use doc && ! use linguas_en && ! use linguas_es && ! use linguas_fr; then
		elog "No linguas specified."
		elog "English documentation will be installed."
	fi
}

_epatch(){
	[[ -e "$1" ]] && epatch "$1"
}

src_prepare() {
	use firebird && _epatch "${FILESDIR}"/${P}-firebird-2.1.patch
	epatch "${FILESDIR}"/${PN}-notrace.patch
	sed -i -e 's% self->GetName();%\n#if PTRACING\nself->GetName();\n#else\n0;\n#endif\n%' *.{h,cxx}
}

src_configure() {
	use h46018 && {
		ewarn "****************************************************************************"
		ewarn "You selecting H.460.18 / H.460.19 NAT traversal,                           *"
		ewarn "granted by Tandberg to GnuGk project.                                      *"
		ewarn "Check patent license before enabling!                                      *"
		ewarn "http://www.tandbergusa.com/collateral/tandberg-ITU-license.pdf             *"
		ewarn "http://www.tandberg.com/collateral/tandberg-ITU-H460-license-agreement.pdf *"
		ewarn "****************************************************************************"
		ebeep 10
		epause 5
	}
	# --with-large-fdset=4096 is added because of bug #128102
	# and it is recommanded in the online manual
	export PTLIB_CONFIG="${ROOT}/usr/bin/ptlib-config"
	export PW_LIBDIR="/usr/$(get_libdir)"
	append-cflags `$PTLIB_CONFIG --ccflags --libs` -fexceptions
	econf \
		$(use_enable h46018) \
		$(use_enable h46023) \
		$(use_enable firebird) \
		$(use_enable mysql) \
		$(use_enable postgres pgsql) \
		$(use_enable odbc unixodbc) \
		$(use_enable radius) \
		$(use_enable sqlite) \
		--with-large-fdset=4096
}

src_compile() {
	# PASN_NOPRINT should be set for -debug but it's buggy
	# better to prevent issues and keep default settings
	# `make debugdepend debugshared` and `make debug` failed (so no debug)
	# `make optdepend optnoshared` also failed (so no static)

	# splitting emake calls fixes parallel build issue
	emake optdepend || die "emake optdepend failed"
	emake optshared || die "emake optshared failed"

	# build tool addpasswd
	emake addpasswd || die "emake addpasswd failed"

	if use doc; then
		cd docs/manual

		if use linguas_en || ( ! use linguas_es && ! use linguas_fr ); then
			emake html || die "emake en doc failed"
		fi

		if use linguas_es; then
			emake html-es || die "emake es doc failed"
		fi

		if use linguas_fr; then
			emake html-fr || die "emake fr doc failed"
		fi
		cd ../..
	fi
}

src_install() {
	dosbin obj_*/${PN} || die "dosbin failed"
	dosbin obj_*/addpasswd || die "dosbin failed"

	dodir /etc/${PN}
	insinto /etc/${PN}
	doins etc/* || die "doins etc/* failed"

	dodoc changes.txt readme.txt H46023_license.txt || die "dodoc failed"

	if use doc; then
		dodoc docs/*.txt docs/*.pdf || die "dodoc failed"

		if use linguas_en || ( ! use linguas_es && ! use linguas_fr ); then
			dohtml docs/manual/manual*.html || die "dohtml failed"
		fi
		if use linguas_fr; then
			dohtml docs/manual/fr/manual-fr*.html || die "dohtml failed"
		fi
		if use linguas_es; then
			dohtml docs/manual/es/manual-es*.html || die "dohtml failed"
		fi
	fi

	doman docs/${PN}.1 || die "doman failed"

	newinitd "${FILESDIR}"/${PN}.rc6 ${PN}
	newconfd "${FILESDIR}"/${PN}.confd ${PN}
}
