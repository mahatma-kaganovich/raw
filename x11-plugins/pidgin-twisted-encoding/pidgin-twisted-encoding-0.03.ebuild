EAPI="8"
SLOT="0"
DESCRIPTION="Pidgin plugin. Repair double encoded messages (usually ICQ->Jabber)."
LICENSE="Anarchy"
KEYWORDS="amd64 x86"
RDEPEND="net-im/pidgin[perl]"
S="${FILESDIR}"

src_install() {
	insinto /usr/$(get_libdir)/purple-2
	doins "${FILESDIR}"/twist-enc.pl
}
