source "${PORTDIR}/eclass/kernel-2.eclass"

if [[ ${ETYPE} == sources ]]; then

IUSE="${IUSE} build-kernel debug custom-cflags pnp compressed integrated ipv6 netboot"
DEPEND="${DEPEND}
	build-kernel? (
		pnp? ( sys-kernel/genpnprd )
		compressed? ( sys-kernel/genpnprd )
	) "
# cramfs = compat

[[ "${KERNEL_CONFIG}" == "" ]] &&
    KERNEL_CONFIG="KALLSYMS_EXTRA_PASS DMA_ENGINE USB_STORAGE_[\w\d]+
	USB_LIBUSUAL -BLK_DEV_UB USB_EHCI_ROOT_HUB_TT USB_EHCI_TT_NEWSCHED USB_SISUSBVGA_CON
	KEYBOARD_ATKBD
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
	-SOUND_PRIME -KVM
	    -TR HOSTAP_FIRMWARE NET_PCMCIA WAN DCC4_PSISYNC
	    FDDI HIPPI VT_HW_CONSOLE_BINDING SERIAL_NONSTANDARD
	    SERIAL_8250_EXTENDED SPI"
[[ "${KERNEL_MODULES}" == "" ]] &&
    KERNEL_MODULES="+drivers +fs +sound +crypt"
#    KERNEL_MODULES="drivers +fs +sound +drivers/net +crypt"
#    KERNEL_MODULES=". +drivers +fs +sound +crypt"

[[ -e "${CONFIG_ROOT}/etc/kernels/kernel.conf" ]] && source "${CONFIG_ROOT}/etc/kernels/kernel.conf"

fi

BDIR="${WORKDIR}/build"

kernel-2_src_compile() {
	cd "${S}"
	fixes
	[[ ${ETYPE} == headers ]] && compile_headers
	[[ ${ETYPE} == sources ]] || return
	if use custom-cflags; then
#		filter-flags -march=* -msse* -mmmx -m3dnow
		sed -i -e "s/-O2/${CFLAGS}/g" Makefile
	fi
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
#		ln -s "/usr/src/${i}" "${r}"/build
#		ln -s "/usr/src/${i}" "${r}"/source
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
#	use cramfs && cramfs
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
		for f in "${BDIR}"/* ; do
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
	local arch="$(tc-arch-kernel)"
	[[ "$arch" == "i386" ]] && arch="x86"
	LDFLAGS="" ARCH="$(tc-arch-kernel)" ABI="${KERNEL_ABI}" "${S}/genkernel" --cachedir="${TMPDIR}/genkernel-cache" --tempdir="${TMPDIR}/genkernel" --logfile="${TMPDIR}/genkernel.log" --utils-arch=${arch} --arch-override=${arch} --postclear $* || die "genkernel failed"
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

cfg(){
	local r="$1"
	local o="$2"
	local i i1
	( grep -P "^(?:\# )?CONFIG_${o}(?:=.*| is not set)\$" .config || echo "${o}" ) >"${TMPDIR}"/pnp.tmp
	while read i ; do
		i1="${i}"
		i=${i#\# }
		i=${i#CONFIG_}
		i=${i/=*/}
		i=${i/ is not set/}
		sed -i -e "/^# CONFIG_${i} is not set/d" -e "/^CONFIG_${i}=.*/d" .config
		[[ "$3" == "-"  && "${i1/=}" != "${i1}" ]] && continue
		if [[ "${r}" == "n" ]]; then
			echo "# CONFIG_${i} is not set" >>.config
		elif [[ "${r}" != "-" ]]; then
			echo "CONFIG_${i}=${r}" >>.config
		fi
	done <"${TMPDIR}"/pnp.tmp
	rm "${TMPDIR}"/pnp.tmp
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
	local i i1 o m xx
	einfo "Configuring kernel"
	kmake defconfig >/dev/null
	for i in ${KERNEL_MODULES}; do
		einfo "Searching modules: ${i}"
		m="-"
		i1="${i}"
		i="${i#+}"
		[[ "${i1}" == "${i}" ]] || m=""
		for xx in 1 $m ; do
			for o in `grep -Prh "^\s*(?:menu)?config\s+.*?\n(?:[^\n]+\n)*\s*tristate" ${i} --include="Kconfig*" 2>/dev/null  | grep -P "^\s*(?:menu)?config"` ; do
				[[ "${o}" == "config" || "${o}" == "menuconfig" ]] || cfg m "${o}" "${m}"
			done
			yes '' 2>/dev/null | kmake oldconfig &>/dev/null
		done
	done
	setconfig
	setconfig
	cfg y EXT2_FS
	if use pnp || use compressed; then
		cfg m SQUASHFS
		cfg m CRAMFS
		cfg m BLK_DEV_LOOP
	fi
	cfg_use debug "(?:[^\n]*_)?DEBUG(?:_[^\n]*)?"
	cfg_use ipv6 IPV6
	yes '' 2>/dev/null | kmake oldconfig >/dev/null
}

kmake(){
	# DESTDIR="${D}"
	emake ARCH=$(tc-arch-kernel) ABI=${KERNEL_ABI} $* || die
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
	use pnp || return
	einfo "Fixing modules hardware info exports (forced mode, waiting for bugs!)"
	sh "${ROOT}/usr/share/genpnprd/modulesfix" "${S}" f
}
