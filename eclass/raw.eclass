inherit eutils
EXPORT_FUNCTIONS pkg_postinst

KEYWORDS="raw"

# force RAWDEPEND to rebuild after
raw_pkg_postinst(){
	local p
	for p in ${RAWDEPEND}; do
		force "${ROOT}/var/db/pkg"/${p} && continue
		for p1 in $(grep -wrl "$p" "${ROOT}/var/db/pkg" --include=PROVIDE) ; do
			force ${p1%/PROVIDE}
		done
	done
	if [[ "${REBUILD}" != "" ]]; then
		einfo "=========================================================="
		einfo "= Run 'emerge -Nv world' to rebuild \"${REBUILD}\""
		einfo "=========================================================="
	fi
}

force(){
	local p f
	for p in "$1"*; do
		[[ -e "${p}" ]] || return 1
		local pp=${p/${ROOT}\/var\/db\/pkg\//}
		for f in "${p}"/{USE,IUSE}; do
			grep -q "raw-force-rebuild" "${f}" && continue
			sed -i -e 's/\(.*\)/\1 raw-force-rebuild/' "${f}"
			[[ "${pp}" != "" ]] && REBUILD="${REBUILD} ${pp}"
			pp=""
		done
	done
	return 0
}
