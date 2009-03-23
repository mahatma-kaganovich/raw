SLOT="0"
SRC_URI=""
DESCRIPTION="smf common atom"
KEYWORDS="~x86 ~amd64"
PDEPEND="mail-mta/sendmail"

src_install(){
	insinto "/usr/ppatch/mail-mta/sendmail/compile"
	doins "${FILESDIR}/sleep.p-patch"
}

pkg_postinst(){
	ewarn "============================================"
	ewarn "  Now you must run:"
	ewarn "emerge -1 sendmail"
	ewarn "  to re-emerge sendmail with sleep patch"
	ewarn "============================================"
}