inherit raw-mod
source "${PORTDIR}/eclass/kernel-2.eclass"
IUSE="${IUSE} build-kernel debug custom-cflags cramfs"
DEPEND="${DEPEND}
	build-kernel? (
		sys-kernel/genkernel
		cramfs? ( sys-fs/cramfs )
	) "

[[ "${KERNEL_CONFIG}" == "" ]] &&
    KERNEL_CONFIG="-CC_OPTIMIZE_FOR_SIZE DMA_ENGINE USB_STORAGE_\w+ NET_RADIO PNP PNP_ACPI PARPORT_PC_FIFO PARPORT_1284 NFTL_RW PMC551_BUGFIX CISS_SCSI_TAPE CDROM_PKTCDVD_WCACHE SCSI_SCAN_ASYNC IOSCHED_DEADLINE DEFAULT_DEADLINE SND_SEQUENCER_OSS SND_FM801_TEA575X_BOOL SND_AC97_POWER_SAVE SCSI_PROC_FS  -ARCNET -IDE -SMB_FS -DEFAULT_CFQ -SOUND_PRIME -KVM"
[[ "${KERNEL_MODULES}" == "" ]] &&
    KERNEL_MODULES="drivers fs sound"

[[ -e "${CONFIG_ROOT}/etc/kernels/kernel.conf" ]] && source "${CONFIG_ROOT}/etc/kernels/kernel.conf"


kernel-2_src_compile() {
	cd "${S}"
	[[ ${ETYPE} == headers ]] && compile_headers
	[[ ${ETYPE} == sources ]] || return
	use custom-cflags && sed -i -e "s/-O2/${CFLAGS}/g" Makefile
	use build-kernel || return
	config_defaults
	mmake
	initrd
}


kernel-2_src_install() {
	cd "${S}" || die
	if [[ ${ETYPE} == sources ]] && use build-kernel; then
		insinto "/boot"
		doins "initrd-${KV}.img"
		mmake INSTALL_PATH="${D}/boot" INSTALL_MOD_PATH="${D}" install modules_install
		ewarn "If your /boot is not mounted, copy next files by hands:"
		ewarn `ls "${D}/boot"`
	fi
	install_universal
	[[ ${ETYPE} == headers ]] && install_headers
	[[ ${ETYPE} == sources ]] && install_sources
}

initrd(){
	LDFLAGS="" genkernel ramdisk --kerneldir="${S}" --logfile="${TMPDIR}/genkernel.log" --bootdir="${S}" --no-mountboot --cachedir="${TMPDIR}/genkernel-cache" --tempdir="${TMPDIR}/genkernel" --postclear #  --all-ramdisk-modules
	local r=`ls initramfs*-${KV}`
	rename "${r}" "initrd-${KV}.img" "${r}" || die "initramfs rename failed"
	use cramfs || return
	einfo "Converting initramfs to cramfs"
	local tmp="${TMPDIR}/ramfstmp"
	mkdir "${tmp}"
	cd "${tmp}" || die "cd failed"
	gzip p -dc "${S}/initrd-${KV}.img" | cpio -i
	sed -i -e 's/ext2/cramfs/g' etc/fstab
	cd "${S}" || die
	mkcramfs "${tmp}" "initrd-${KV}.img" || die
	rm "${tmp}" -Rf
	gzip -9 "initrd-${KV}.img" || die
	rename .gz "" "initrd-${KV}.img.gz" || die
}

cfg(){
	local r="$1"
	shift
	local o="$*"
	for i in `grep -P "^(?:\# )?CONFIG_${o}(?:=.*| is not set)$" .config || echo "${o}"` ; do
		i=${i#\# }
		i=${i#CONFIG_}
		i=${i/=*/}
		sed -i -e "s/^# CONFIG_${i} is not set//" -e "s/^CONFIG_${i}=.*//" .config
		if [[ "${r}" == "n" ]]; then
			echo "# CONFIG_${i} is not set" >>.config
		elif [[ "${r}" != "-" ]]; then
			echo "CONFIG_${i}=${r}" >>.config
		fi
	done
}

setconfig(){
	local i o
	for i in ${KERNEL_CONFIG}; do
		o="y ${i}"
		o="${o/y +/m }"
		o="${o/y -/n }"
		o="${o/y ~/- }"
		cfg ${o}
	done
	yes '' 2>/dev/null | mmake oldconfig &>/dev/null
}

config_defaults(){
	local i i1 o
	einfo "Configuring kernel"
	mmake defconfig >/dev/null
	for i in ${KERNEL_MODULES}; do
		for i1 in ${i}{,/*,/*/*,/*/*/*,*/*/*/*}/Kconfig{,.*} ; do
			[[ -e ${i1} ]] || continue
			echo "	${i1}"
			for o in `grep -P "^\s*(?:menu)?config\s.*\n(?:[^\n]+\n)*\s*tristate" ${i1} 2>/dev/null  | grep -P "^config"` ; do
				[[ "${o}" == "config" ]] || cfg m ${o}
			done
		done
	done
	setconfig
	setconfig
	setconfig
	if use cramfs; then
		cfg y CRAMFS
	else
		cfg y EXT2_FS
	fi
	use debug || sed -i -e 's/^CONFIG.*_DEBUG=.*//' .config
	yes '' 2>/dev/null | mmake oldconfig >/dev/null
}
