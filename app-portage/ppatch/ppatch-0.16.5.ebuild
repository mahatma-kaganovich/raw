EAPI=5

inherit eutils raw

DESCRIPTION="Asyncronous patchshield for Gentoo"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="alpha amd64 arm hppa ia64 mips ppc ppc64 s390 sh sparc x86"
RDEPEND="dev-lang/perl"
DEPEND="${RDEPEND}"
IUSE="strict global-profile"
PDEPEND=""

: ${FILESDIR:=${EBUILD%/*}/files}

# every patchset (=useflag) is files/... dir
ppinit(){
	local p p1 f pac
	for p in "${FILESDIR}"/* ; do
		[[ -d "$p" ]] || continue
		f="${p##*/}"
		f1="${f//[()|&^]}"
		IUSE+=" ${f1#!}"
#		[[ "$f" != "$f1" ]] && REQUIRED_USE+=" $f"
#		for p1 in "$p"/*/* ; do
#			[[ -d "${p1}" ]] || continue
#			pac="${p1#$p/}"
#			PDEPEND="$PDEPEND $f? ( $pac )"
#		done
	done
}

ppinit

src_unpack(){
	mkdir -p "${S}"
}

src_compile(){
	CC="$(tc-getCC)"
	[ "$CC" = gcc ] || gcc(){
		$CC "${@}"
	}
	{
		case "$ARCH" in
		amd64|x86)echo "ACCEPT_KEYWORDS=\"amd64 ~amd64 x86 ~x86\"";;
		*)echo "ACCEPT_KEYWORDS=\"$ARCH ~$ARCH\"";;
		esac
		. "${FILESDIR}/cpu2conf.sh"
	} >"${WORKDIR}/make.defaults"
}

src_install(){
    local d s t r='/usr/ppatch'
    cd "${FILESDIR}"||die
    exeinto /usr/sbin
    doexe p-patch
    insinto $r
    doins *.{p-patch,bashrc,sh}
    dodir $r/virtual
    dosym linux-sources $r/virtual/linux-kernel
    for d in $IUSE ; do
	use "$d" || d="!$d"
	d="${FILESDIR}/$d"
	[[ -d "$d" ]] || continue
	find "$d"|egrep -v "/\."|while read s; do
		t="${s#$d/}"
		[[ "$t" == "$s" ]] && continue
		use strict || t="`echo "$t"|sed -e 's:^\([^/]*/[^/]*/[^/]*/\)[^/]*/\([^/]*\):\1\2:'`"
		t="$D$r/$t"
		if ! [[ -d "$s" ]] || [[ -L "$s" ]]; then
			mkdir -p "${t%/*}"
			cp -a "$s" "$t" || die
		fi
	done
    done
    insinto $r/profiles
    doins "${WORKDIR}/make.defaults"
}

migrate(){
	. "${ROOT}"/usr/ppatch/migrate-profile.sh
#	. "${FILESDIR}/migrate-profile.sh
}

pkg_postinst(){
    SS="${PORTAGE_CONFIGROOT}" "${ROOT}"/usr/sbin/p-patch "${ROOT}"/usr/ppatch/bashrc.p-patch
    local f=
    use global-profile && f=force
    migrate $f
    raw_pkg_postinst
}
