inherit eutils linux-mod

mmake(){
	emake DESTDIR="${D}" ARCH=$(tc-arch-kernel) ABI=${KERNEL_ABI} $* || die "emake failed"
}

kern_prepare(){
	local k="${WORKDIR}/raw-kernel"
	local kk="${KERNEL_DIR}"
	[ -h "${KERNEL_DIR}" ] && kk="$(readlink -f ${KERNEL_DIR})" 
	cp "${kk}" "${k}" -Ra
	find "${k}" -name "*.cmd" | while read f ; do
		sed -i -e 's%'"${kk}"'%'"${k}"'%g' ${f}
	done
	KERNEL_DIR="${k}"
}

src_compile(){
	kern_prepare
	econf --with-kernel="${KERNEL_DIR}" || die
	mmake
}

src_install(){
	mmake install
}
