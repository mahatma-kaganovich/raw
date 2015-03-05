EAPI="5"
SLOT="0"
DESCRIPTION="Simple replacement for scannedonly package for clamd, written on perl"
LICENSE="Anarchy"
KEYWORDS="amd64 x86"
RDEPEND="net-fs/samba app-antivirus/clamav dev-lang/perl"

S="$WORKDIR"

src_install() {
	f="${FILESDIR}/${PN}"
	keepdir "/var/lib/scannedonly"
	dobin "$f.pl" &&
	newinitd "$f.init" "$PN" &&
	newconfd "$f.conf" "$PN" &&
	exeinto /etc/cron.daily &&
	doexe "$f.daily" ||
	die
}
