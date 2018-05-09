EAPI=5

inherit eutils raw

DESCRIPTION="Asyncronous patchshield for Gentoo"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="alpha amd64 arm hppa ia64 mips ppc ppc64 s390 sh sparc x86"
RDEPEND="dev-lang/perl"
DEPEND="${RDEPEND}"
IUSE="strict global-profile apache2_modules_unixd custom-defaults ddns extensions mmap pam-mount-auth pch pgo tsx via-drm thinkpad10-2 speculative"
PDEPEND=""

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
	# "media-fonts/*" atom works only in /etc/portage/package.use
	# so simple enum all fonts to exclude from system-wide USE=-nls
	local i n c
	for i in "${PORTDIR:-/usr/portage}"/media-fonts/*; do
		[ -d "$i" ] || continue
		n="${i##*/}"
		i="${i%/*}"
		c="${i##*/}"
		echo "$c/$n nls"
	done|sort >"${WORKDIR}/package.use.force"
}

src_install(){
    local d s t r='/usr/ppatch'
    cd "${FILESDIR}"||die
    exeinto /usr/sbin
    doexe p-patch
    # lazy to make separate package just for 1 script
    dosbin mount.zram
#    dobin make.lto
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
    doins "${WORKDIR}/"{make.defaults,package.*}
}

migrate(){
	. "${ROOT}"/usr/ppatch/migrate-profile.sh
#	. "${FILESDIR}/migrate-profile.sh
}

pkg_postinst(){
    SS="${PORTAGE_CONFIGROOT}" "${ROOT}"/usr/sbin/p-patch "${ROOT}"/usr/ppatch/bashrc.p-patch
    local f=
    use global-profile && f=force && rm "${PORTDIR:-/usr/portage}"/metadata/md5-cache -Rf
    migrate $f
    raw_pkg_postinst
}
