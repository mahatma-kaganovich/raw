EAPI=7
inherit raw
SLOT="0"
SRC_URI=""
DESCRIPTION="smf common atom"
KEYWORDS="~x86 ~amd64"
PDEPEND="mail-mta/sendmail mail-filter/libmilter"
DEPEND="app-portage/ppatch"
S="${FILESDIR}"

src_install(){
	insinto "/usr/ppatch/mail-mta/sendmail/prepare"
	doins "${FILESDIR}/sleep.bashrc"
	insinto "/usr/ppatch/mail-filter/libmilter/prepare"
	doins "${FILESDIR}/sleep.bashrc"
}
