EAPI="5"
SLOT="0"
DESCRIPTION="Simple drop-in replacement for scannedonly package for clamd, written on perl"
LICENSE="Anarchy"
KEYWORDS="amd64 x86"
RDEPEND="net-fs/samba app-antivirus/clamav dev-lang/perl"

S="$WORKDIR"

src_install() {
	f="${FILESDIR}/${PN}"
	dobin "$f.pl" &&
	newinitd "$f.init" "$PN" &&
	newconfd "$f.conf" "$PN" &&
	exeinto /etc/cron.daily &&
	doexe "$f.daily" ||
	die
}
