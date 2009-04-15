inherit eutils linux-mod

mmake(){
	emake DESTDIR="${D}" ARCH=$(tc-arch-kernel) ABI=${KERNEL_ABI} $* || die "emake failed"
}

kern_prepare(){
	local k="${WORKDIR}/raw-kernel"
	cp "${KERNEL_DIR}" "${k}" -LRp
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
