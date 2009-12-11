inherit raw

EAPI="2"
DESCRIPTION="Nouveau DRM patch for linux kernel"
SLOT="${PV}"
HOMEPAGE="http://cgit.freedesktop.org/nouveau/linux-2.6/"
SRC_URI="http://cgit.freedesktop.org/nouveau/linux-2.6/patch/?id=d2f6fd14ff6443fa9929a19d746dd2fd3b94aaea -> ${P}.patch"
KEYWORDS="~x86 ~amd64"
PDEPEND="|| ( virtual/linux-sources virtual/linux-kernel )"
RESTRICT="nomirror"
S="${WORKDIR}"

src_unpack(){
	perl "${FILESDIR}"/pp.pl <"${DISTDIR}/${P}.patch"|bzip2 -c9 >"${S}/${P}".patch.bz2
}

src_install(){
	insinto /usr/ppatch/virtual/linux-sources/compile
	doins "${P}".patch.bz2 || die
}
