inherit eutils raw

EAPI="2"
DESCRIPTION="Asyncronous patchshield for Gentoo"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="alpha amd64 arm hppa ia64 mips ppc ppc64 s390 sh sparc x86"
RDEPEND="dev-lang/perl"
DEPEND="${RDEPEND}"
IUSE="strict"
PDEPEND=""

: ${FILESDIR:=${EBUILD%/*}/files}

# every patchset (=useflag) is files/... dir
ppinit(){
	local p p1 f pac
	for p in "${FILESDIR}"/* ; do
		[[ -d "$p" ]] || continue
		f="${p##*/}"
		IUSE="$IUSE $f"
#		for p1 in "$p"/*/* ; do
#			[[ -d "${p1}" ]] || continue
#			pac="${p1#$p/}"
#			PDEPEND="$PDEPEND $f? ( $pac )"
#		done
	done
}

ppinit

src_install(){
    local d s t
    cd "${FILESDIR}"||die
    exeinto /usr/sbin
    doexe p-patch
    insinto /usr/ppatch
    doins *.p-patch
    dodir /usr/ppatch/virtual
    dosym linux-sources /usr/ppatch/virtual/linux-kernel
    for d in $IUSE ; do
	( use !"${d}" || ! [[ -d "${d}" ]] ) && continue
	d="${FILESDIR}/${d}"
	find "${d}"|egrep -v "/\."|while read s; do
		t="${s#${d}/}"
		[[ "${t}" == "${s}" ]] && continue
		use strict || t="`echo "$t"|sed -e 's:^\([^/]*/[^/]*/[^/]*/\)[^/]*/\([^/]*\):\1\2:'`"
		t="${D}/usr/ppatch/${t}"
		if ! [[ -d "${s}" ]] || [[ -L "${s}" ]]; then
			mkdir -p "${t%/*}"
			cp -a "${s}" "${t}" || die
		fi
	done
    done
}

pkg_postinst(){
    SS="${PORTAGE_CONFIGROOT}" "${ROOT}"/usr/sbin/p-patch "${ROOT}"/usr/ppatch/bashrc.p-patch
    raw_pkg_postinst
}
