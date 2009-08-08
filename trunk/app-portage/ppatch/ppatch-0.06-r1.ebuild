
inherit eutils raw

DESCRIPTION="Asyncronous patchshield for Gentoo"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="alpha amd64 arm hppa ia64 mips ppc ppc64 s390 sh sparc x86"
RDEPEND="dev-lang/perl"
DEPEND="${RDEPEND}"
IUSE=""
PDEPEND=""
RAWDEPEND=""

# every patchset (=useflag) is files/... dir
ppinit(){
	local p p1 f pac
	for p in "${FILESDIR}"/* ; do
		[[ -d "$p" ]] || continue
		f="${p##*/}"
		IUSE="$IUSE $f"
		for p1 in "$p"/*/* ; do
			[[ -d "${p1}" ]] || continue
			pac="${p1#$p/}"
			#PDEPEND="$PDEPEND $f? ( $pac )"
			RAWDEPEND="$RAWDEPEND $pac"
		done
	done
}

ppinit

src_install(){
    local d
    dodir /usr/sbin
    dodir /usr/ppatch
    cp "${FILESDIR}"/p-patch-${PV} "${TMPDIR}"/p-patch
    cp "${FILESDIR}"/*.p-patch "${D}"/usr/ppatch/
    for d in $IUSE ; do
	( use !"${d}" || ! [[ -d "${FILESDIR}/${d}" ]] ) && continue
	cp "${FILESDIR}/${d}"/* "${D}"/usr/ppatch/ -Rf
    done
    install "${TMPDIR}"/p-patch "${D}"/usr/sbin
}

pkg_postinst(){
    SS="${PORTAGE_CONFIGROOT}" p-patch ${FILESDIR}/bashrc.p-patch
    raw_pkg_postinst
}
