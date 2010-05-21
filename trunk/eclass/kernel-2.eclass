EAPI=3
inherit flag-o-matic
[[ "${PV}" == 9999* ]] && KV_FULL="${PV}"
source "${PORTDIR}/eclass/kernel-2.eclass"


#UROOT="${ROOT}"
UROOT=""

if [[ ${ETYPE} == sources ]]; then

IUSE="${IUSE} build-kernel debug custom-cflags pnp compressed integrated ipv6
	netboot nls unicode +acl minimal selinux custom-arch
	+kernel-drm +kernel-alsa kernel-firmware +sources fbcon staging pnponly lzma
	external-firmware"
DEPEND="${DEPEND}
	pnp? ( sys-kernel/genpnprd )
	build-kernel? (
		>=sys-kernel/genkernel-3.4.10.903
		compressed? ( sys-kernel/genpnprd )
		kernel-drm? ( !x11-base/x11-drm )
		kernel-alsa? ( !media-sound/alsa-driver )
		kernel-firmware? ( !sys-kernel/linux-firmware )
	) "

eval "`/usr/bin/perl ${UROOT}/usr/share/genpnprd/Kconfig.pl -config`"

PROVIDE="sources? ( virtual/linux-sources )
	!sources? ( virtual/linux-kernel )
	kernel-alsa? ( virtual/alsa )"

[[ -e "${CONFIG_ROOT}${KERNEL_CONF:=/etc/kernels/kernel.conf}" ]] && source "${CONFIG_ROOT}${KERNEL_CONF}"

USEKEY="$(for i in ${!KERNEL_@} ; do
	echo "${!i} , "
done | md5sum)"
IUSE="${IUSE} md5cfg:${USEKEY%% *}"


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
	grep "^$1[ 	]*=.*$" "${S}"/Makefile | sed -e 's%^.*= *%%'
}

gen_KV(){
	local KV KERNEL_DIR="${S}" g="${UROOT}/usr/share/genkernel/gen_determineargs.sh"
	get_KV(){ KV="$(get_v VERSION).$(get_v PATCHLEVEL).$(get_v SUBLEVEL)$(get_v EXTRAVERSION)";}
	[ -e "${g}" ] && source "${g}"
	get_KV
	echo "${KV}"
}

check_kv(){
	REAL_KV="$(gen_KV)"
	[ -z "${KV}" ] && set_kv ${REAL_KV}
}

kernel-2_src_compile() {
	local KV0="${KV}"
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
	kmake bzImage
	einfo "Compiling kernel modules"
	kmake modules ${KERNEL_MODULES_MAKEOPT}
	einfo "Generating initrd image"
	KV="${KV0}"
	check_kv
	local p=""
	use netboot && p="${p} --netboot"
	[[ -e "${BDIR}" ]] || mkdir "${BDIR}"
	kmake INSTALL_MOD_PATH="${BDIR}" modules_install
	local r="${BDIR}/lib/modules/${REAL_KV}"
	rm "${r}"/build "${r}"/source
	cd "${WORKDIR}"
	local i
	use sources && for i in build source ; do
		ln -s "../../../usr/src/linux-${KV_FULL}" "${r}/${i}"
	done
	cd "${S}"
	if use external-firmware; then
		mkdir "${BDIR}"/lib 2>/dev/null
		cp -na "$ROOT"/lib/firmware "${BDIR}"/lib
	fi
	if use pnp || use compressed; then
		p="${p} --all-ramdisk-modules"
		[[ -e "${BDIR}/lib/firmware" ]] && p="${p} --firmware --firmware-dir=\"${BDIR}/lib/firmware\""
	fi
	run_genkernel ramdisk "--kerneldir=\"${S}\" --bootdir=\"${S}\" --module-prefix=\"${BDIR}\" --no-mountboot ${p}"
	r=`ls initramfs*-${REAL_KV}`
	rename "${r}" "initrd-${REAL_KV}.img" "${r}" || die "initramfs rename failed"
	einfo "Preparing boot image"
	bash "${UROOT}/usr/share/genpnprd/genpnprd" "${S}/initrd-${REAL_KV}.img" "$( (use !pnp && echo nopnp)||(use pnponly && echo pnponly) )" "${TMPDIR}"/overlay-rd || die
	# integrated: do not compress twice;
	# others: +~700K, but faster boot & less RAM to uncompress.
	# "integrated" still minimal
	( use pnp || use compressed || use integrated ) &&
		gzip -dc "initrd-${REAL_KV}.img" >"initrd-${REAL_KV}.cpio" &&
		rm "initrd-${REAL_KV}.img"
	if use integrated; then
		echo "CONFIG_INITRAMFS_SOURCE=\"initrd-${REAL_KV}.cpio\"
CONFIG_INITRAMFS_ROOT_UID=0
CONFIG_INITRAMFS_ROOT_GID=0
CONFIG_INITRAMFS_COMPRESSION_NONE=y" >>.config
		yes '' 2>/dev/null | kmake oldconfig &>/dev/null
		kmake bzImage
	else
		[[ -e "initrd-${REAL_KV}.cpio" ]] && rename .cpio .img "initrd-${REAL_KV}.cpio"
	fi
	rm .config.old
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
		if use kernel-firmware; then
			ewarn "Useflag 'kernel-firmware' must be enabled one branch to avoid collisions"
		else
			rm ${BDIR}/lib/firmware -Rf
		fi
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
		bash "${UROOT}/usr/share/genpnprd/genpkgrd" "${i}" "${KERNEL_IMAGE_FILES}" "${KERNEL_IMAGE_FILES2}" "${KERNEL_IMAGE_PACKAGES}" || die
	fi
	echo ">>> Preparing to unpack ..."
}

run_genkernel(){
	[[ ! -e "${TMPDIR}/genkernel-cache" ]] && cp "${UROOT}/var/cache/genkernel" "${TMPDIR}/genkernel-cache" -r
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

cfg(){
	KERNEL_CONFIG="$* ${KERNEL_CONFIG}"
}

cfg_use(){
	local i u="$1"
	shift
	for i in $* ; do
		if use $u ; then
			cfg $i
		else
			cfg -$i
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
	cfg EXT2_FS
	if use pnp || use compressed; then
		cfg +SQUASHFS +CRAMFS +BLK_DEV_LOOP
	fi
	local cfg_exclude=" HAVE_DMA_API_DEBUG "
	cfg_use debug "(?:[^\n]*_)?DEBUG(?:_[^\n]*)?" FRAME_POINTER OPTIMIZE_INLINING FUNCTION_TRACER OPROFILE KPROBES X86_VERBOSE_BOOTUP PROFILING MARKERS
	use debug || cfg STRIP_ASM_SYMS -INPUT_EVBUG
	local cfg_exclude=
	cfg_use ipv6 IPV6
	cfg_use acl "[\d\w_]*_ACL"
	cfg_use selinux "[\d\w_]*FS_SECURITY SECURITY SECURITY_NETWORK SECURITY_SELINUX SECURITY_SELINUX_BOOTPARAM"
	use nls && cfg "[\d\w_]*_NLS"
	use unicode && cfg NLS_UTF8
	if use kernel-drm ; then
		cfg +DRM
	else
		cfg -DRM
	fi
	cfg_use kernel-alsa SND
	use kernel-alsa || cfg +SOUND_PRIME
	cfg_use lzma KERNEL_LZMA
	cfg_use !lzma KERNEL_BZIP2
	# framebuffer enabled anymore, but "fbcon" support for more devices, exclude [external] nouveau drm
	if use fbcon; then
		cfg FB FRAMEBUFFER_CONSOLE FB_BOOT_VESA_SUPPORT "LOGO_LINUX_[\w\d]*"
	else
		cfg -FB_UVESA
	fi
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
	if use minimal; then
		KERNEL_CONFIG="${KERNEL_CONFIG} -IP_ADVANCED_ROUTER -NETFILTER ~IP_FIB_TRIE -NET_CLS_IND"
		KERNEL_MODULES="${KERNEL_MODULES} -net +net/sched +net/irda +net/bluetooth"
	fi
	# staging submenu will be opened, but no auto-m
	use staging || KERNEL_MODULES="${KERNEL_MODULES} -drivers/staging"
	kmake defconfig >/dev/null
	setconfig
	export ${!KERNEL_@}
	while cfg_loop .config.{3,4} ; do
		/usr/bin/perl "${UROOT}/usr/share/genpnprd/Kconfig.pl"
		yes '' 2>/dev/null | kmake oldconfig >/dev/null
	done
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
	sh "${UROOT}/usr/share/genpnprd/modulesfix" "${S}" f
}

