inherit eutils linux-mod
EXPORT_FUNCTIONS src_compile src_install src_prepare src_configure pkg_setup

mmake(){
	emake DESTDIR="${D}" HOSTCC="$(tc-getBUILD_CC)" CROSS_COMPILE="${CTARGET:-${CHOST}}-" ARCH="$(tc-arch-kernel)" ABI="${KERNEL_ABI}" $* || die "emake failed"
}

mconf(){
	DESTDIR="${D}" HOSTCC="$(tc-getBUILD_CC)" CROSS_COMPILE="${CTARGET:-${CHOST}}-" ARCH="$(tc-arch-kernel)" ABI="${KERNEL_ABI}" econf $* || die
}

# around 2.6.35 bug
raw-mod_pkg_setup(){
	local d=`pwd`
	cd "${KERNEL_DIR}"
	linux-mod_pkg_setup
	cd "$d"
}

raw-mod_src_prepare(){
	local k="${WORKDIR}/raw-kernel"
	local kk="${KERNEL_DIR}"
	[ -h "${KERNEL_DIR}" ] && kk="$(readlink -f ${KERNEL_DIR})" 
	cp "${kk}" "${k}" -Ra
	find "${k}" -name "*.cmd" | while read f ; do
		sed -i -e 's%'"${kk}"'%'"${k}"'%g' ${f}
	done
	KERNEL_DIR="${k}"
}

raw-mod_src_configure(){
	local l h=`mconf --help`
	for l in with-kernel with-linux with-kdir with-kdir-path; do
		[[ "${h#*--$l=}" == "$h" ]] || break
	done
	mconf --${l}="${KERNEL_DIR}" ${myconf}
}

raw-mod_src_compile(){
	mmake
}

raw-mod_src_install(){
	mmake install
}
