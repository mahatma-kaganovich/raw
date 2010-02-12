inherit flag-o-matic
source "${PORTDIR}/eclass/kernel-2.eclass"

if [[ ${ETYPE} == sources ]]; then

IUSE="${IUSE} build-kernel debug custom-cflags pnp compressed integrated ipv6
	netboot nls unicode +acl minimal selinux custom-arch
	+kernel-drm +kernel-alsa +sources fbcon staging pnponly"
DEPEND="${DEPEND}
	pnp? ( sys-kernel/genpnprd )
	build-kernel? (
		>=sys-kernel/genkernel-3.4.10.903
		compressed? ( sys-kernel/genpnprd )
		kernel-drm? ( !x11-base/x11-drm )
		kernel-alsa? ( !media-sound/alsa-driver )
	) "

: ${KERNEL_CONFIG:="KALLSYMS_EXTRA_PASS DMA_ENGINE USB_STORAGE_[\w\d]+
	PREEMPT_NONE
	-X86_GENERIC MTRR_SANITIZER IA32_EMULATION LBD
	GFS2_FS_LOCKING_DLM NTFS_RW
	X86_BIGSMP X86_32_NON_STANDARD X86_X2APIC INTR_REMAP
	MICROCODE_INTEL MICROCODE_AMD
	ASYNC_TX_DMA NET_DMA DMAR INTR_REMAP CONFIG_BLK_DEV_INTEGRITY
	AMD_IOMMU
	SPARSEMEM_MANUAL MEMTEST [\d\w_]*FS_XATTR
	VMI KVM_CLOCK KVM_GUEST XEN
	USB_LIBUSUAL -BLK_DEV_UB USB_EHCI_ROOT_HUB_TT USB_EHCI_TT_NEWSCHED USB_SISUSBVGA_CON
	KEYBOARD_ATKBD
	CRC_T10DIF
	-VGACON_SOFT_SCROLLBACK FB_BOOT_VESA_SUPPORT FRAMEBUFFER_CONSOLE_ROTATION
	IKCONFIG_PROC IKCONFIG EXPERIMENTAL
	NET_RADIO PNP_ACPI PARPORT_PC_FIFO PARPORT_1284 NFTL_RW
	PMC551_BUGFIX CISS_SCSI_TAPE CDROM_PKTCDVD_WCACHE
	SCSI_SCAN_ASYNC IOSCHED_DEADLINE DEFAULT_DEADLINE SND_SEQUENCER_OSS
	SND_FM801_TEA575X_BOOL SND_AC97_POWER_SAVE SCSI_PROC_FS SCSI_FLASHPOINT
	NET_VENDOR_[\w\d_]* NET_POCKET
	SYN_COOKIES [\w\d_]*_NAPI
	[\w\d_]*_EDID FB_[\w\d_]*_I2C FB_MATROX_[\w\d_]* FB_ATY_[\w\d_]*
	FB_[\w\d_]*_ACCEL -FB_HGA_ACCEL FB_SIS_300 FB_SIS_315 FB_GEODE
	FB_MB862XX_PCI_GDC
	-CC_OPTIMIZE_FOR_SIZE
	-ARCNET -SMB_FS -DEFAULT_CFQ -DEFAULT_AS -DEFAULT_NOOP
	-SOUND_PRIME GPIO EZX_PCAP MFD_SM501_GPIO SSB_PCMCIAHOST
	ISCSI_IBFT_FIND EXT4DEV_COMPAT LDM_PARTITION
	SCSI_FC_TGT_ATTRS SCSI_SAS_ATA SCSI_SRP_TGT_ATTRS
	MEGARAID_NEWGEN SCSI_EATA_TAGGED_QUEUE SCSI_EATA_LINKED_COMMANDS
	SCSI_GENERIC_NCR53C400 IBMMCA_SCSI_ORDER_STANDARD
	SCSI_U14_34F_TAGGED_QUEUE SCSI_U14_34F_LINKED_COMMANDS
	SCSI_MULTI_LUN
	GACT_PROB IP_FIB_TRIE
	TCP_CONG_CUBIC TCP_CONG_BIC TCP_CONG_YEAH
	BT_RFCOMM_TTY BT_HCIUART_H4 BT_HCIUART_BCSP BT_HCIUART_LL
	IRDA_ULTRA IRDA_FAST_RR DONGLE
	-SECURITY_FILE_CAPABILITIES
	    HOSTAP_FIRMWARE DCC4_PSISYNC
	    FDDI HIPPI VT_HW_CONSOLE_BINDING SERIAL_NONSTANDARD
	    SERIAL_8250_EXTENDED
	TIPC_ADVANCED NET_IPGRE_BROADCAST
	IP_VS_PROTO_[\d\w_]*
	KERNEL_LZMA
	ISA MCA MCA_LEGACY EISA NET_ISA PCI PCI_LEGACY
	PCIEASPM CRYPTO_DEV_HIFN_795X_RNG PERF_COUNTERS
	X86_SPEEDSTEP_RELAXED_CAP_CHECK
	SLIP_COMPRESSED SLIP_SMART NET_FC -LOGO_LINUX_[\w\d]*
	-8139TOO_PIO
	-COMPAT_BRK -COMPAT_VDSO
	NET_CLS_IND
	-STAGING_EXCLUDE_BUILD DRM_RADEON_KMS DRM_NOUVEAU_BACKLIGHT
	===bugs:
	-TR -RADIO_RTRACK
	===kernel.conf:
	"}
: ${KERNEL_MODULES:="+."}
# prefer: "-." - defconfig, "." - defconfig for "y|m", "+." - Kconfig/oldconfig
: ${KERNEL_DEFAULTS:="."}

PROVIDE="sources? ( virtual/linux-sources )
	!sources? ( virtual/linux-kernel )
	kernel-alsa? ( virtual/alsa )"

[[ -e "${CONFIG_ROOT}/etc/kernels/kernel.conf" ]] && source "${CONFIG_ROOT}/etc/kernels/kernel.conf"

fi

BDIR="${WORKDIR}/build"

set_kv(){
	local v="$1"
	KV="${v}"
	EXTRAVERSION="${KV##*-}"
	CKV="${KV%%-*}"
	OKV="${CKV}"
	KV_FULL="${KV}"
	KV_MAJOR=${v%%.*}
	v=${v#*.}
	KV_MINOR=${v%%.*}
	v=${v#*.}
	KV_PATCH=${v%%-*}
	KV_EXTRA=${v#*-}
}

get_v(){
	grep -P "^$1[ 	]*=.*$" "${S}"/Makefile | sed -e 's%^.*= *%%'
}

check_kv(){
	REAL_KV="$(get_v VERSION).$(get_v PATCHLEVEL).$(get_v SUBLEVEL)$(get_v EXTRAVERSION)"
	[ -z "${KV}" ] && set_kv ${REAL_KV}
}

kernel-2_src_compile() {
	check_kv
	cd "${S}"
	fixes
	[[ ${ETYPE} == headers ]] && compile_headers
	[[ ${ETYPE} == sources ]] || return
	local cflags="${KERNEL_CFLAGS}"
	if use custom-cflags; then
		use custom-arch || filter-flags "-march=*"
		filter-flags "-msse*" -mmmx -m3dnow
		cflags="${CFLAGS} ${cflags}"
	fi
	[[ -n ${cflags} ]] && sed -i -e "s/^\(KBUILD_CFLAGS.*-O.\)/\1 ${cflags}/g" Makefile
	use build-kernel || return
	config_defaults
	einfo "Compiling kernel"
	kmake all
	local p=""
	use netboot && p="${p} --netboot"
	[[ -e "${BDIR}" ]] || mkdir "${BDIR}"
	kmake INSTALL_MOD_PATH="${BDIR}" modules_install
	local r="${BDIR}/lib/modules/${REAL_KV}"
	rm "${r}"/build "${r}"/source
	cd "${WORKDIR}"
	local i
	for i in linux*${KV_FULL} ; do
		use sources || continue
		[[ -e "${i}" ]] || continue
		ln -s "../../../usr/src/${i}" "${r}"/build
		ln -s "../../../usr/src/${i}" "${r}"/source
	done
	cd "${S}"
	if use pnp || use compressed; then
		p="${p} --all-ramdisk-modules"
		[[ -e "${BDIR}/lib/firmware" ]] && p="${p} --firmware --firmware-dir=\"${BDIR}/lib/firmware\""
	fi
	run_genkernel ramdisk "--kerneldir=\"${S}\" --bootdir=\"${S}\" --module-prefix=\"${BDIR}\" --no-mountboot ${p}"
	r=`ls initramfs*-${REAL_KV}`
	rename "${r}" "initrd-${REAL_KV}.img" "${r}" || die "initramfs rename failed"
	einfo "Preparing boot image"
	bash "${ROOT}/usr/share/genpnprd/genpnprd" "${S}/initrd-${REAL_KV}.img" "$( (use !pnp && echo nopnp)||(use pnponly && echo pnponly) )" "${TMPDIR}"/overlay-rd || die
	# integrated: do not compress twice;
	# others: +~700K, but faster boot & less RAM to uncompress.
	# "integrated" still minimal
	( use pnp || use compressed || use integrated ) &&
		gzip -dc "initrd-${REAL_KV}.img" >"initrd-${REAL_KV}.cpio" &&
		rm "initrd-${REAL_KV}.img"
	if use integrated; then
		cfg "\"initrd-${REAL_KV}.cpio\"" INITRAMFS_SOURCE
		cfg 0 INITRAMFS_ROOT_UID
		cfg 0 INITRAMFS_ROOT_GID
		cfg y INITRAMFS_COMPRESSION_NONE
		yes '' 2>/dev/null | kmake oldconfig &>/dev/null
		kmake bzImage
	else
		[[ -e "initrd-${REAL_KV}.cpio" ]] && rename .cpio .img "initrd-${REAL_KV}.cpio"
	fi
}

kernel-2_src_install() {
	check_kv
	cd "${S}" || die
	if [[ ${ETYPE} == sources ]] && use build-kernel; then
		mkdir "${D}/boot"
		if ! use integrated; then
			insinto "/boot"
			doins "initrd-${REAL_KV}.img"
		fi
		local f f1
		rm ${BDIR}/lib/firmware -Rf
		mv "${BDIR}"/* "${D}/" || die
		kmake INSTALL_PATH="${D}/boot" install
		for f in vmlinuz System.map config ; do
			f1="${D}/boot/${f}"
			if [[ -e "${f1}" ]] ; then
				mv "$(readlink -f ${f1})" "${f1}-${REAL_KV}"
				rm "${f1}" -f &>/dev/null
			fi
			[[ ${SLOT} == 0 ]] && use symlink && dosym "${f}-${REAL_KV}" "${f}"
			[[ "${SLOT}" != "${PVR}" ]] && dosym "${f}-${REAL_KV}" /boot/"${f}-${SLOT}"
		done
		f="${D}/boot/config-${REAL_KV}"
		[[ -e "$f" ]] || cp "${S}/.config" "$f"
		if [[ "${SLOT}" != "${PVR}" ]] ; then
			use sources && dosym linux-${KV_FULL} /usr/src/linux-${SLOT}
			use integrated || dosym initrd-${REAL_KV}.img /boot/initrd-${SLOT}.img
		fi
		if use sources ; then
			find "${S}" -name "*.cmd" | while read f ; do
				sed -i -e 's%'"${S}"'%/usr/src/linux-'"${REAL_KV}"'%g' ${f}
			done
		else
			cd "${WORKDIR}"
			rm "${S}" -Rf
		fi
		ewarn "If your /boot is not mounted, copy next files by hands:"
		ewarn `ls "${D}/boot"`
	fi
	install_universal
	[[ ${ETYPE} == headers ]] && install_headers
	[[ ${ETYPE} == sources ]] && install_sources
}

kernel-2_pkg_setup() {
	if kernel_is 2 4; then
		if [ "$( gcc-major-version )" -eq "4" ] ; then
			echo
			ewarn "Be warned !! >=sys-devel/gcc-4.0.0 isn't supported with linux-2.4!"
			ewarn "Either switch to another gcc-version (via gcc-config) or use a"
			ewarn "newer kernel that supports gcc-4."
			echo
			ewarn "Also be aware that bugreports about gcc-4 not working"
			ewarn "with linux-2.4 based ebuilds will be closed as INVALID!"
			echo
			epause 10
		fi
	fi

	ABI="${KERNEL_ABI}"
	[[ ${ETYPE} == headers ]] && setup_headers
	[[ ${ETYPE} == sources ]] || return
	if use build-kernel; then
		# ldd give false sandbox dependences in other place
		einfo "Generating boot image overlay (if configured)"
		local i="${TMPDIR}/overlay-rd"
		mkdir "${i}"
		bash "${ROOT}/usr/share/genpnprd/genpkgrd" "${i}" "${KERNEL_IMAGE_FILES}" "${KERNEL_IMAGE_FILES2}" "${KERNEL_IMAGE_PACKAGES}" || die
	fi
	echo ">>> Preparing to unpack ..."
}

run_genkernel(){
	[[ ! -e "${TMPDIR}/genkernel-cache" ]] && cp "${ROOT}/var/cache/genkernel" "${TMPDIR}/genkernel-cache" -r
	# cpio works fine without loopback, but may panish sandbox
	cp /usr/bin/genkernel "${S}" || die
	sed -i -e 's/has_loop/true/' "${S}/genkernel"
	# gentoo arch are weirdous
	local a="$(arch)"
	case ${a} in
	i386) a="x86" ;;
	esac
	LDFLAGS="${KERNEL_GENKERNEL_LDFLAGS}" "${S}/genkernel" \
		--cachedir="${TMPDIR}/genkernel-cache" \
		--tempdir="${TMPDIR}/genkernel" \
		--logfile="${TMPDIR}/genkernel.log" \
		--arch-override=${a} \
		--utils-arch=${a} --utils-cross-compile=${CTARGET:-${CHOST}}- \
		--postclear $* ${KERNEL_GENKERNEL} || die "genkernel failed"
	rm "${S}/genkernel"
}

grep_kconfig(){
	local c="^[ 	]*$1[ 	]+"
	local t="$2"
	local x="$3"
	local cfgl="\n(?:[ 	][^\n]*\n|\n)*"
	[[ -n "${t}" ]] && t="[ 	]*${t}(?:[ 	][^\n]*)?"
	[[ -n "${x}" ]] && [[ -n "${t}" ]] && t="${t}${cfgl}"
	grep -Prh "${c}.*?${cfgl}${t}${x}\$" "$4" --include="Kconfig*" 2>/dev/null | grep -P "${c}"
}

cfg(){
	local o="${2%%=*}"
	local v="${2#*=}"
	[[ "$v" == "$2" ]] && v="$1"
	local i i1 i2 i3 l
	( grep -P "^(?:\# )?CONFIG_${o}(?:=.*| is not set)\$" .config || echo "${o}" ) | while read i1 ; do
		i=${i1#\# }
		i=${i#CONFIG_}
		i=${i%%=*}
		i=${i%% *}
		[ "${cfg_exclude// $i }" == "${cfg_exclude}" ] || continue
		case "$3" in
		-) l=$( grep -P "^(?:CONFIG_${i}=)|(?:# CONFIG_${i} is not set)" .config.def ) ;;
		~) l=$( grep -P "^CONFIG_${i}=" .config.def ) ;;
		*) l="" ;;
		esac
		[[ -z "${l}" ]] && case "$1" in
		n)
			if [[ "${i1}" == "CONFIG_${i}="* ]] ; then
				grep_kconfig "(?:menu)?config" "" "[ 	]*select[ 	]+${i}" . | while read i3 i2 ; do
					einfo "CONFIG: -$i -> -$i2"
					cfg "$1" "$i2"
				done
			fi
			l="# CONFIG_${i} is not set"
		;;
		-) l="" ;;
		*) l="CONFIG_${i}=${v}" ;;
		esac
		echo "${i}" >>.config.set
		[[ "${i1}" != "${i}" ]] && sed -i -e "/^# CONFIG_${i} is not set/d" -e "/^CONFIG_${i}=.*/d" .config
		echo "${l}" >>.config
	done
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

cfg_loop(){
	grep "CONFIG" .config >$1
#	if diff -qN $1 $2 >/dev/null ; then
	if cmp -s $1 $2 ; then
		rm $1 $2
		return 1
	else
		cp $1 $2
		return 0
	fi
}

setconfig(){
	einfo "Applying KERNEL_CONFIG"
	local i o
	cfg y EXT2_FS
	if use pnp || use compressed; then
		cfg m SQUASHFS
		cfg m CRAMFS
		cfg m BLK_DEV_LOOP
	fi
	local cfg_exclude=" HAVE_DMA_API_DEBUG "
	cfg_use debug "(?:[^\n]*_)?DEBUG(?:_[^\n]*)?" FRAME_POINTER OPTIMIZE_INLINING FUNCTION_TRACER OPROFILE KPROBES X86_VERBOSE_BOOTUP PROFILING MARKERS
	if ! use debug ; then
		cfg y STRIP_ASM_SYMS
		cfg n INPUT_EVBUG
	fi
	local cfg_exclude=
	cfg_use ipv6 IPV6
	cfg_use acl "[\d\w_]*_ACL"
	cfg_use selinux "[\d\w_]*FS_SECURITY SECURITY SECURITY_NETWORK SECURITY_SELINUX SECURITY_SELINUX_BOOTPARAM"
	use nls && cfg y "[\d\w_]*_NLS"
	use unicode && cfg y NLS_UTF8
	if use kernel-drm ; then
		cfg m DRM
	else
		cfg n DRM
	fi
	cfg_use kernel-alsa SND
	# framebuffer enabled anymore, but "fbcon" support for more devices, exclude [external] nouveau drm
	if use fbcon; then
		cfg y FB
		cfg y FRAMEBUFFER_CONSOLE
		cfg y FB_BOOT_VESA_SUPPORT
		cfg y "LOGO_LINUX_[\w\d]*"
	else
		cfg n FB_UVESA
	fi
	for i in ${KERNEL_CONFIG}; do
		o="y ${i}"
		o="${o/y +/m }"
		o="${o/y -/n }"
		o="${o/y ~/- }"
		cfg ${o}
	done
	for i in ${!KERNEL_CONFIG_@} ; do
		cfg "${!i}" "${i#KERNEL_CONFIG_}"
	done
}

_i_m(){
	einfo "Configuring $1: ${i}"
	case "${i}" in
	-*|+*|~*)
		m="${i:0:1}"
		i="${i:1}"
	;;
	*)
		# set if undef
		m="~"
	;;
	esac
}

config_defaults(){
	local i i1 o m x
	einfo "Configuring kernel"
	echo -e "KERNEL_CONFIG=\"${KERNEL_CONFIG}\""
	if use minimal; then
		KERNEL_CONFIG="${KERNEL_CONFIG} -IP_ADVANCED_ROUTER -NETFILTER ~IP_FIB_TRIE -NET_CLS_IND"
		KERNEL_MODULES="${KERNEL_MODULES} -net +net/sched +net/irda +net/bluetooth"
	fi
	# staging submenu will be opened, but no auto-m
	use staging || KERNEL_MODULES="${KERNEL_MODULES} -drivers/staging"
	touch .config.set
	kmake defconfig >/dev/null
	cp .config .config.def
    while cfg_loop .config.{3,4} ; do
	for i in ${KERNEL_DEFAULTS}; do
		_i_m "menu defaults"
		grep_kconfig "menuconfig" "bool" "" ${i} | while read i1 o ; do
			cfg y "${o}" "${m}"
		done
	done
	for i in ${KERNEL_MODULES}; do
		_i_m "modules"
		x='m'
		[[ "${m}" == '-' ]] && x='-'
		grep_kconfig "(?:menu)?config" "tristate" "" ${i} | while read i1 o ; do
			cfg "${x}" "${o}" "${m}"
		done
	done
	for i in ${KERNEL_DEFAULTS}; do
		_i_m "defaults"
		[[ "${m}" == "-" ]] ||
		grep_kconfig "config" "bool" "" ${i} | while read i1 o ; do
			grep -q "^${o}\$" .config.set && continue
			[[ -z "${m}" ]] && sed -i -e "/^CONFIG_${o}=.*/d" .config .config.def
			sed -i -e "/^# CONFIG_${o} is not set/d" .config .config.def
		done
		grep_kconfig "config" "bool" "[^\n]*If\s+unsure,\s+say\s+Y\..*" ${i} | while read i1 o ; do
			grep -q "^${o}\$" .config.set && continue
			cfg y "${o}" "${m/-/--}"
		done
	done
	while cfg_loop .config.{1,2} ; do
		setconfig
		yes '' 2>/dev/null | kmake oldconfig >/dev/null
	done
    done
    rm .config.{old,def,set}
}

arch(){
	if [[ -n "${KERNEL_ARCH}" ]] ; then
		echo "${KERNEL_ARCH}"
		return
	fi
	local h="${1:-${CTARGET:-${CHOST}}}"
	case ${h} in
		i?86*) echo "i386";;
		x86_64*) echo "x86_64";;
		*) echo "$(tc-ninja_magic_to_arch kern ${h})";;
	esac
}

kmake(){
	local o=""
	local h="${CTARGET:-${CHOST}}"
	[[ "${CBUILD}" != "${h}" ]] && o="CROSS_COMPILE=${h}-"
	emake ARCH=$(arch) $o $* ${KERNEL_MAKEOPT} || die
}

fixes(){
	local i
	einfo "Fixing compats"
	# glibc 2.8+
	for i in "${S}/scripts/mod/sumversion.c" ; do
		[[ -e "${i}" ]] || continue
		grep -q "<limits.h>" "${i}" || sed -i -e 's/#include <string.h>/\n#include <string.h>\n#include <limits.h>/' "${i}"
	done
	# glibs 2.10+
	sed -i -e 's/getline/get_line/g' "${S}"/scripts/unifdef.c
	# gcc 4.2+
	sed -i -e 's/_proxy_pda = 0/_proxy_pda = 1/g' "${S}"/arch/*/kernel/vmlinux.lds.S
	[[ -e "${S}"arch/x86_64/kernel/x8664_ksyms.c ]] && ( grep -q "_proxy_pda" "${S}"arch/x86_64/kernel/x8664_ksyms.c || echo "EXPORT_SYMBOL(_proxy_pda);" >>arch/x86_64/kernel/x8664_ksyms.c )
	# unicode by default/only for fat
	use unicode && sed -i -e 's/sbi->options\.utf8/1/g' fs/fat/dir.c
	# custom-arch
	use custom-arch && sed -i -e 's/-march=[a-z0-9\-]*//g' -e 's/-mtune=[a-z0-9\-]*//g' arch/*/Makefile*
	# prevent to build twice
#	sed -i -e 's%-I$(srctree)/arch/$(hdr-arch)/include%%' Makefile
	# pnp
	use pnp || return
	einfo "Fixing modules hardware info exports (forced mode, waiting for bugs!)"
	sh "${ROOT}/usr/share/genpnprd/modulesfix" "${S}" f
}

