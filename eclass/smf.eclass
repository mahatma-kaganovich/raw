inherit eutils

MY_PN=${MY_PN:=${PN}}
MY_P=${MY_P:=${P}}
DIRS=${DIRS:=/var/smfs}

RESTRICT="nomirror"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~x86 ~amd64"
HOMEPAGE="http://smfs.sourceforge.net/${MY_PN}.html"
SRC_URI="mirror://sourceforge/smfs/${MY_P}.tar.gz"
DEPEND="mail-filter/smf-common
	mail-mta/sendmail
	app-portage/ppatch"

S="${WORKDIR}/${MY_P}"

src_compile(){
	sed -i -e 's%-O2%'"${CFLAGS}"'%' Makefile
	emake || die
}

src_install(){
	exeinto /usr/sbin
	doexe ${MY_PN}
	local d
	for d in ${DIRS}; do
		keepdir ${d}
		fowners smfs:smfs ${d}
		fperms 700 ${d}
	done
	insinto /etc/mail/smfs
	doins ${MY_PN}.conf
	fperms 755 /etc/mail/smfs
	dodoc readme
}

pkg_setup(){
	enewgroup smfs
	enewuser smfs -1 -1 /dev/null smfs
}

pkg_postinst(){
einfo "===================================================================="
einfo "Add these lines to your Sendmail configuration file (usually sendmail.mc):"
einfo "define(\`confMILTER_MACROS_HELO\', confMILTER_MACROS_HELO\`, {verify}\')dnl"
einfo "INPUT_MAIL_FILTER(\`${MY_PN}\', \`S=unix:${DIRS/ */}/${MY_PN}.sock, T=S:30s;R:4m\')dnl"
einfo
einfo "Also recommended:"
einfo "define(\`confPRIVACY_FLAGS\', \`goaway,noetrn,nobodyreturn,noreceipts\')dnl"
einfo "define(\`confTO_COMMAND\', \`1m\')dnl"
einfo "define(\`confTO_IDENT\', \`0s\')dnl"
einfo "define(\`confMAX_DAEMON_CHILDREN\', \`256\')dnl enlarge if it\'s required"
einfo "define(\`confCONNECTION_RATE_THROTTLE\', \`8\')dnl enlarge if it\'s required"
einfo "define(\`confBAD_RCPT_THROTTLE\', \`1\')dnl Sendmail v8.12+"
einfo "FEATURE(\`greet_pause\', \`5000\')dnl Sendmail v8.13+"
einfo "===================================================================="
}
