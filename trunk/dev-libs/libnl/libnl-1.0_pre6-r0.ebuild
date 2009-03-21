
inherit eutils multilib

MY_P="${PN}-1.0-pre6"
MY_P_DOC="${PN}-doc-1.0-pre4"
DESCRIPTION="A library for applications dealing with netlink socket"
HOMEPAGE="http://people.suug.ch/~tgr/libnl/"
SRC_URI="http://people.suug.ch/~tgr/libnl/files/${MY_P}.tar.gz
    doc? ( http://people.suug.ch/~tgr/libnl/files/${MY_P_DOC}.tar.gz )"
LICENSE="LGPL-2.1"
SLOT="0"
IUSE="doc"
KEYWORDS="amd64 x86"
S="${WORKDIR}/${MY_P}"

src_unpack() {
	unpack ${A}
	use doc && unpack ${MY_P_DOC}.tar.gz
	cd ${S}/lib
	sed -i Makefile -e 's:install -o root -g root:install:'
	cd ${S}/include
	sed -i Makefile -e 's:install -o root -g root:install:g'
	epatch "${FILESDIR}/${PN}-1.0-pre6-include.diff"
	epatch "${FILESDIR}/${PN}-1.0-pre6-amd64-typedef.diff"
}

src_install() {
	make DESTDIR="${D}" LIBDIR="/usr/$(get_libdir)" install || die
	use doc && dodoc ${WORKDIR}/${MY_P_DOC}/*
}
