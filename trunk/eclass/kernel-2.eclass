inherit flag-o-matic
source "${PORTDIR}/eclass/kernel-2.eclass"

if [[ ${ETYPE} == sources ]]; then

IUSE="${IUSE} build-kernel debug custom-cflags pnp compressed integrated ipv6 netboot nls unicode +acl minimal"
DEPEND="${DEPEND}
	build-kernel? (
		sys-kernel/genkernel
		pnp? ( sys-kernel/genpnprd )
		compressed? ( sys-kernel/genpnprd )
	) "

[[ "${KERNEL_CONFIG}" == "" ]] &&
    KERNEL_CONFIG="KALLSYMS_EXTRA_PASS DMA_ENGINE USB_STORAGE_[\w\d]+
	-X86_GENERIC MTRR_SANITIZER IA32_EMULATION LBD
	GFS2_FS_LOCKING_DLM NTFS_RW
	X86_BIGSMP X86_32_NON_STANDARD X86_X2APIC
	MICROCODE_INTEL MICROCODE_AMD
	CALGARY_IOMMU AMD_IOMMU
	SPARSEMEM_MANUAL MEMTEST [\d\w_]*FS_XATTR
	PARAVIRT_GUEST VMI KVM_CLOCK KVM_GUEST
	USB_LIBUSUAL -BLK_DEV_UB USB_EHCI_ROOT_HUB_TT USB_EHCI_TT_NEWSCHED USB_SISUSBVGA_CON
	KEYBOARD_ATKBD
	CRC_T10DIF
	-VGACON_SOFT_SCROLLBACK -DRM FB_BOOT_VESA_SUPPORT FRAMEBUFFER_CONSOLE_ROTATION
	IKCONFIG_PROC IKCONFIG EXPERIMENTAL
	NET_RADIO PNP PNP_ACPI PARPORT_PC_FIFO PARPORT_1284 NFTL_RW
	PMC551_BUGFIX CISS_SCSI_TAPE CDROM_PKTCDVD_WCACHE
	SCSI_SCAN_ASYNC IOSCHED_DEADLINE DEFAULT_DEADLINE SND_SEQUENCER_OSS
	SND_FM801_TEA575X_BOOL SND_AC97_POWER_SAVE SCSI_PROC_FS
	NET_VENDOR_3COM
	SYN_COOKIES [\w\d_]*_NAPI
	[\w\d_]*_EDID FB_[\w\d_]*_I2C FB_MATROX_[\w\d_]* FB_ATY_[\w\d_]*
	FB_[\w\d_]*_ACCEL -FB_HGA_ACCEL FB_SIS_300 FB_SIS_315 FB_GEOGE
	FB_MB862XX_PCI_GDC
	-CC_OPTIMIZE_FOR_SIZE
	-ARCNET -IDE -SMB_FS -DEFAULT_CFQ -DEFAULT_AS -DEFAULT_NOOP
	-SOUND_PRIME CPIOLIB ISCSI_IBFT_FIND EXT4DEV_COMPAT LDM_PARTITION
	NET_SCHED GACT_PROB IP_FIB_TRIE
	+TCP_CONG_[\w\d_]+ TCP_CONG_ADVANCED TCP_CONG_CUBIC TCP_CONG_BIC TCP_CONG_YEAH
	BT_RFCOMM_TTY BT_HCIUART_H4 BT_HCIUART_BCSP BT_HCIUART_LL
	IRDA_ULTRA IRDA_CACHE_LAST_LSAP IRDA_FAST_RR DONGLE
	ISDN
	-SECURITY_FILE_CAPABILITIES -SECURITY
	    -TR HOSTAP_FIRMWARE NET_PCMCIA WAN DCC4_PSISYNC
	    FDDI HIPPI VT_HW_CONSOLE_BINDING SERIAL_NONSTANDARD
	    SERIAL_8250_EXTENDED SPI
	TIPC_ADVANCED NETFILTER_ADVANCED NET_IPGRE_BROADCAST
	IP_VS_PROTO_[\d\w_]*
	KERNEL_GZIP KERNEL_BZIP2 KERNEL_LZMA"
[[ "${KERNEL_MODULES}" == "" ]] &&
    KERNEL_MODULES="+."

[[ -e "${CONFIG_ROOT}/etc/kernels/kernel.conf" ]] && source "${CONFIG_ROOT}/etc/kernels/kernel.conf"

fi

BDIR="${WORKDIR}/build"

kernel-2_src_compile() {
	cd "${S}"
	fixes
	[[ ${ETYPE} == headers ]] && compile_headers
	[[ ${ETYPE} == sources ]] || return
	local cflags="${KERNEL_CFLAGS}"
	if use custom-cflags; then
		filter-flags "-march=*" "-msse*" -mmmx -m3dnow
		cflags="${CFLAGS} ${cflags}"
	fi
	[[ -n ${cflags} ]] && sed -i -e "s/^\(KBUILD_CFLAGS.*-O2\)/\1 ${cflags}/g" Makefile
	use build-kernel || return
	config_defaults
	einfo "Compiling kernel"
	kmake all
	local p=""
	use netboot && p="${p} --netboot"
	[[ -e "${BDIR}" ]] || mkdir "${BDIR}"
	kmake INSTALL_MOD_PATH="${BDIR}" modules_install
	local r="${BDIR}/lib/modules/${KV}"
	rm "${r}"/build "${r}"/source
	cd "${WORKDIR}"
	local i
	for i in linux*${KV} ; do
		ln -s "../../../usr/src/${i}" "${r}"/build
		ln -s "../../../usr/src/${i}" "${r}"/source
	done
	cd "${S}"
	if use pnp || use compressed; then
		p="${p} --all-ramdisk-modules"
		[[ -e "${BDIR}/lib/firmware" ]] && p="${p} --firmware --firmware-dir=\"${BDIR}/lib/firmware\""
	fi
	run_genkernel ramdisk "--kerneldir=\"${S}\" --bootdir=\"${S}\" --module-prefix=\"${BDIR}\" --no-mountboot ${p}"
	r=`ls initramfs*-${KV}`
	rename "${r}" "initrd-${KV}.img" "${r}" || die "initramfs rename failed"
	if use pnp; then
		sh "${ROOT}/usr/share/genpnprd/genpnprd" "${S}/initrd-${KV}.img"
	elif use compressed; then
		sh "${ROOT}/usr/share/genpnprd/genpnprd" "${S}/initrd-${KV}.img" nopnp
	fi
	if use integrated; then
		cfg - CONFIG_INITRAMFS_SOURCE
		cfg - CONFIG_INITRAMFS_ROOT_UID
		cfg - CONFIG_INITRAMFS_ROOT_GID
		gzip -dc  "initrd-${KV}.img" >"initrd-${KV}.cpio" || die
		rm "initrd-${KV}.img"
		echo "CONFIG_INITRAMFS_SOURCE=\"${S}/initrd-${KV}.cpio\"\nCONFIG_INITRAMFS_ROOT_UID=0\nCONFIG_INITRAMFS_ROOT_GID=0" >>.config
		yes '' 2>/dev/null | kmake oldconfig &>/dev/null
		kmake bzImage
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
		local f
		rm ${BDIR}/lib/firmware -Rf
		mv "${BDIR}"/* "${D}/" || die
		kmake INSTALL_PATH="${D}/boot" install
		rm "${D}"/boot/vmlinuz -f &>/dev/null
		[[ ${SLOT} == 0 ]] && use symlink && dosym vmlinuz-${KV} vmlinuz
		if [[ "${SLOT}" != "${PVR}" ]] ; then
			dosym vmlinuz-${KV} /boot/vmlinuz-${SLOT}
			dosym linux-${KV_FULL} /usr/src/linux-${SLOT}
			use integrated || dosym initrd-${KV}.img /usr/src/initrd-${SLOT}.img
		fi
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
#	LDFLAGS="" ARCH="$(arch)" ABI="${KERNEL_ABI}" "${S}/genkernel" --cachedir="${TMPDIR}/genkernel-cache" --tempdir="${TMPDIR}/genkernel" --logfile="${TMPDIR}/genkernel.log" --utils-arch=$(tc-ninja_magic_to_arch) --arch-override=$(arch) --postclear $* || die "genkernel failed"
	LDFLAGS="" "${S}/genkernel" --cachedir="${TMPDIR}/genkernel-cache" --tempdir="${TMPDIR}/genkernel" --logfile="${TMPDIR}/genkernel.log" --arch-override=$(arch) --postclear $* || die "genkernel failed"
	rm "${S}/genkernel"
}

cfg(){
	local r="$1"
	local o="$2"
	local i i1 i2
	local tmp="${TMPDIR}/pnp.tmp"
	while [[ -e ${tmp} ]] ; do
		tmp="${tmp}.1"
	done
	( grep -P "^(?:\# )?CONFIG_${o}(?:=.*| is not set)\$" .config || echo "${o}" ) >$tmp
	while read i ; do
		i1="${i}"
		i=${i#\# }
		i=${i#CONFIG_}
		i=${i/=*/}
		i=${i/ is not set/}
		if [[ "${r}" == "n" ]] && grep -q "^CONFIG_${i}=" .config ; then
			for i2 in `grep -Prh "^\s*(?:menu)?config\s+.*?\n(?:[^\n]+\n)*\s*select ${i}\n" . --include="Kconfig*" 2>/dev/null |grep -P "^\s*(?:menu)?config"` ; do
				if [[ "${i2}" != "config" && "${i2}" != "menuconfig" ]] ; then
					einfo "CONFIG: -$i -> -$i2"
					cfg $r $i2
				fi
			done
		fi
		sed -i -e "/^# CONFIG_${i} is not set/d" -e "/^CONFIG_${i}=.*/d" .config
		[[ "$3" == "-"  ]] && grep -P "^CONFIG_${i}=" .config.old >>.config && continue
		[[ "$3" == "--"  ]] && grep -P "^(?:CONFIG_${i}=)|(?:${i} is not set)" .config.old >>.config && continue
		if [[ "${r}" == "n" ]]; then
			echo "# CONFIG_${i} is not set" >>.config
		elif [[ "${r}" != "-" ]]; then
			echo "CONFIG_${i}=${r}" >>.config
		fi
	done <$tmp
	rm $tmp
}

cfg_use(){
	local i u="$1"
	shift
	for i in $* ; do
		if use $u ; then
			cfg y $i
		else
			cfg n $i
		fi
	done
}

setconfig(){
	local i o
	cfg y EXT2_FS
	if use pnp || use compressed; then
		cfg m SQUASHFS
		cfg m CRAMFS
		cfg m BLK_DEV_LOOP
	fi
	cfg_use debug "(?:[^\n]*_)?DEBUG(?:_[^\n]*)?" FRAME_POINTER OPTIMIZE_INLINING FUNCTION_TRACER OPROFILE KPROBES X86_VERBOSE_BOOTUP PROFILING MARKERS
	cfg_use ipv6 IPV6
	cfg_use acl "[\d\w_]*_ACL"
	use nls && cfg y "[\d\w_]*_NLS"
	use unicode && cfg y NLS_UTF8
	for i in ${KERNEL_CONFIG}; do
		o="y ${i}"
		o="${o/y +/m }"
		o="${o/y -/n }"
		o="${o/y ~/- }"
		cfg ${o}
	done
	yes '' 2>/dev/null | kmake oldconfig >/dev/null
}

config_defaults(){
	local i i1 o m xx
	einfo "Configuring kernel"
	if use minimal; then
		KERNEL_CONFIG="${KERNEL_CONFIG} -IP_ADVANCED_ROUTER -NETFILTER ~IP_FIB_TRIE"
		KERNEL_MODULES="${KERNEL_MODULES} -net +net/sched"
	fi
	kmake defconfig >/dev/null
	cp .config .config.old
#	setconfig
	for i in ${KERNEL_MODULES}; do
		einfo "Searching modules: ${i}"
		m="-"
		i1="${i}"
		i="${i#+}"
		if [[ "${i1}" == "${i}" ]] ; then
			i="${i#-}"
			[[ "${i1}" == "${i}" ]] || m="--"
		else
			m=""
		fi
		for o in `grep -Prh "^\s*(?:menu)?config\s+.*?\n(?:[^\n]+\n)*\s*tristate" ${i} --include="Kconfig*" 2>/dev/null  | grep -P "^\s*(?:menu)?config"` ; do
			[[ "${o}" == "config" || "${o}" == "menuconfig" ]] || cfg m "${o}" "${m}"
		done
	done
	echo -e "KERNEL_CONFIG=\"${KERNEL_CONFIG}\""
	setconfig
	setconfig
	rm .config.old
}

arch(){
	local arch=$(tc-ninja_magic_to_arch)
	case ${arch} in
		amd64) echo "x86_64"
		;;
		*) echo "${arch}"
		;;
	esac
}

kmake(){
	emake ARCH=$(arch) $* || die
}

fixes(){
	local i
	einfo "Fixing compats"
	# glibc 2.8+
	for i in "${S}/scripts/mod/sumversion.c" ; do
		[[ -e "${i}" ]] || continue
		grep -q "<limits.h>" "${i}" || sed -i -e 's/#include <string.h>/\n#include <string.h>\n#include <limits.h>/' "${i}"
	done
	# gcc 4.2+
	sed -i -e 's/_proxy_pda = 0/_proxy_pda = 1/g' "${S}"/arch/*/kernel/vmlinux.lds.S
	[[ -e "${S}"arch/x86_64/kernel/x8664_ksyms.c ]] && grep -q "_proxy_pda" "${S}"arch/x86_64/kernel/x8664_ksyms.c || echo "EXPORT_SYMBOL(_proxy_pda);" >>arch/x86_64/kernel/x8664_ksyms.c
	use unicode && sed -i -e 's/sbi->options\.utf8/1/g' fs/fat/dir.c
	use pnp || return
	einfo "Fixing modules hardware info exports (forced mode, waiting for bugs!)"
	sh "${ROOT}/usr/share/genpnprd/modulesfix" "${S}" f
}
