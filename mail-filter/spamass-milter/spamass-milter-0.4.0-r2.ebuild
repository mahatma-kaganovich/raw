# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit eutils

IUSE=""

DESCRIPTION="A milter for SpamAssassin"
HOMEPAGE="https://savannah.nongnu.org/projects/spamass-milt/"
SRC_URI="https://savannah.nongnu.org/download/spamass-milt/${P}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="amd64 ~ppc x86"

DEPEND="|| ( mail-filter/libmilter mail-mta/sendmail )
	>=mail-filter/spamassassin-3.1.0"
RDEPEND="${DEPEND}"

PATCHES=(
        "${FILESDIR}"/${PN}-git.patch
        "${FILESDIR}"/${PN}-quarantine.patch
)

#pkg_setup() {
#	enewgroup milter
#	enewuser milter -1 -1 /var/lib/milter milter
#}

src_install() {
	emake DESTDIR="${D}" install

	newinitd "${FILESDIR}"/spamass-milter.rc4 spamass-milter
	newconfd "${FILESDIR}"/spamass-milter.conf3 spamass-milter
	dodir /var/lib/milter
	keepdir /var/lib/milter
#	fowners milter:milter /var/lib/milter

	dodoc AUTHORS NEWS README ChangeLog "${FILESDIR}/README.gentoo"
}
