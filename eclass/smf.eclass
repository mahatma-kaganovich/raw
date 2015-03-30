inherit eutils user

MY_PN=${MY_PN:=${PN}}
MY_P=${MY_P:=${P}}
DIRS=${DIRS:=/var/run/smfs}

RESTRICT="nomirror"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~x86 ~amd64"
HOMEPAGE="http://smfs.sourceforge.net/${MY_PN}.html"
SRC_URI="mirror://sourceforge/smfs/${MY_P}.tar.gz"
DEPEND="mail-filter/smf-common
	mail-mta/sendmail"

S="${WORKDIR}/${MY_P}"

src_compile(){
	emake CFLAGS="-fwhole-program $CFLAGS -D_REENTRANT" LDFLAGS="$LDFLAGS -lmilter -lpthread" || die
}

src_install(){
	local dst=/usr/sbin
	exeinto $dst
	doexe ${MY_PN}
	local d
	for d in ${DIRS}; do
		keepdir ${d}
		fowners smfs:mail ${d}
		fperms 740 ${d}
	done
	for d in "${D}${dst}"/*; do
		d="${d##*/}"
		echo "#!/sbin/runscript

depend() {
	need localmount
	use netmount
	before mta
}

start() {
	ebegin 'Starting $d'
	checkpath -q -d -o smfs:mail -m 0740 /var/run/smfs && start-stop-daemon --start --exec $dst/$d
	eend \$? 'Failed to start $d'
}

stop() {
	ebegin 'Stopping $d'
	start-stop-daemon --stop --exec $dst/$d
	eend \$? 'Failed to stop $d'
	true
}
" >$d.initd
		newinitd $d.initd $d
	done
	insinto /etc/mail/smfs
	doins ${MY_PN}.conf
	fperms 755 /etc/mail/smfs
	dodoc readme
}

pkg_setup(){
	enewgroup smfs
	enewuser smfs -1 -1 /dev/null mail
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
