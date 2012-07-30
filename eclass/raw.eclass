inherit eutils
EXPORT_FUNCTIONS pkg_preinst pkg_postinst

KEYWORDS="raw"

ppatch_dirs(){
	local p p1 i d="${D}/usr/ppatch/" db="${ROOT}/var/db/pkg/"
	for p in "$d"* ; do
		[[ -d "$p" ]] || continue
		p="${p#$d}"
		if [[ -d "$db$p" ]]; then
			for p in "$d$p"/* ; do
				[[ -d "$p" ]] && echo "${p#$d}"
			done
		else
			echo "$p"
		fi
	done|sort -u
}

raw_pkg_preinst(){
	local d=`pwd`
	( cd "${ROOT}/usr/ppatch" && md5sum `find $(ppatch_dirs)` ) >"${TMPDIR}/ppatch-${EBUILD_PHASE}.md5" 2>/dev/null
	cd "$d" || die
}

# force to rebuild after
raw_pkg_postinst(){
	raw_pkg_preinst
	local p p1 i d="${D}/usr/ppatch/" db="${ROOT}/var/db/pkg/"
	for p in `diff -U 0 "${TMPDIR}"/ppatch-{preinst,postinst}.md5|grep "^[+-][^+-]"|sed -e 's:^[^ ]*  ::' -e 's:^\([^/]*/[^/]*\).*$:\1:'|sort -u`; do
		p1="${p%%/*}"
		if ! [[ -d "$db$p1" ]]; then
			p=' '
			for i in "$db"*/"$p1"-[0-9]*; do
				[[ -d "$i" ]] || continue
				i="${i#$db}"
				i="${i%%/*}/$p1"
				[[ -n "${p##* $i *}" ]] && p+="$i "
			done
		fi
		for p in $p; do
			force "${ROOT}/var/db/pkg"/${p} && continue
			for p1 in $(grep -wrl "$p" "${ROOT}/var/db/pkg" --include=PROVIDE) ; do
				force ${p1%/PROVIDE}
			done
		done
	done
	if [[ -n "${REBUILD}" ]]; then
		einfo "=========================================================="
		einfo "= Run 'emerge -Nv world' to rebuild \"${REBUILD# }\""
		einfo "=========================================================="
	fi
}

force(){
	local p f
	for p in "$1"-[0-9]*; do
		[[ -e "${p}" ]] || return 1
		local pp=${p/${ROOT}\/var\/db\/pkg\//}
		for f in "${p}"/{USE,IUSE}; do
			if [[ -e "${f}" ]]; then
				grep -q "raw-force-rebuild" "${f}" && continue
				sed -i -e 's/\(.*\)/\1 raw-force-rebuild/' "${f}"
			else
				echo "raw-force-rebuild" >"${f}"
			fi
			[[ -n "${pp}" ]] && REBUILD="${REBUILD} ${pp}"
			pp=""
		done
	done
	return 0
}
