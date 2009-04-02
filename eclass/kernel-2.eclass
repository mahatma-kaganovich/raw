inherit raw-mod
source "${PORTDIR}/eclass/kernel-2.eclass"
IUSE="${IUSE} build-kernel debug custom-cflags compress integrated ipv6"
DEPEND="${DEPEND}
	build-kernel? (
		sys-kernel/genkernel
		compress? (
			sys-fs/squashfs-tools
			sys-fs/cramfs
		)
	) "
# cramfs = compat

[[ "${KERNEL_CONFIG}" == "" ]] &&
    KERNEL_CONFIG="-CC_OPTIMIZE_FOR_SIZE DMA_ENGINE USB_STORAGE_[^\s\n=]+ USB_LIBUSUAL -BLK_DEV_UB NET_RADIO PNP PNP_ACPI PARPORT_PC_FIFO PARPORT_1284 NFTL_RW PMC551_BUGFIX CISS_SCSI_TAPE CDROM_PKTCDVD_WCACHE SCSI_SCAN_ASYNC IOSCHED_DEADLINE DEFAULT_DEADLINE SND_SEQUENCER_OSS SND_FM801_TEA575X_BOOL SND_AC97_POWER_SAVE SCSI_PROC_FS  -ARCNET -IDE -SMB_FS -DEFAULT_CFQ -SOUND_PRIME -KVM"
[[ "${KERNEL_MODULES}" == "" ]] &&
    KERNEL_MODULES="drivers fs sound"

[[ -e "${CONFIG_ROOT}/etc/kernels/kernel.conf" ]] && source "${CONFIG_ROOT}/etc/kernels/kernel.conf"


kernel-2_src_compile() {
	cd "${S}"
	[[ ${ETYPE} == headers ]] && compile_headers
	[[ ${ETYPE} == sources ]] || return
	if use custom-cflags; then
#		filter-flags -march=* -msse* -mmmx -m3dnow
		sed -i -e "s/-O2/${CFLAGS}/g" Makefile
	fi
	use build-kernel || return
	config_defaults
	mmake
	cp "${ROOT}/var/cache/genkernel" "${TMPDIR}/genkernel-cache" -r
	local p=""
	use compress && p="${p} --all-ramdisk-modules"
	LDFLAGS="" genkernel ramdisk --kerneldir="${S}" --logfile="${TMPDIR}/genkernel.log" --bootdir="${S}" --no-mountboot --cachedir="${TMPDIR}/genkernel-cache" --tempdir="${TMPDIR}/genkernel" --postclear ${p} || die
	local r=`ls initramfs*-${KV}`
	rename "${r}" "initrd-${KV}.img" "${r}" || die "initramfs rename failed"
	use compress && fs_compat
#	use cramfs && cramfs
	if use integrated; then
		cfg - CONFIG_INITRAMFS_SOURCE
		cfg - CONFIG_INITRAMFS_ROOT_UID
		cfg - CONFIG_INITRAMFS_ROOT_GID
		gzip -dc  "initrd-${KV}.img" >"initrd-${KV}.cpio" || die
		rm "initrd-${KV}.img"
		echo "CONFIG_INITRAMFS_SOURCE=\"${S}/initrd-${KV}.cpio\"\nCONFIG_INITRAMFS_ROOT_UID=0\nCONFIG_INITRAMFS_ROOT_GID=0" >>.config
		yes '' 2>/dev/null | mmake oldconfig &>/dev/null
		mmake
	fi
}


kernel-2_src_install() {
	cd "${S}" || die
	if [[ ${ETYPE} == sources ]] && use build-kernel; then
		mkdir "${D}/boot"
		if ! use integrated; then
			insinto "/boot"
			doins "initrd-${KV}.img"
		fi
		mmake INSTALL_PATH="${D}/boot" INSTALL_MOD_PATH="${D}" install modules_install
		use symlink || rm "${D}"/boot/vmlinuz
		ewarn "If your /boot is not mounted, copy next files by hands:"
		ewarn `ls "${D}/boot"`
	fi
	install_universal
	[[ ${ETYPE} == headers ]] && install_headers
	[[ ${ETYPE} == sources ]] && install_sources
}

# incompatible with 2.6.20
cramfs(){
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

squashfs_enabled(){
	[[ -e "${S}/fs/squashfs" ]] && return 0
	return 1
}

# compressed /lib loopback only, compat
fs_compat(){
	einfo "Including $1 into initramfs"
	local tmp="${TMPDIR}/ramfstmp"
	mkdir "${tmp}"
	cd "${tmp}" || die "cd failed"
	gzip p -dc "${S}/initrd-${KV}.img" | cpio -i
	if squashfs_enabled; then
		mksquashfs "lib" "lib.loopfs" -all-root -no-recovery || die
	else
		mkcramfs "lib" "lib.loopfs" || die
	fi
	sed -i -e 's%\(#!/bin/sh\)%\1\n\n/bin/mount /lib.loopfs /lib -o loop%' \
		-e 's%\(umount /sys\)%umount /lib\n\1%' \
		init
	rm ${tmp}/lib/* -Rf || die
	# todo: cramfs/squashfs modules preserve
#	cd lib/modules
#	depmod -b ../.. *
	find . -print | cpio --quiet -o -H newc -F "${S}/initrd-${KV}.img"
	cd "${S}" || die
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

cfg_use(){
	if use $1; then
		cfg y $2
	else
		cfg n $2
	fi
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
	cfg y EXT2_FS
	if use compress; then
		if squashfs_enabled; then
			cfg y SQUASHFS
		else
			cfg y CRAMFS
		fi
		cfg y BLK_DEV_LOOP
		cfg y BLK_DEV_CRYPTOLOOP
	fi
	use debug || sed -i -e 's/^CONFIG.*_DEBUG=.*//' .config
	cfg_use ipv6 IPV6
	yes '' 2>/dev/null | mmake oldconfig >/dev/null
}
