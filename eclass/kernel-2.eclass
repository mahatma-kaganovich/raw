: ${EAPI:=1} # 3 or neutral
inherit flag-o-matic
[[ "${PV}" == 9999* ]] && KV_FULL="${PV}"
source "${PORTDIR}/eclass/kernel-2.eclass"
EXPORT_FUNCTIONS src_configure src_prepare pkg_prerm

#UROOT="${ROOT}"
UROOT=""
SHARE="${UROOT}/usr/share/genpnprd"
COMP='GZIP,BZIP2'

if [[ ${ETYPE} == sources ]]; then

IUSE="${IUSE} +build-kernel debug custom-cflags +pnp +compressed integrated
	netboot unicode selinux custom-arch embed-hardware
	+kernel-drm +kernel-alsa kernel-firmware +sources staging pnponly lzma xz
	external-firmware xen +smp tools multilib multitarget +multislot thin
	lvm evms device-mapper unionfs luks gpg iscsi e2fsprogs mdadm
	lguest acpi klibc"
DEPEND="${DEPEND}
	!<app-portage/ppatch-0.08-r16
	pnp? ( sys-kernel/genpnprd )
	lzma? ( app-arch/xz-utils )
	xz? ( app-arch/xz-utils )
	build-kernel? (
		>=sys-kernel/genkernel-3.4.10.903
		compressed? ( sys-kernel/genpnprd )
		kernel-drm? ( !x11-base/x11-drm )
		kernel-alsa? ( !media-sound/alsa-driver )
		kernel-firmware? ( !sys-kernel/linux-firmware )
		luks? ( sys-fs/cryptsetup )
		evms? ( sys-fs/evms )
		klibc? ( dev-libs/klibc )
	) "

if use multislot ; then
	SLOT="${CTARGET}-${PF}"
elif [[ ${CTARGET} != ${CHOST} ]]; then
	SLOT="${CTARGET}-${PN%-sources}"
else
	SLOT="${PN%-sources}"
fi

eval "`/usr/bin/perl ${SHARE}/Kconfig.pl -config`"

KERNEL_CONFIG+=" +TR"

PROVIDE="sources? ( virtual/linux-sources )
	!sources? ( virtual/linux-kernel )
	kernel-alsa? ( virtual/alsa )"

CF1(){
	local i
	for i in "${@}"; do
		CF="${CF// [+-]${i#[+-]} }"
		CF="${CF// ${i#[+-]} } ${i} "
	done
}

CF2(){
	local i
	for i in "${@}"; do
		if use embed-hardware; then
			CF1 "$i"
		else
			CF1 "+$i"
		fi
	done
}

[[ -e "${CONFIG_ROOT}${KERNEL_CONF:=/etc/kernels/kernel.conf}" ]] && source "${CONFIG_ROOT}${KERNEL_CONF}"

#USEKEY="$(for i in ${!KERNEL_@} ; do
#	echo "${!i} , "
#done | md5sum)"
#IUSE="${IUSE} md5cfg:${USEKEY%% *}"

for i in "${SHARE}"/*.{-use,use}; do
	i="${i##*/}"
	i="${i%.use}"
	i="${i%.-use}"
	IUSE="$IUSE ${i#[0-9]}"
done

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
	local KV KERNEL_DIR="${S}" g
	get_KV(){ KV="$(get_v VERSION).$(get_v PATCHLEVEL).$(get_v SUBLEVEL)$(get_v EXTRAVERSION)";}
	determine_config_file(){ KERNEL_CONFIG="${S}/.config";}
	for g in ${UROOT}/usr/share/genkernel/gen_determineargs.sh; do
		[ -e "${g}" ] && source "${g}"
	done
	get_KV
	echo "${KV}"
}

check_kv(){
	REAL_KV="$(gen_KV)"
	[ -z "${KV}" ] && set_kv ${REAL_KV}
}

flags_nosp(){
	local x="${@# }"
	echo "${x% }"
}

kernel-2_src_configure() {
	[[ ${ETYPE} == sources ]] || return
	cd "${S}"
	cpu2K
	## ldflags unsure
	: ${KERNEL_UTILS_CFLAGS:="${CFLAGS}"} # "
	local cflags="${KERNEL_CFLAGS}" aflags="${KERNEL_ASFLAGS}" ldflags="${KERNEL_LDFLAGS}"
	if use custom-cflags; then
		use custom-arch || filter-flags "-march=*"
		filter-flags "-msse*" -mmmx -m3dnow
		cflags="$(flags_nosp "${CFLAGS} ${cflags}")"
		aflags="$(flags_nosp "$(extract_aflags) ${aflags}")"
		ldflags="$(flags_nosp "$(extract_flags -Wl, ${LDFLAGS}) ${ldflags}")"
	fi
	[[ -n "${cflags}" ]] && sed -i -e "s/^\(KBUILD_CFLAGS.*-O.\)/\1 ${cflags}/g" Makefile
	[[ -n "${aflags}" ]] && sed -i -e "s/^\(AFLAGS_[A-Z]*[	 ]*=\)$/\1 ${aflags}/" Makefile
	[[ -n "${ldflags}" ]] && sed -i -e "s/^\(LDFLAGS_[A-Z]*[	 ]*=\)$/\1 ${ldflags}/" Makefile
	export comp=''
	use build-kernel || return
	useconfig
	kconfig
	for i in `grep "^CONFIG_KERNEL_.*=y$" "$S/.config"|sed -e 's:^CONFIG_KERNEL_::' -e 's:=y$::' -e 's:^LZMA$:LZMA XZ:'`; do
		grep -q "^CONFIG_SQUASHFS_$i=y" "$S/.config" && (mksquashfs |& grep -qi "^\s*$i\s*$") && comp="${i,,}"
	done
	export comp
}

use__(){
	use $1 && echo "--${2:-$1}"
}

kernel-2_src_compile() {
	if [[ "${EAPI}" == 1 ]]; then
		kernel-2_src_prepare
		kernel-2_src_configure
	fi
	####

	cd "${S}"
	[[ ${ETYPE} == headers ]] && compile_headers

	if [[ $K_DEBLOB_AVAILABLE == 1 ]] && use deblob ; then
		echo ">>> Running deblob script ..."
		sh "${T}/${DEBLOB_A}" --force || \
			die "Deblob script failed to run!!!"
	fi

	####
	[[ ${ETYPE} == sources ]] || return
	local KV0="${KV}"
	check_kv
	use build-kernel || return
	for i in true false; do
		if [[ -n "${KERNEL_MODULES_MAKEOPT}" ]]; then
			einfo "Compiling kernel (bzImage)"
			kmake bzImage
		fi
		einfo "Compiling kernel (all)"
		kmake all ${KERNEL_MODULES_MAKEOPT}
		grep -q "=m$" .config && [[ -z "`find . -name "*.ko" -print`" ]] && die "Modules configured, but not built"
		$i && use embed-hardware || break
		KERNEL_CONFIG+=" ===detect: $(detects)"
		kconfig
	done
	KV="${KV0}"
	check_kv

	einfo "Preparing modules"
	mkdir -p "${BDIR}" lib/modules/"${REAL_KV}"
	kmake INSTALL_MOD_PATH="${BDIR}" -j1 modules_install
	ln -s ../firmware lib/firmware
	ln -s ../../.. "lib/modules/${REAL_KV}/kernel"
	cp "${BDIR}/lib/modules/${REAL_KV}"/* "lib/modules/${REAL_KV}/"
	local r="${BDIR}/lib/modules/${REAL_KV}"
	rm "${r}"/build "${r}"/source
	cd "${WORKDIR}"
	local i
	use sources && for i in build source; do
		ln -s "../../../usr/src/linux-${KV_FULL}" "${r}/${i}"
	done
	cd "${S}"
	if use external-firmware; then
		mkdir "${BDIR}"/lib 2>/dev/null
		cp -na "$ROOT"/lib/firmware "${BDIR}"/lib
	fi

	if use sources || use klibc; then
		einfo "Preparing kernel headers"
		kmake headers_install #$(use compressed && echo _all)
	fi

	if use tools; then
		einfo "Compiling tools"
		mktools
	fi

	for i in `find Documentation -name "*.c"`; do
		_cc $i
	done

	if use klibc; then
		userspace
		return
	fi
	
	einfo "Generating initrd image"
	local p="$(use__ lvm lvm2) $(use__ evms) $(use__ luks) $(use__ gpg) $(use__ iscsi) $(use__ device-mapper dmraid) $(use__ unionfs) $(use__ e2fsprogs disklabel) $(use__ mdadm)"
	use netboot && p="${p} --netboot"
	if use pnp || use compressed; then
		p="${p} --all-ramdisk-modules"
		[[ -e "${BDIR}/lib/firmware" ]] && p="${p} --firmware --firmware-dir=\"${BDIR}/lib/firmware\""
	fi
	run_genkernel ramdisk "--kerneldir=\"${S}\" --bootdir=\"${S}\" --module-prefix=\"${BDIR}\" --no-mountboot ${p}"
	r=`ls initramfs*-${REAL_KV}`
	rename "${r}" "initrd-${REAL_KV}.img" "${r}" || die "initramfs rename failed"
	einfo "Preparing boot image"
	bash "${SHARE}/genpnprd" "${S}/initrd-${REAL_KV}.img" "$( (use !pnp && echo nopnp)||(use pnponly && echo pnponly) )" "${TMPDIR}"/overlay-rd "${S}" ${comp:+--COMPRESS $comp} $(use thin||echo --THIN -)|| die
	local i="initrd-${REAL_KV}.cpio" i1="initrd-${REAL_KV}.img"
	( use pnp || use compressed || (use integrated && use !thin) ) &&
		gzip -dc "$i1"  >"$i" && rm "$i1"
	if use integrated && use thin; then
		i="initrd-${REAL_KV}.thin.cpio"
		i1="$i1.thin"
		gzip -dc "$i1" >"$i" && rm "$i1"
	fi
	initramfs "$i" NONE
}

# integrated: do not compress twice;
# others: +~700K, but faster boot & less RAM to uncompress.
# "integrated" still minimal
# integrated+thin = integrated thin
# standalone "thin" image still compressed
initramfs(){
	local c="${2:-${COMP##*,}}"
	if use integrated; then
		einfo "Integrating initramfs"
		echo "CONFIG_INITRAMFS_SOURCE=\"$1\"
CONFIG_INITRAMFS_ROOT_UID=0
CONFIG_INITRAMFS_ROOT_GID=0
CONFIG_INITRAMFS_COMPRESSION_$c=y" >>.config
		yes '' 2>/dev/null | kmake oldconfig &>/dev/null
		kmake bzImage
	elif [[ "${c:-NONE}" != NONE ]]; then
		${c,,} -zc9 "$1" >"${1%.cpio}.img" || die
		rm "$1"
	else
		[[ -e "$1" ]] && rename .cpio .img "$1"
	fi
	rm .config.old
}

kernel-2_src_install() {
	check_kv
	cd "${S}" || die
	if [[ ${ETYPE} == sources ]] && use build-kernel; then
		mkdir "${D}/boot"
		local f f1
		if ! use integrated; then
			insinto "/boot"
			for f in initrd-"${REAL_KV}".img{,.thin}; do
				[[ -e "$f" ]] && doins "$f"
			done
		fi
		if use kernel-firmware; then
			ewarn "Useflag 'kernel-firmware' must be enabled one branch to avoid collisions"
		else
			rm ${BDIR}/lib/firmware -Rf
		fi
		mv "${BDIR}"/* "${D}/" || die
		kmake INSTALL_PATH="${D}/boot" install
		use tools && mktools INSTALL_PATH="${D}" DESTDIR="${D}" install
		for f in vmlinuz System.map config ; do
			f1="${D}/boot/${f}"
			if [[ -e "${f1}" ]] ; then
				mv "$(readlink -f ${f1})" "${f1}-${REAL_KV}"
				rm "${f1}" -f &>/dev/null
			fi
			use !multislot && dosym "${f}-${REAL_KV}" /boot/"${f}-${SLOT}"
		done
		f="${D}/boot/config-${REAL_KV}"
		[[ -e "$f" ]] || cp "${S}/.config" "$f"
		local sym=''
		if use !multislot; then
			use sources && sym="linux-${KV_FULL}"
			for i in .img .img.thin; do
				[[ -e "${D}/boot/initrd-${REAL_KV}$i" ]] && dosym initrd-${REAL_KV}$i /boot/initrd-${SLOT}$i
			done
		fi
		if use sources ; then
			find "${S}" -name "*.cmd" | while read f ; do
				sed -i -e 's%'"${S}"'%/usr/src/linux-'"${REAL_KV}"'%g' ${f}
			done
			if use pnp && use compressed; then
				einfo "Compressing with squashfs"
				f="linux-${REAL_KV}"
				# respect linux-info.eclass
				[[ "${sym:-$f}" != "$f" ]] && dosym "$f" "/usr/src/$sym"
				# but real directory will be linux-`uname -r`
				sym="${sym:+$f}"
				f1="/lib/modules/${REAL_KV}/kernel"
				rm "${D}${f1}" -Rf
				dosym "../../../usr/src/${f}" "${f1}"
				rm "initrd-${REAL_KV}.img"
				cd "${WORKDIR}"
				keepdir /usr/src/"${f}"
				f="${D}/usr/src/${f}.squashfs"
				mksquashfs "${S}" "${f}" ${comp:+-comp $comp }-no-recovery -no-progress || die
				chmod 755 "${f}"
				rm "${S}" -Rf
			fi
		else
			cd "${WORKDIR}"
			rm "${S}" -Rf
		fi
		[[ -n "$sym" ]] && dosym "$sym" /usr/src/linux-${SLOT}
		ewarn "If your /boot is not mounted, copy next files by hands:"
		ewarn `ls "${D}/boot"`
	fi
	install_universal
	[[ ${ETYPE} == headers ]] && install_headers
	[[ ${ETYPE} == sources ]] && install_sources
}

to_overlay(){
	use build-kernel || return
	einfo "Generating boot image overlay (if configured)"
	local i="${TMPDIR}/overlay-rd"
	mkdir "${i}"
	bash "${SHARE}/genpkgrd" "${i}" "${KERNEL_IMAGE_FILES}" "${KERNEL_IMAGE_FILES2}" "${KERNEL_IMAGE_PACKAGES}"
}

run_genkernel(){
	[[ ! -e "${TMPDIR}/genkernel-cache" ]] && cp "${UROOT}/var/cache/genkernel" "${TMPDIR}/genkernel-cache" -r
	# cpio works fine without loopback, but may panish sandbox
	cp /usr/bin/genkernel "${S}" || die
	sed -i -e 's/has_loop/true/' "${S}/genkernel"
	local a="$(arch "" 1)"
	# e2fsprogs & mdraid need more crosscompile info
	ac_cv_target="${CTARGET:-${CHOST}}" ac_cv_build="${CBUILD}" ac_cv_host="${CHOST:-${CTARGET}}" CC="$(tc-getCC)" LD="$(tc-getLD)" CXX="$(tc-getCXX)" CPP="$(tc-getCPP)" AS="$(tc-getAS)" \
	CFLAGS="${KERNEL_UTILS_CFLAGS}" LDFLAGS="${KERNEL_GENKERNEL_LDFLAGS}" "${S}/genkernel" \
		--config=/etc/kernels/genkernel.conf \
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
	if cmp -s $1 $2 ; then
		rm $1 $2
		return 1
	else
		cp $1 $2
		return 0
	fi
}

useconfig(){
	einfo "Preparing KERNEL_CONFIG"
	local i o
	# staging submenu will be opened, but no auto-m
	use staging || KERNEL_MODULES="${KERNEL_MODULES} -drivers/staging"
	if use !embed-hardware; then
		cfg EXT2_FS
		use compressed || use pnp && cfg +SQUASHFS +CRAMFS +BLK_DEV_LOOP
	fi
	local cfg_exclude=" HAVE_DMA_API_DEBUG "
	cfg_use debug "(?:[^\n]*_)?DEBUG(?:GING)?(?:_[^\n]*)?" FRAME_POINTER OPTIMIZE_INLINING FUNCTION_TRACER OPROFILE KPROBES X86_VERBOSE_BOOTUP PROFILING MARKERS
	use debug || cfg STRIP_ASM_SYMS -INPUT_EVBUG
	local cfg_exclude=
	cfg_use selinux "[\d\w_]*FS_SECURITY SECURITY SECURITY_NETWORK SECURITY_SELINUX SECURITY_SELINUX_BOOTPARAM"
	use unicode && cfg NLS_UTF8
	if use kernel-drm ; then
		cfg +DRM
	else
		cfg -DRM
	fi
	cfg_use kernel-alsa SND
	use kernel-alsa || cfg +SOUND_PRIME
#	use lzo && COMP+=',LZO'
	use lzma && COMP+=',LZMA,XZ'
	use xz && COMP+=',XZ'
	cfg KERNEL_{$c}
	KERNEL_CONFIG+="
"
	for i in "${SHARE}"/*use; do
		o="${i##*/}"
		o="${o%.*}"
		o="${o#[0-9]}"
		o="${o#[+~-]}"
		case "$i" in
		*.-use)o="!$o";;
		*.use);;
		*)continue;;
		esac
		use "$o" || continue
		KERNEL_CONFIG+="===$o: "
		source "$i"
		KERNEL_CONFIG+="
"
	done
	use multilib || ( use multitarget && use x86 ) || cfg -IA32_EMULATION
}

# experemental
acpi_detect(){
	local i n=0
	[[ -d /sys/bus/acpi ]] || return
	CF1 -PCI -PCC_CPUFREQ -SMP -X86_BIGSMP -MAXSMP
	for i in $(cat /sys/bus/acpi/devices/*/path|sed -e 's:^\\::'); do
		case "$i" in
		*.SRAT)CF1 NUMA;;
		_SB_.PCI*)CF1 PCI;;
		_SB_.PCCH)CF2 PCC_CPUFREQ;freq+=" PCC_CPUFREQ";;
		_PR_.*)let n=n+1;;
		esac
	done
	[[ "$CF" == *-SCHED_SMT* ]] && grep -q "^flags\s*:.*\sht\s" /proc/cpuinfo && let n=n/2
	[[ $n == 0 ]] && die "ACPI CPU enumeration wrong. Say 'USE=-acpi'"
	[[ $n -gt 1 ]] && CF1 SMP
	[[ $n -gt 8 ]] && CF1 X86_BIGSMP
	[[ $n -gt 512 ]] && CF1 MAXSMP
	CF1 NR_CPUS=$n
}

# Kernel-config CPU from CFLAGS and|or /proc/cpuinfo (native)
# use smp: when 'native' = single/multi cpu, ht/mc will be forced ON
cpu2K(){
local i v V="" CF="" march=$(march) m64g="HIGHMEM64G -HIGHMEM4G -NOHIGHMEM" freq='' gov='ONDEMAND'
local vendor_id="" model_name="" flags="" cpu_family="" model="" cache_alignment="" fpu="" siblings="" cpu_cores="" processor=""
CF1 -SMP -X86{BIGSMP,GENERIC} X86_{X2APIC,UP_APIC,UP_IOAPIC}
use xen && CF1 -HIGHMEM64G -HIGHMEM4G NOHIGHMEM X86_PAE
use smp && CF1 SMP X86_BIGSMP SCHED_{SMT,MC}
[[ "$(march mtune)" == generic ]] && CF1 X86_GENERIC
if [[ -z "${march}" ]]; then
	CF1 GENERIC_CPU X86_GENERIC
	march="${CTARGET:-${CHOST}}"
	march="${march%%-*}"
fi
case "${march}" in
native)
	CF1 -SCHED_{SMT,MC} -X86_{UP_APIC,TSC,PAT,MSR,MCE,CMOV,X2APIC} -MTRR -INTEL_IDLE -KVM_INTEL -KVM_AMD
	case "${CTARGET:-${CHOST}}" in
	x86*|i?86*)
		use multitarget && CF1 -64BIT
		CF1 -XEN # -KVM
		use lguest || CF1 -{PARAVIRT,LGUEST}{,_GUEST} -VIRTUALIZATION
	;;
	esac

	while read i ; do
		v="${i%%:*}"
		v="${v//	}"
		v="${v// /_}"
		[[ -n "${v}" ]] && local ${v}="${i#*: }"
	done </proc/cpuinfo
	flags=" ${flags:-.} "

	for i in ${flags}; do
		case $i in
		apic)CF1 X86_UP_APIC;;
		ht)	case "${model_name}" in
			*Celeron*);;
			*)
				if ! grep -q SMP /proc/version; then
					ewarn "Trying to detect hyperthreading/cores under non-SMP kernel:"
					ewarn "SMP+SMT+MC forced, recommended to re-ebuild kernel under new kernel."
					CF1 SMP SCHED_{SMT,MC}
				fi
			;;
			esac
		;;
		tsc|pat|msr|mce|cmov|x2apic)CF1 X86_${i^^};;
		mtrr)CF1 ${i^^};;
		pae)CF1 X86_PAE $m64g;;
		mp)CF1 SMP;; # ?
		lm)use multitarget && CF1 64BIT;;
		cmp_legacy)CF1 SMP SCHED_MC -SCHED_SMT;;
		up)ewarn "Running SMP on UP. Recommended useflag '-smp' and '-SMP' in ${KERNEL_CONF}";;
		est)freq+=" X86_ACPI_CPUFREQ";;
		longrun)freq+=" X86_LONGRUN";;
		vmx)CF1 XEN +KVM{,_INTEL} PARAVIRT{,_GUEST} VIRTUALIZATION;;
		svm)CF1 XEN +KVM{,_AMD} PARAVIRT{,_GUEST} VIRTUALIZATION;;
		hypervisor)CF1 XEN PARAVIRT{,_GUEST} VIRTUALIZATION;;
		esac
	done

	[[ "${processor:=0}" -gt 0 ]] && CF1 SMP
	[[ $((processor+1)) == "${cpu_cores:-1}" ]] && [[ "${siblings:-1}" == "${cpu_cores:-1}" ]] && CF1 -NUMA
	# xtopology & other flags present only on SMP running anymore
	[[ "${cpu_cores:-1}" -gt 1 ]] && CF1 SMP SCHED_MC
	[[ "${siblings:-0}" -gt "${cpu_cores:-1}" ]] && CF1 SMP SCHED_SMT
	[[ "$(grep "^siblings\s*:\|^cpu cores\s*:" /proc/cpuinfo|sort -u|wc -l)" -gt 2 ]] && CF1 SMP SCHED_{SMT,MC} NUMA
	[[ "${fpu}" != yes ]] && CF1 MATH_EMULATION

	use acpi && acpi_detect

	case "${vendor_id}" in
	*Intel*)
		V=INTEL
		case "${cpu_family}:${model}:${flags}:${model_name}" in
		*Atom*)CF1 MATOM;;
		5:*\ mmx\ *)CF1 M586MMX;;
		5:*\ tsc\ *)CF1 M586TSC;;
		15:*\ M\ *)CF1 MPENTIUM4 MPSC;: ${freq:=X86_SPEEDSTEP_ICH};;
		15:*)CF1 MPENTIUM4 MPSC;[[ -z "$freq" ]] && freq=X86_P4_CLOCKMOD && gov='';;
		6:*\ ssse3\ *)CF1 MCORE2;;
		6:*\ sse2\ *)CF1 MPENTIUMM;;
		6:*\ sse\ *Mobile*|6:*\ sse\ *-S\ *)CF1 MPENTIUMIII;: ${freq:=X86_SPEEDSTEP_SMI};;
		6:*\ sse\ *Coppermine*)CF1 MPENTIUMIII;: ${freq:="X86_SPEEDSTEP_SMI X86_SPEEDSTEP_ICH"};;
		6:*\ sse\ *)CF1 MPENTIUMIII;: ${freq:=X86_SPEEDSTEP_ICH};;
		6:*\ mmx\ *)CF1 MPENTIUMII;;
		[3-6]:*)CF1 M${cpu_family}86;;
		*)CF1 GENERIC_CPU X86_GENERIC;;
		esac
		[[ "$family" == 6 ]] && [[ "$model" -gt 25 ]] && CF1 INTEL_IDLE
	;;
	*AMD*)
		V=AMD
		case "${cpu_family}:${model}:${flags}:${model_name}" in
		4:[3789]:*)CF1 M486;;
		4:*\ mmx\ *)CF1 M586MMX;;
		4:*\ tsc\ *)CF1 M586TSC;;
		4:*)CF1 M586;;
		5:*)CF1 MK6;freq=X86_POWERNOW_K6;;
		6:*)CF1 MK7;freq="X86_POWERNOW_K7 X86_CPUFREQ_NFORCE2";;
		7:*|*\ k8\ *|*\ lm\ *)CF1 MK8;freq=X86_POWERNOW_K8;gov=CONSERVATIVE;;
		*Geode*)CF1 GEODE_LX;;
		*)CF1 GENERIC_CPU X86_GENERIC;;
		esac
	;;
	*Centaur*)
		V=CENTAUR
		case "${cpu_family}:${model}:${flags}" in
		6:[0-8]:*)CF1 MCYRIXIII;freq=X86_LONGHAUL;;
		6:9:*)CF1 MVIAC3_2;;
		6:*\ lm\ *)CF1 MCORE2;CF2 SENSORS_VIA_CPUTEMP;;
		6:*)
			CF1 MPENTIUMM X86_GENERIC
			#CF1 MVIAC7
			CF2 SENSORS_VIA_CPUTEMP
		;; # C7: core2 w/o ssse3
		*\ 3dnow\ *)CF1 MWINCHIP3D;;
		*\ mmx\ *)CF1 MWINCHIPC6;;
		*)CF1 GENERIC_CPU X86_GENERIC;;
		esac
		[[ "$model" == 6 ]] && : ${freq:=X86_E_POWERSAVER}
	;;
	*Cyrix*)	V=CYRIX
			CF1 GENERIC_CPU X86_GENERIC
			case "${model_name}" in
			*6x86*|M\ II)CF1 M686;;
			*5x86*)CF1 M586;;
			*486*)CF1 M486;;
			*Geode*|*MediaGX*)CF1 MGEODEGX1 -X86_GENERIC;freq=X86_GX_SUSPMOD;;
			esac
	;;
	*)	#CF1 -CPU_SUP_{INTEL,AMD,CENTAUR}
		case "${model_name}" in
		*Geode*|*MediaGX*)CF1 MGEODEGX1;V=CYRIX;freq=X86_GX_SUSPMOD;;
		*Efficeon*)CF1 MEFFICEON;V=TRANSMETA_32;;
		*Crusoe*)CF1 MCRUSOE;V=TRANSMETA_32;;
		*386*)CF1 GENERIC_CPU X86_GENERIC M386;;
		*486*)CF1 GENERIC_CPU X86_GENERIC M486;;
		*586*|*5x86*)CF1 GENERIC_CPU X86_GENERIC M586;;
		*686|*6x86*)CF1 GENERIC_CPU X86_GENERIC M686;;
		*)CF1 GENERIC_CPU X86_GENERIC;;
		esac
	;;
	esac
;;
i386)CF1 M386 MATH_EMULATION;;
i486)CF1 M486 MATH_EMULATION;;
i586|pentium)CF1 M586;;
pentium-mmx)CF1 M586MMX;;
i686)CF1 X86_GENERIC M686;;
winchip-c6)CF1 MWINCHIPC6 -SCHED_SMT;;
winchip2)CF1 MWINCHIP3D -SCHED_SMT;;
c3)CF1 MCYRIXIII -SCHED_SMT;;
c3-2)CF1 MVIAC3_2 -SCHED_SMT;V=CENTAUR;;
geode)CF1 MGEODE_LX -SCHED_SMT;;
k6|k6-2)CF1 MK6 -SCHED_SMT;freq=X86_POWERNOW_K6;V=AMD;;
# compat: pentium-m sometimes have no PAE/64G
pentiumpro)CF1 M686;;
pentium2)CF1 MPENTIUMII;;
pentium3|pentium3m)CF1 MPENTIUMIII;freq="X86_SPEEDSTEP_SMI X86_SPEEDSTEP_ICH";;
pentium-m)CF1 MPENTIUMM;;
# sure 64G
pentium4|pentium4m|prescott|nocona)
	case "$(march mtune)" in
	pentium4|pentium4m|prescott|nocona)CF1 MPENTIUM4 MPSC $m64g;;
	?*)CF1 MPENTIUMM X86_GENERIC GENERIC_CPU $m64g;;
	*)CF1 MPENTIUM4 MPSC $m64g;;
	esac
	freq="X86_ACPI_CPUFREQ X86_P4_CLOCKMOD"
;;
core2|atom)CF1 M${^^march} $m64g;freq=X86_ACPI_CPUFREQ;;
k6-3)CF1 MK6 $m64g -SCHED_SMT;freq=X86_POWERNOW_K6;V=AMD;;
athlon|athlon-tbird|athlon-4|athlon-xp|athlon-mp)CF1 MK7 $m64g -SCHED_SMT;freq=X86_POWERNOW_K7;V=AMD;;
bdver1|k8|opteron|athlon64|athlon-fx|k8-sse3|opteron-sse3|athlon64-sse3|amdfam10|barcelona)CF1 MK8 $m64g -SCHED_SMT;freq=X86_POWERNOW_K8;gov=CONSERVATIVE;V=AMD;;
*)CF1 GENERIC_CPU X86_GENERIC;;
esac
case "${CTARGET:-${CHOST}}:$CF" in
	x86_64*|*\ 64BIT\ *)CF1 -MPENTIUM4 -PENTIUMM -X86_GENERIC;;
	*)CF1 -MPSC -GENERIC_CPU;;
esac
use lguest && CF1 -HIGHMEM64G
use acpi && use embed-hardware && acpi_detect
use embed-hardware && [[ -n "$freq" ]] && CF1 $freq CPU_FREQ_GOV_${gov} CPU_FREQ_DEFAULT_GOV_${gov}
[[ -n "${V}" ]] && CF1 "-CPU_SUP_[\w\d_]*" CPU_SUP_${V}
KERNEL_CONFIG="#-march=${march}# ${CF//  / }
${KERNEL_CONFIG}"
}

march(){
local a=" ${CFLAGS} ${KERNEL_CFLAGS}"
a="${a##* -${1:-march}=}"
echo "${a%% *}"
}

kconfig(){
	einfo "Configuring kernel"
	local a
	[[ -e .config ]] || kmake defconfig >/dev/null
	export ${!KERNEL_@}
	while cfg_loop .config.{3,4} ; do
		for a in "$(arch)" ''; do
			SRCARCH="$a" /usr/bin/perl "${SHARE}/Kconfig.pl" && break
		done
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
		# x86 profile sometimes buggy. to kernel when not 32/64 - do old
		i?86*) ( [[ -n "$2" ]] || ( use multitarget && [[ "$(march)" == native ]] ) ) &&
			echo "x86" || echo "i386"
		;;
		x86_64*) [[ -z "$2" ]] && use multitarget && [[ "$(march)" == native ]] &&
			echo "x86" || echo "x86_64"
		;;
		*) tc-ninja_magic_to_arch kern ${h};;
	esac
}

kmake(){
	local o=""
	local h="${CTARGET:-${CHOST}}"
	[[ "${CBUILD}" != "${h}" ]] && o="CROSS_COMPILE=${h}-"
	emake HOSTCC="$(tc-getBUILD_CC)" ARCH=$(arch) $o "${@}" ${KERNEL_MAKEOPT} || die
}

mktools(){
	local i
	for i in tools/*/Makefile; do
		kmake -C "${i%/Makefile}" CFLAGS="${KERNEL_UTILS_CFLAGS}" "${@}"
	done
}

_cc(){
	einfo "Compiling '$1'"
	$(tc-getCC) -I"${S}"/include ${KERNEL_UTILS_CFLAGS} ${LDFLAGS} $1 -o ${1%.c} &&
	    [[ -n "$2" ]] && ( ( [[ -d "$2" ]] || mkdir -p "$2" ) && cp ${1%.c} "$2" )
	return $?
}

kernel-2_src_prepare(){
	[[ ${ETYPE} == sources ]] || return

	local i
	to_overlay
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
	use unicode && sed -i -e 's/(sbi->options\.utf8)\|(utf8)/(1)/g' fs/fat/{dir,namei_vfat}.c
	# custom-arch
	use custom-arch && sed -i -e 's/-march=[a-z0-9\-]*//g' -e 's/-mtune=[a-z0-9\-]*//g' arch/*/Makefile*
	# prevent to build twice
#	sed -i -e 's%-I$(srctree)/arch/$(hdr-arch)/include%%' Makefile
	# gcc 4.5+ -O3 -ftracer
	sed -i -e 's:^static unsigned long vmcs_readl:static noinline unsigned long vmcs_readl:' arch/x86/kvm/vmx.c
	sed -i -e 's:^static void sleep_delay:static noinline void sleep_delay:' drivers/media/radio/radio-aimslab.c
	# ;)
	sed -i -e 's:^#if 0$:#if 1:' drivers/net/tokenring/tms380tr.c
	# amdfam10 (???)
	if [[ "$a" == i?86-* ]] || [[ "$a" == x86_* ]]; then
	echo "CFLAGS_events.o += -fno-selective-scheduling2" >>drivers/xen/Makefile
	echo "CFLAGS_mballoc.o += -fno-selective-scheduling2" >>fs/ext4/Makefile
	echo "CFLAGS_virtio_balloon.o += -fno-selective-scheduling2" >>drivers/virtio/Makefile
	echo "CFLAGS_ba_action.o += -fno-selective-scheduling2" >>drivers/staging/rt2860/Makefile
	echo "CFLAGS_ba_action.o += -fno-selective-scheduling2" >>drivers/staging/rt2870/Makefile
	echo "CFLAGS_tail_conversion.o += -fno-selective-scheduling2" >>fs/reiser4/Makefile
	fi
	# core2+
	echo "CFLAGS_ti_usb_3410_5052.o += -fno-tree-loop-distribution" >>drivers/usb/serial/Makefile
	# pnp
	use pnp || return
	einfo "Fixing modules hardware info exports (forced mode, waiting for bugs!)"
	sh "${SHARE}/modulesfix" "${S}" f
}

# around git-sources, etc (postinst_sources -> kernel-2_pkg_postinst)
override_postinst(){
	pkg_postinst(){
		kernel-2_pkg_postinst
	}
}

_umount(){
	[[ ${ETYPE} == sources ]] &&  use build-kernel && use pnp && use compressed || return
	override_postinst
	local i x y z
	for i in `portageq contents "${ROOT:-/}" "${CATEGORY}/${PF}"|grep "^${ROOT%/}/usr/src/linux-[^/]*$"`; do
		[[ -d "${i}" ]] || continue
		while read x y z; do
			[[ "${y}" == "${i}" ]] || continue
			x="${x%:}"
			( umount ${x} || umount -l ${x} ) && elog "Unmounted $x: $i"
			losetup -d ${x}
		done </proc/mounts
		( umount "${i}" || umount -l "${i}" ) && elog "Unmounted $i"
	done 2>/dev/null
}

kernel-2_pkg_prerm() {
	_umount
}

kernel-2_pkg_preinst() {
	[[ ${ETYPE} == headers ]] && preinst_headers
	####
	_umount
	[[ ${ETYPE} == sources ]] &&  use build-kernel || return
	local i="/lib/modules/${REAL_KV}/kernel"
	( ( [[ -L "${D}${i}" ]] && ! [[ -L "${ROOT}${i}" ]] && [[ -e "${ROOT}${i}" ]] ) ||
	    ( [[ -L "${ROOT}${i}" ]] && ! [[ -L "${D}${i}" ]] && [[ -e "${D}${i}" ]] ) ) &&
	    rm -Rf "${ROOT}${i}"
}

kernel-2_pkg_postinst() {
	[[ ${ETYPE} == sources ]] && postinst_sources
	####
	[[ ${ETYPE} == sources ]] && use build-kernel && use pnp && use compressed && mount -o loop,ro "${ROOT}"/usr/src/linux-"${REAL_KV}"{.squashfs,} && elog "Mounted sources: ${REAL_KV}"
}

extract_flags(){
local pref="$1"
shift
for i in "${@}"; do
	a="${i#${pref}}"
	[[ "$a" == "$i" ]] && continue
	echo -n " ${a//,/ }"
done
}

extract_aflags(){
# ASFLAGS used for yasm too, -mtune is unsure
local i a aflags="${ASFLAGS}"
for i in $(extract_flags -Wa, ${CFLAGS}); do
	case "${i}" in
	-mtune=native)continue;;
	esac
	aflags="${aflags% ${i}} ${i}"
done
for i in $(echo "int main(){}"|$(tc-getBUILD_CC) ${CFLAGS} "${@}" -x c - -v -o /dev/null |& grep "^[ ]*[^ ]*/as"); do #"
	case "${i}" in
	-mtune=*)aflags="${aflags% ${i}} ${i}";;
	esac
done
echo "${aflags# }"
}

detects(){
	local i a b c d
	find . -name Makefile|while read i; do
		while read i; do
			a="${i%\\}"
			[[ "$a" == "$i" ]] && echo "$i" || echo -n "$a "
		done <$i
	done |grep "^obj-" >"${TMPDIR}"/unmodule.tmp
	perl "${SHARE}"/mod2sh.pl "${WORKDIR}" >&2 || die "Unable to run '${SHARE}/mod2sh.pl'"
	. "${WORKDIR}"/modules.alias.sh
	{
		# /sys
		cat `find /sys -name modalias`
		grep -sh "^MODALIAS=" $(find /sys -name uevent)|sed -e 's:^MODALIAS=::'
		# rootfs
		while read a b c d; do
			[[ "$b" == / ]] && [[ "$c" != rootfs ]] && echo "$c"
		done </proc/mounts
		# cpu flags
		(cd "${SHARE}"/etc/modflags && cat $(grep "^flags" /proc/cpuinfo|sed -e 's/^.*://') $(cat /sys/bus/acpi/devices/*/path|sed -e 's:^\\::') </dev/null 2>/dev/null)
	}|sed -e 's:-:_:g'|sort -u|while read i; do
		modalias "$i"||continue
		# strip "later" concurrent drivers
		i="$ALIAS"
		i="${ALIAS%% 1 *}"
		#[[ "$i" != "$ALIAS" ]] && [[ -n "$i" ]] && echo "strip: $ALIAS" >&2
		i="${i:-${ALIAS#1 }}"
		echo "${i// /
}"
		rm -f $i
	done|sed -e 's:^.*/::g' -e 's:\.ko$::g'|sort -u|while read i; do
		grep -Rh "^\s*obj\-\$[(]CONFIG_.*\s*\+=.*\s${i//[_-]/[_-]}\.o" "${TMPDIR}"/unmodule.tmp|sed -e 's:).*$::g' -e 's:^.*(CONFIG_::'|while read i; do
			m2y "$i"
		done
	done
}

m2y(){
	grep -q "^CONFIG_$1=[my]$" .config || return
	echo -ne " &$1"
	# buggy dependences only
	case "$1" in
	ACPI_VIDEO)m2y VIDEO_OUTPUT_CONTROL;;
	esac
}

LICENSE(){
	grep -qF "#include <linux/module.h>" $1 || sed -i -e 's:^#include:#include <linux/module.h>\n#include:' $1
	grep -q "MODULE_LICENSE" $1 || echo "MODULE_LICENSE(\"${2:-GPL}\");" >>$1
}

userspace(){
	local i f t img='initramfs.lst' c='' k k1 libdir="$(get_libdir)"
	# klibc in progress
	if [[ -n "$KERNEL_KLIBC_SRC" ]]; then
		if [[ "$KERNEL_KLIBC_SRC" == "*" ]]; then
			i="$(best_version dev-libs/klibc)"
			i="${i##*/}"
			i="${i%%-r*}"
			KERNEL_KLIBC_SRC="$PORTDIR/distfiles/$i.tar.bz2"
			KERNEL_KLIBC_DIR="${KERNEL_KLIBC_DIR:-${S}/usr}/$i"
		fi
		if [[ -z "$KERNEL_KLIBC_DIR" ]]; then
			i="${KERNEL_KLIBC_SRC##*/}"
			i="${i%.tar.bz2}"
			KERNEL_KLIBC_DIR="${S}/usr/$i"
		fi
		tar -xaf "$KERNEL_KLIBC_SRC" -C "${KERNEL_KLIBC_DIR%/*}"
	fi
	if [[ -n "$KERNEL_KLIBC_DIR" ]]; then
		einfo "Making KLIBC from $KERNEL_KLIBC_SRC $KERNEL_KLIBC_DIR"
		[[ -d "$KERNEL_KLIBC_DIR" ]] || die
#		export CFLAGS="$CFLAGS --sysroot=${S}"
#		export KERNEL_UTILS_CFLAGS="$KERNEL_UTILS_CFLAGS --sysroot=${S}"
		kmake -C "$KERNEL_KLIBC_DIR" KLIBCKERNELSRC="${S}" INSTALLDIR="/usr" INSTALLROOT="${S}" all install
		k="${S}/usr"
		k1="$k/bin"
	else
		k="$ROOT/usr/$libdir"
		k1="$k/klibc/bin"
	fi

	if use compressed; then
		einfo "Compressing lib.loopfs"
		mksquashfs "${BDIR}/lib" lib.loopfs $(use xz&&echo "-comp xz") -all-root -no-recovery -no-progress
		c=NONE
	fi
	einfo "Preparing initramfs"
	mkdir "${S}/usr/sbin"
	cp "${SHARE}/kpnp" "${S}/usr/sbin/init"
	{
	[[ -e "$k1/sh" ]] || echo "slink /bin/sh sh.shared 0755 0 0"
	use compressed && echo "file lib.loopfs lib.loopfs 0755 0 0"
	for i in "${BDIR}/" 'usr/lib/klibc*' "$k"/{bin,lib,klibc/bin} '-L usr/'{bin,sbin,etc}/'*'; do
		f="${i##*/}"
		find ${i%/*} ${f:+-name} "${f}" 2>/dev/null
	done | while read i; do
		[[ -e "$i" ]] || [[ -L "$i" ]] || continue
		f="${i#$BDIR}"
		f="/${f#/}"
		case "$f" in
		/usr/lib*|*/loop.ko|*/squashfs.ko);;
		/lib*/*)use compressed && continue;;
		*/bin/*)f="/bin/${f##*/bin/}";;
		/usr/*)f="${f#/usr}";;
		esac
		if [[ -f "$i" ]]; then
			if [[ -L "$i" ]]; then
				echo "slink $f $(readlink "$i") 0755 0 0"
			else
				echo "file $f $i 0755 0 0"
			fi
			f="${f%/*}"
		fi
		while [[ -n "${f#/}" ]]; do
			if [[ -z "${f%%*/$libdir}" ]] && [[ "$libdir" != lib ]]; then
				echo "slink $f lib 0755 0 0"
				f="${f%%$libdir}lib"
			fi
			echo "dir $f 0755 0 0"
			f="${f%/*}"
		done
	done
	} | sort -u >$img
	if use integrated; then
		use thin || c=NONE
	else
		f="initrd-${REAL_KV}.cpio"
		"${S}"/usr/gen_init_cpio $img >$f || die
		img="$f"
	fi
	initramfs $img $c
}
