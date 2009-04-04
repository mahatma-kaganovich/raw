source "${PORTDIR}/eclass/kernel-2.eclass"

if [[ ${ETYPE} == sources ]]; then

IUSE="${IUSE} build-kernel debug custom-cflags compress integrated ipv6 netboot"
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
    KERNEL_CONFIG="KALLSYMS_EXTRA_PASS DMA_ENGINE USB_STORAGE_[\w\d]+
	USB_LIBUSUAL -BLK_DEV_UB
	NET_RADIO PNP PNP_ACPI PARPORT_PC_FIFO PARPORT_1284 NFTL_RW
	PMC551_BUGFIX CISS_SCSI_TAPE CDROM_PKTCDVD_WCACHE
	SCSI_SCAN_ASYNC IOSCHED_DEADLINE DEFAULT_DEADLINE SND_SEQUENCER_OSS
	SND_FM801_TEA575X_BOOL SND_AC97_POWER_SAVE SCSI_PROC_FS
	NET_VENDOR_3COM
	SYN_COOKIES [\w\d_]*_NAPI
	-CC_OPTIMIZE_FOR_SIZE
	-ARCNET -IDE -SMB_FS -DEFAULT_CFQ -DEFAULT_AS -DEFAULT_NOOP
	-SOUND_PRIME -KVM
	    -TR HOSTAP_FIRMWARE NET_PCMCIA WAN DCC4_PSISYNC
	    FDDI HIPPI VT_HW_CONSOLE_BINDING SERIAL_NONSTANDARD
	    SERIAL_8250_EXTENDED SPI"
[[ "${KERNEL_MODULES}" == "" ]] &&
    KERNEL_MODULES="drivers +fs +sound +drivers/net"
	# todo: fix genkernel default modules
#	+drivers/scsi +drivers/ata"

[[ -e "${CONFIG_ROOT}/etc/kernels/kernel.conf" ]] && source "${CONFIG_ROOT}/etc/kernels/kernel.conf"

fi

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
	einfo "Compiling kernel"
	kmake modules
	local p=""
	use netboot && p="${p} --netboot"
	local r="${TMPDIR}/tmproot"
	mkdir "${r}"
	kmake INSTALL_MOD_PATH="${r}" modules_install
	if use compress; then
		p="${p} --all-ramdisk-modules"
		[[ -e "${r}/lib/firmware" ]] && p="${p} --firmware --firmware-dir=\"${r}/lib/firmware\""
	fi
	run_genkernel ramdisk --kerneldir="${S}" --bootdir="${S}" --module-prefix="${r}" --no-mountboot ${p}
	r=`ls initramfs*-${KV}`
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
		yes '' 2>/dev/null | kmake oldconfig &>/dev/null
	fi
	kmake bzImage
}

kernel-2_src_install() {
	cd "${S}" || die
	if [[ ${ETYPE} == sources ]] && use build-kernel; then
		mkdir "${D}/boot"
		if ! use integrated; then
			insinto "/boot"
			doins "initrd-${KV}.img"
		fi
		local f
		for f in "${TMPDIR}"/tmproot/* ; do
			mv "${f}" "${D}/" || die
		done
		kmake INSTALL_PATH="${D}/boot" install
		use symlink || rm "${D}"/boot/vmlinuz &>/dev/null
		ewarn "If your /boot is not mounted, copy next files by hands:"
		ewarn `ls "${D}/boot"`
	fi
	install_universal
	[[ ${ETYPE} == headers ]] && install_headers
	[[ ${ETYPE} == sources ]] && install_sources
}

run_genkernel(){
	[[ ! -e "${TMPDIR}/genkernel-cache" ]] && cp "${ROOT}/var/cache/genkernel" "${TMPDIR}/genkernel-cache" -r
	# cpio works fine without loopback
	cp /usr/bin/genkernel "${S}" || die
	sed -i -e 's/has_loop/true/' "${S}/genkernel"
	LDFLAGS="" "${S}/genkernel" --cachedir="${TMPDIR}/genkernel-cache" --tempdir="${TMPDIR}/genkernel" --logfile="${TMPDIR}/genkernel.log" $* || die "genkernel failed"
	rm "${S}/genkernel"
}

# incompatible with 2.6.20
cramfs(){
	einfo "Converting initramfs to cramfs"
	local tmp="${TMPDIR}/ramfstmp"
	mkdir "${tmp}"
	cd "${tmp}" || die "cd failed"
	gzip -dc "${S}/initrd-${KV}.img" | cpio -i
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
	gzip -dc "${S}/initrd-${KV}.img" | cpio -i
	if squashfs_enabled; then
		mksquashfs "lib" "lib.loopfs" -all-root -no-recovery -no-progress || die
	else
		mkcramfs "lib" "lib.loopfs" || die
	fi
	sed -i -e 's%^\(mount.* / .*\)$%\1\nmount /lib.loopfs /lib -o loop%' \
		-e 's%\(umount /sys\)%umount /lib\n\1%' \
		init
	rm ${tmp}/lib/* -Rf || die
	local i
	for i in 0 1 2 3; do
		mknod -m 660 "${tmp}/dev/loop${i}" b 7 ${i}
	done
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
	local o="$2"
	local i
	( grep -P "^(?:\# )?CONFIG_${o}(?:=.*| is not set)\$" .config || echo "${o}" ) >"${TMPDIR}/cfg.tmp"
	while read i ; do
		[[ "$3" == "-"  && "${i/=}" != "${i}" ]] && continue
		i=${i#\# }
		i=${i#CONFIG_}
		i=${i/=*/}
		i=${i/ is not set/}
		sed -i -e "s/^# CONFIG_${i} is not set//" -e "s/^CONFIG_${i}=.*//" .config
		if [[ "${r}" == "n" ]]; then
			echo "# CONFIG_${i} is not set" >>.config
		elif [[ "${r}" != "-" ]]; then
			echo "CONFIG_${i}=${r}" >>.config
		fi
	done <"${TMPDIR}/cfg.tmp"
	rm "${TMPDIR}/cfg.tmp"
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
	yes '' 2>/dev/null | kmake oldconfig &>/dev/null
}

config_defaults(){
	local i i1 o m
	einfo "Configuring kernel"
	kmake defconfig >/dev/null
	for i in ${KERNEL_MODULES}; do
		einfo "Searching modules: ${i}"
		m="-"
		i1="${i}"
		i="${i#+}"
		[[ "${i1}" == "${i}" ]] || m=""
		for o in `grep -Prh "^\s*(?:menu)?config\s+.*?\n(?:[^\n]+\n)*\s*tristate" ${i} --include="Kconfig*" 2>/dev/null  | grep -P "^\s*(?:menu)?config"` ; do
			[[ "${o}" == "config" || "${o}" == "menuconfig" ]] || cfg m "${o}" "${m}"
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
	fi
	cfg_use debug "(?:[^\n]*_)?DEBUG(?:_[^\n]*)?"
	cfg_use ipv6 IPV6
	yes '' 2>/dev/null | kmake oldconfig >/dev/null
}

kmake(){
	# DESTDIR="${D}"
	emake ARCH=$(tc-arch-kernel) ABI=${KERNEL_ABI} $* || die
}
