inherit raw-mod
source "${PORTDIR}/eclass/kernel-2.eclass"
IUSE="${IUSE} build-kernel debug"
DEPEND="${DEPEND}
	build-kernel? ( sys-kernel/genkernel ) "

[[ "${KERNEL_CONFIG}" == "" ]] &&
    KERNEL_CONFIG="DMA_ENGINE USB_STORAGE_\w+ NET_RADIO PNP PNP_ACPI PARPORT_PC_FIFO PARPORT_1284 NFTL_RW PMC551_BUGFIX CISS_SCSI_TAPE CDROM_PKTCDVD_WCACHE SCSI_SCAN_ASYNC IOSCHED_DEADLINE DEFAULT_DEADLINE SND_SEQUENCER_OSS SND_FM801_TEA575X_BOOL SND_AC97_POWER_SAVE SCSI_PROC_FS  -ARCNET -IDE -SMB_FS -DEFAULT_CFQ -SOUND_PRIME -KVM"
[[ "${KERNEL_MODULES}" == "" ]] &&
    KERNEL_MODULES="drivers fs sound"

[[ -e "${CONFIG_ROOT}/etc/kernels/kernel.conf" ]] && source "${CONFIG_ROOT}/etc/kernels/kernel.conf"

kernel-2_src_compile() {
	cd "${S}"
	[[ ${ETYPE} == headers ]] && compile_headers
	use build-kernel || return
	config_defaults
	mmake
#	genkernel all --kernel-config="${S}/.config" --kerneldir="${S}" --logfile=/dev/null --no-install --integrated-initramfs
}

kernel-2_src_install() {
	mkdir "${D}/boot"
	genkernel ramdisk --kerneldir="${S}" --logfile=/dev/null --bootdir="${D}/boot"
	install_universal
	[[ ${ETYPE} == headers ]] && install_headers
	[[ ${ETYPE} == sources ]] && install_sources
	use build-kernel || return
	mmake INSTALL_PATH="${D}/boot" INSTALL_MOD_PATH="${D}" install modules_install
	local ff=`ls "${D}/boot"`
	ewarn "If your /boot is not mounted, copy next files by hands:"
	ewarn "${ff}"
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
	use debug || sed -i -e 's/^CONFIG.*_DEBUG=.*//' .config
	yes '' 2>/dev/null | mmake oldconfig >/dev/null
}
