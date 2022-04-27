EAPI=6
inherit raw
SLOT="0"
SRC_URI=""
DESCRIPTION="smf common atom"
KEYWORDS="~x86 ~amd64"
PDEPEND="mail-mta/sendmail"
DEPEND="app-portage/ppatch"


src_install(){
	insinto "/usr/ppatch/mail-mta/sendmail/compile"
	doins "${FILESDIR}/sleep.bashrc"
}
