inherit raw

FN="reiser4-for-${PV}.patch.bz2"
DESCRIPTION="Reiser4 FS patches for linux kernel"
SLOT="${PV}"
SRC_URI="http://ftp.kernel.org/pub/linux/kernel/people/edward/reiser4/reiser4-for-2.6/${FN}"
KEYWORDS="~x86 ~amd64"
PDEPEND="|| ( virtual/linux-sources virtual/linux-kernel )"
RESTRICT="nomirror"
S="${WORKDIR}"

src_unpack(){
	cp "${DISTDIR}/${FN}" ${S} || die
}

src_install(){
	insinto /usr/ppatch/virtual/linux-sources/compile
	doins "${S}/${FN}" || die
}