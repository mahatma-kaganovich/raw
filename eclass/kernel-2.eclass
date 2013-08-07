: ${EAPI:=1} # 3 or neutral
inherit flag-o-matic
[[ "${PV}" == 9999* ]] && KV_FULL="${PV}"
source "${PORTDIR}/eclass/kernel-2.eclass"
EXPORT_FUNCTIONS src_configure src_prepare pkg_prerm

#UROOT="${ROOT}"
UROOT=""
SHARE="${UROOT}/usr/share/genpnprd"
COMP='GZIP BZIP2'

if [[ ${ETYPE} == sources ]]; then

IUSE="${IUSE} +build-kernel custom-cflags +pnp +compressed integrated
	netboot custom-arch embed-hardware staging
	+kernel-drm +kernel-alsa kernel-firmware +sources pnponly lzma xz lzo
	external-firmware xen +smp tools multitarget +multislot thin
	lvm evms device-mapper unionfs luks gpg iscsi e2fsprogs mdadm
	lguest acpi klibc +genkernel monolythe update-boot"
DEPEND="${DEPEND}
	!<app-portage/ppatch-0.08-r16
	pnp? ( sys-kernel/genpnprd )
	lzma? ( app-arch/xz-utils )
	xz? ( app-arch/xz-utils )
	lzo? ( app-arch/lzop )
	build-kernel? (
		compressed? ( sys-kernel/genpnprd )
		kernel-drm? ( !x11-base/x11-drm )
		kernel-alsa? ( !media-sound/alsa-driver )
		kernel-firmware? ( !sys-kernel/linux-firmware )
		klibc? ( dev-libs/klibc )
		genkernel? (
			>=sys-kernel/genkernel-3.4.10.903
			luks? ( sys-fs/cryptsetup )
			evms? ( sys-fs/evms )
		)
		!klibc? ( !genkernel? (
			sys-apps/busybox
			e2fsprogs? ( sys-apps/util-linux )
			mdadm? ( sys-fs/mdadm )
			device-mapper? ( sys-fs/dmraid )
			lvm? ( sys-fs/lvm2 )
			unionfs? ( sys-fs/unionfs-fuse )
			iscsi? ( sys-block/open-iscsi )
			gpg? ( app-crypt/gnupg )
			luks? ( sys-fs/cryptsetup )
			evms? ( sys-fs/evms )
		) )
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
	local i s='[ 	
]'
	for i in "${@}"; do
		CF="${CF//$s[+-]${i#[+-]}$s}"
		CF="${CF//$s${i#[+-]}$s} ${i} "
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

load_conf(){
	[[ -e "${CONFIG_ROOT}${KERNEL_CONF:=/etc/kernels/kernel.conf}" ]] && source "${CONFIG_ROOT}${KERNEL_CONF}"
}

load_conf

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
	REAL_KV=''
	use genkernel && REAL_KV="$(gen_KV)"
	: ${REAL_KV:="$(kmake kernelrelease)"}
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
		filter-flags "-msse*" -mmmx -m3dnow -mavx "-mfpmath=*"
		cflags="$(flags_nosp "${CFLAGS} ${cflags}")"
		aflags="$cflags" # at least now
		ldflags="$(flags_nosp "$(extract_flags -Wl, ${LDFLAGS}) ${ldflags}")" #"
	fi
	[[ -n "${cflags}" ]] && sed -i -e "s/^\(KBUILD_CFLAGS.*-O.\)/\1 ${cflags}/g" Makefile
	[[ -n "${aflags}" ]] && sed -i -e "s/^\(AFLAGS_[A-Z]*[	 ]*=\)$/\1 ${aflags}/" Makefile
	[[ -n "${ldflags}" ]] && sed -i -e "s/^\(LDFLAGS_[A-Z]*[	 ]*=\)$/\1 ${ldflags}/" Makefile
	export comp=''
	# kmake & genkernel
	export MAKEOPTS+=" DEPMOD=$([[ -x /sbin/depmod ]] && echo /sbin/depmod || echo /usr/bin/depmod)"
	use build-kernel || return
	useconfig
	kconfig
	grep -q "^CONFIG_SQUASHFS=" .config && for i in $COMP; do
		( [[ "$i" == GZIP ]] || grep -q "^CONFIG_SQUASHFS_$i=" .config ) && ( mksquashfs |& grep -q "^\s*${i,,}\s*" ) && comp="${i,,}"
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
		$i || break
		i=false
		if use embed-hardware; then
			einfo "Reconfiguring kernel with hardware detect"
			KERNEL_CONFIG+=" ###detect: $(detects)"
			kconfig
			i="${KERNEL_CLEANUP:-arch/$(arch) drivers/dma}"
			einfo "Applying KERNEL_CLEANUP='$i'"
			KERNEL_CONFIG+=" ###cleanup: ${KERNEL_CONFIG2} $(detects_cleanup $i)"
			kconfig
			i=true
		fi
		if use monolythe; then
			einfo "Reconfiguring kernel as 'monolythe'"
			use !embed-hadrware && [[ -z "$KERNEL_CLEANUP" ]] && {
				ewarn "Useflag 'monolythe' requires at least USE='embed-hadrware' KERNEL_CLEANUP='.'"
				ewarn "(or too global KERNEL_[CONFIG]) - You are warned!"
			}
			sed -i -e 's:^CONFIG_MODULES=y$:# CONFIG_MODULES is not set:' .config
			sed -i -e 's:=m$:=y:g' .config
			yes '' 2>/dev/null | kmake oldconfig &>/dev/null
			i=true
		fi
		( [[ -n "$KERNEL_CLEANUP" ]] || use monolythe ) && use sources && kmake clean
		$i || break
	done

	KV="${KV0}"
	check_kv

    if grep -q "=m$" .config; then
	einfo "Preparing modules"

	# fix modules order & presence in /etc/modflags
	sed -e 's:.*/::' -e 's:.ko*::' -e 's:-:_:' <modules.order >"${TMPDIR}/mod.order" || die
	for i in "${TMPDIR}/overlay-rd/etc/modflags/"*; do
		grep -xoFf "$i" "${TMPDIR}/mod.order" >"${TMPDIR}/_mod" && mv "${TMPDIR}/_mod" "$i"
	done

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
    fi

	cd "${S}"
	if use external-firmware; then
		mkdir -p "${BDIR}"/lib 2>/dev/null
		cp -na "$ROOT"/lib/firmware "${BDIR}"/lib
	fi

	if use sources || use klibc; then
		einfo "Preparing kernel headers"
		kmake headers_install #$(use compressed && echo _all)
	fi

	[[ -n "$KERNEL_MAKE_ADD" ]] && kmake $KERNEL_MAKE_ADD

	use klibc && userspace

	if use tools; then
		einfo "Compiling tools"
		mktools
	fi

	for i in `find Documentation -name "*.c"`; do
		_cc $i
	done

	if use !klibc && use !genkernel; then
		/usr/bin/genpnprd --IMAGE "initrd-${REAL_KV}.img" --S "${S}" --OVERLAY "${TMPDIR}/overlay-rd" --FILES "/bin/busybox
			$(use e2fsprogs && echo /sbin/blkid)
			$(use mdadm && echo /sbin/mdadm /sbin/mdmon)
			$(use device-mapper && echo /usr/sbin/dmraid)
			$(use lvm && echo /sbin/lvm /sbin/dmsetup)
			$(use unionfs && echo /sbin/unionfs)
			$(use luks && echo /bin/cryptsetup)
			$(use gpg && echo /sbin/gpg)
			$(use iscsi && echo /usr/sbin/iscsistart)
		" || die "genpnprd failed"
	fi
	use genkernel || return
	use klibc && mv initrd-${REAL_KV}.img initrd-${REAL_KV}.img.klibc

	einfo "Generating initrd image"
	local p="$(use__ lvm lvm2) $(use__ evms) $(use__ luks) $(use__ gpg) $(use__ iscsi) $(use__ device-mapper dmraid) $(use__ unionfs) $(use__ e2fsprogs disklabel) $(use__ mdadm)"
	use netboot && p+=" --netboot"
	use monolythe && p+=" --static"
	if use pnp || use compressed; then
		use monolythe || p+=" --all-ramdisk-modules"
		[[ -e "${BDIR}/lib/firmware" ]] && p="${p} --firmware --firmware-dir=\"${BDIR}/lib/firmware\""
	fi
	run_genkernel ramdisk "--kerneldir=\"${S}\" --bootdir=\"${S}\" --module-prefix=\"${BDIR}\" --no-mountboot ${p}"
	r=`ls initramfs*-${REAL_KV}||ls "$TMPDIR"/genkernel/initramfs*` && mv "$r" "initrd-${REAL_KV}.img" || die "initramfs rename failed"
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
	local c="${2:-${COMP##* }}"
	if use integrated; then
		einfo "Integrating initramfs"
		echo "CONFIG_INITRAMFS_SOURCE=\"$1\"
CONFIG_INITRAMFS_ROOT_UID=0
CONFIG_INITRAMFS_ROOT_GID=0
CONFIG_INITRAMFS_COMPRESSION_$c=y" >>.config
		yes '' 2>/dev/null | kmake oldconfig &>/dev/null
		kmake bzImage
	elif [[ "${c:-NONE}" != NONE ]]; then
		c="${c,,} -9"
		c="${c//lzo/lzop}"
		c="${c//gzip/gzip -n}"
		c="${c//xz -9/xz --check=crc32 --lzma2=dict=1MiB}"
		${c} -c "$1" >"${1%.cpio}.img" || die
		rm "$1"
	else
		[[ -e "$1" ]] && rename .cpio .img "$1"
	fi
}

kernel-2_src_install() {
	check_kv
	cd "${S}" || die
	rm -f .config.old *.loopfs
	if [[ ${ETYPE} == sources ]] && use build-kernel; then
		rm -f lib/firmware "lib/modules/${REAL_KV}/kernel"
		dodir /boot
		local f f1
		if ! use integrated; then
			insinto "/boot"
			for f in initrd-"${REAL_KV}".img{,.thin,.klibc}; do
				[[ -e "$f" ]] && doins "$f"
			done
		fi
		if use kernel-firmware; then
			ewarn "Useflag 'kernel-firmware' must be enabled one branch to avoid collisions"
		else
			rm ${BDIR}/lib/firmware -Rf
		fi
		[[ -e "${BDIR}" ]] && ( mv "${BDIR}"/* "${D}/" || die )
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
			for i in "${D}/boot/initrd-${REAL_KV}.img"{,.*}; do
				local x
				for x in "/boot/initrd-${SLOT}.img"{,"${i##*.img}"}; do
					[[ -e "$i" ]] && ! [[ -e "${D}$x" ]] && dosym "${i##*/}" "$x"
				done
			done
		fi
		if use sources ; then
			dodir /usr/src
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
				mksquash "${S}" "${f}" || die
				chmod 755 "${f}"
				rm "${S}" -Rf
			fi
		else
			cd "${WORKDIR}"
			rm "${S}" -Rf
		fi
		[[ -n "$sym" ]] && dosym "$sym" /usr/src/linux-${SLOT}
	fi
	install_universal
	[[ ${ETYPE} == headers ]] && install_headers
	[[ ${ETYPE} == sources ]] && install_sources
}

to_overlay(){
	use build-kernel || return
	einfo "Generating boot image overlay (if configured)"
	local i="${TMPDIR}/overlay-rd" x
	for x in etc/modflags; do
		mkdir -p "$i/$x"
		cp -a "$SHARE/$x" "$i/$x" -aT
	done
	for x in $(_lsmod drivers/dma); do
		{
			_lsmod crypto/async_tx
			echo raid456
		} >>"$i/etc/modflags/$x"
	done
	bash "${SHARE}/genpkgrd" "${i}" "${KERNEL_IMAGE_FILES}" "${KERNEL_IMAGE_FILES2}" "${KERNEL_IMAGE_PACKAGES}"
}

run_genkernel(){
	[[ ! -e "${TMPDIR}/genkernel-cache" ]] && cp "${UROOT}/var/cache/genkernel" "${TMPDIR}/genkernel-cache" -r
	if use netboot; then
		cp "$UROOT/usr/share/genkernel/netboot/busy-config" "$TMPDIR"
	else
		cp "$UROOT/usr/share/genkernel/defaults/busy-config" "$TMPDIR"
	fi
	for i in $(use selinux && echo SELINUX=y) PAM=n STATIC=y DEBUG=n NO_DEBUG_LIB=y DMALLOC=n EFENCE=n FEATURE_MOUNT_NFS=n \
	    FEATURE_MOUNT_CIFS=y MODPROBE_SMALL=n INSMOD=y RMMOD=y MODPROBE=y LSMOD=n FEATURE_MODPROBE_BLACKLIST=y TELNETD=y \
	    MKFS_EXT2=n; do
		sed -i -e "s:^.*CONFIG_${i%%=*}[= ].*\$:CONFIG_$i:" "$TMPDIR/busy-config"
		grep -q "CONFIG_${i%%=*}[= ]" "$TMPDIR/busy-config" || echo "CONFIG_$i" >>"$TMPDIR/busy-config"
	done
	# cpio works fine without loopback, but may panish sandbox
	cp /usr/bin/genkernel "${S}" || die
	sed -i -e 's/has_loop/true/' "${S}/genkernel"
	local a="$(arch "" 1)" opt=
	ls "$UROOT/usr/share/genkernel/arch/$a/*busy*" >/dev/null 2>&1 || opt+=" --busybox-config=${TMPDIR}/busy-config"
	# e2fsprogs & mdraid need more crosscompile info
	ac_cv_target="${CTARGET:-${CHOST}}" ac_cv_build="${CBUILD}" ac_cv_host="${CHOST:-${CTARGET}}" CC="$(tc-getCC)" LD="$(tc-getLD)" CXX="$(tc-getCXX)" CPP="$(tc-getCPP)" AS="$(tc-getAS)" \
	CFLAGS="${KERNEL_UTILS_CFLAGS}" LDFLAGS="${KERNEL_GENKERNEL_LDFLAGS}" "${S}/genkernel" $opt\
		--config=/etc/kernels/genkernel.conf \
		--cachedir="${TMPDIR}/genkernel-cache" \
		--tempdir="${TMPDIR}/genkernel" \
		--logfile="${TMPDIR}/genkernel.log" \
		--arch-override=${a} \
		--compress-initramfs-type=bzip2 \
		--utils-arch=${a} --utils-cross-compile=${CTARGET:-${CHOST}}- \
		$* ${KERNEL_GENKERNEL} || die "genkernel failed"
	rm "${S}/genkernel"
}

cfg(){
	KERNEL_CONFIG="$* ${KERNEL_CONFIG}"
}

cfg_(){
	KERNEL_CONFIG+=" $*"
}

cfg_use(){
	local i u="$1"
	shift
	for i in $* "#use:$u
"; do
		use $u && cfg $i || cfg -${i#[+=&]}
	done
}

cfg_use_(){
	local i u="$1"
	shift
	cfg_ "
	#use:$u "
	for i in $* ; do
		use $u && cfg_ $i || cfg_ -${i#[+=&]}
	done
}

_cfg_use_(){
	local i u="$1"
	shift
	cfg_ "
	#use:$u "
	for i in $* "#use:$u
"; do
		use $u && cfg_ $i || cfg -${i#[+=&]}
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
	local i o j
	# staging submenu will be opened, but no auto-m
	use staging || KERNEL_MODULES="${KERNEL_MODULES} -drivers/staging"
	if use !embed-hardware; then
		cfg EXT2_FS
		use compressed || use pnp && cfg +SQUASHFS +CRAMFS +BLK_DEV_LOOP
	fi
	local cfg_exclude=" HAVE_DMA_API_DEBUG "
	local cfg_exclude=
	if use kernel-drm ; then
		cfg +DRM
	else
		cfg -DRM
	fi
	cfg_use kernel-alsa SND
	use kernel-alsa || cfg +SOUND_PRIME
	use lzo && COMP+=' LZO'
	use lzma && COMP+=' LZMA XZ'
	use xz && COMP+=' XZ'
	for i in $COMP; do
		o="$i $o"
	done
	o="${o% }"
	cfg "KERNEL_${o// /;KERNEL_}"
	cfg $o
	cfg_ "
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
		cfg_ "###$o: "
		source "$i"
		cfg_ "
"
	done
	cfg_ "###respect:${KERNEL_RESPECT//[ 	]/,}" $(for i in $KERNEL_RESPECT; do
		if [[ "$i" != /* ]]; then
			[[ "$i" == */* ]] && i="$i/*.ebuild" || i="*/$i/$i-*.ebuild"
			o=
			for j in $PORTDIR $PORTDIR_OVERLAY; do
				o+=" $j/$i"
			done
			i="$o"
		fi
		for i in $i; do
		[[ -e "$i" ]] || continue
		o=$(/bin/bash -c ". '$i' &>/dev/null;echo \"\$CONFIG_CHECK\"")
		for i in $o; do
			i="${i#\~}"
			[[ "$i" == [A-Z0-9!]* ]] && echo "${i//!/-}"
		done
		done
	done|sort -u) "
"
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
		_PR_.*|_SB_*.CP[0-9]*)let n=n+1;;
		esac
	done
	# FIXME: on bare metal + ht flag without true HT acpi report double CPUs number
	# comment out next line to workaround any other cases to lost core|CPU
	[[ "$CF" == *-PARAVIRT' '* ]] && [[ "$CF" == *-SCHED_SMT* ]] && grep -q "^flags\s*:.*\sht\s" /proc/cpuinfo && let n=n/2
	[[ $n == 0 ]] && die "ACPI CPU enumeration wrong. Say 'USE=-acpi'"
	[[ $n -gt 1 ]] && CF1 SMP
	[[ $n -gt 8 ]] && CF1 X86_BIGSMP
	[[ $n -gt 512 ]] && CF1 MAXSMP
	CF1 NR_CPUS=$n
}

# Kernel-config CPU from CFLAGS and|or /proc/cpuinfo (native)
# use smp: when 'native' = single/multi cpu, ht/mc will be forced ON
cpu2K(){
local i v V="" march=$(march) m64g="HIGHMEM64G -HIGHMEM4G -NOHIGHMEM" freq='' gov='ONDEMAND'
local CF="#
${KERNEL_CONFIG//	/ }
-march=${march}# ${CF//  / }
"
local vendor_id="" model_name="" flags="" cpu_family="" model="" cache_alignment="" fpu="" siblings="" cpu_cores="" processor=""
export PNP_VENDOR="^vendor_id\|"
CF1 -SMP -X86{BIGSMP,GENERIC} X86_{X2APIC,UP_APIC,UP_IOAPIC} -SPARSE_IRQ -CPUSETS X86_INTEL_PSTATE
use xen && CF1 -HIGHMEM64G -HIGHMEM4G NOHIGHMEM X86_PAE
use smp && CF1 SMP X86_BIGSMP SCHED_{SMT,MC} SPARSE_IRQ CPUSETS NUMA
[[ "$(march mtune)" == generic ]] && CF1 X86_GENERIC
if [[ -z "${march}" ]]; then
	CF1 GENERIC_CPU X86_GENERIC
	march="${CTARGET:-${CHOST}}"
	march="${march%%-*}"
fi
case "${march}" in
native)
	export PNP_VENDOR=""
	CF1 -SCHED_{SMT,MC} -X86_{UP_APIC,TSC,PAT,MSR,MCE,CMOV,X2APIC} -MTRR -INTEL_IDLE -KVM_INTEL -KVM_AMD -SPARSE_IRQ -CPUSETS
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
		ht)if ! ( [[ "${model_name}" == *Celeron* ]] && [[ "${model_name}" != *460* ]] && [[ "${model_name}" != *1053* ]] ) && ! grep -q SMP /proc/version; then
			ewarn "Trying to detect hyperthreading/cores under non-SMP kernel:"
			ewarn "SMP+SMT+MC forced, recommended to re-ebuild kernel under new kernel."
			CF1 SMP SCHED_{SMT,MC}
		fi;;
		tsc|pat|msr|mce|cmov|x2apic)CF1 X86_${i^^};;
		mtrr)CF1 ${i^^};;
		pae)CF1 X86_PAE $m64g;;
		mp)CF1 SMP;; # ?
		lm)use multitarget && CF1 64BIT;;
		cmp_legacy)CF1 SMP SCHED_MC -SCHED_SMT;;
		up)ewarn "Running SMP on UP. Recommended useflag '-smp' and '-SMP' in ${KERNEL_CONF}";;
		est)freq+=" X86_ACPI_CPUFREQ";;
		longrun)freq+=" X86_LONGRUN";;
		vmx)CF1 XEN +KVM{,_INTEL} VIRTUALIZATION;;
		svm)CF1 XEN +KVM{,_AMD} VIRTUALIZATION;;
		hypervisor)
			CF1 PARAVIRT{,_GUEST,_SPINLOCKS,_TIME_ACCOUNTING} XEN KVM_GUEST
			case "`lscpu|grep "^Hypervisor vendor:"`" in
			*KVM)CF1 -XEN;;
			*XEN)CF1 -KVM_GUEST;;
			esac;
			use xen && CF1 XEN
			# at least KVM migration & other asymmetry
			#CF1 -NO_HZ -SCHED_HRTICK -IRQ_TIME_ACCOUNTING
			ewarn "*************************************************************"
			ewarn "** With QEMU VM migration I get best results with cmdline: **"
			ewarn "** nohz=off divider=10 clocksource=acpi_pm notsc  (FIXME!) **"
			ewarn "*************************************************************"
		;;
#		xtopology)CF1 SCHED_SMT;;
		hwpstate)grep -qsF X86_FEATURE_HW_PSTATE "${S}/drivers/cpufreq/powernow-k8.c" && freq+=" X86_ACPI_CPUFREQ -X86_POWERNOW_K8";;
		esac
	done
	use xen && CF1 PARAVIRT{,_GUEST}

	[[ "${processor:=0}" -gt 0 ]] && CF1 SMP
	[[ $((processor+1)) == "${cpu_cores:-1}" ]] && [[ "${siblings:-1}" == "${cpu_cores:-1}" ]] && CF1 -NUMA
	# xtopology & other flags present only on SMP running anymore
	[[ "${cpu_cores:-1}" -gt 1 ]] && CF1 SMP SCHED_MC
	[[ "${siblings:-0}" -gt "${cpu_cores:-1}" ]] && CF1 SMP SCHED_SMT
	[[ "$(grep "^siblings\s*:\|^cpu cores\s*:" /proc/cpuinfo|sort -u|wc -l)" -gt 2 ]] && CF1 SMP SCHED_{SMT,MC} NUMA
	[[ "${fpu}" != yes ]] && CF1 MATH_EMULATION

	use acpi && acpi_detect
	[[ -n "${CF##* -NUMA *}" ]] && CF1 SPARSE_IRQ CPUSETS

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
		if [[ "$cpu_family" == 6 ]]; then
			[[ "$model" -gt 25 ]] && CF1 INTEL_IDLE
			# 42 or 45, but+
			[[ "$model" -lt 42 ]] && CF1 -X86_INTEL_PSTATE
		fi
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
		7:*|*\ k8\ *|*\ lm\ *)CF1 MK8;freq="X86_POWERNOW_K8 X86_ACPI_CPUFREQ $freq";gov=CONSERVATIVE;;
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
core2|atom)CF1 M${march^^} $m64g;freq=X86_ACPI_CPUFREQ;;
k6-3)CF1 MK6 $m64g -SCHED_SMT;freq=X86_POWERNOW_K6;V=AMD;;
athlon|athlon-tbird|athlon-4|athlon-xp|athlon-mp)CF1 MK7 $m64g -SCHED_SMT;freq=X86_POWERNOW_K7;V=AMD;;
bdver1|k8|opteron|athlon64|athlon-fx|k8-sse3|opteron-sse3|athlon64-sse3|amdfam10|barcelona)CF1 MK8 $m64g -SCHED_SMT;freq="X86_POWERNOW_K8 X86_ACPI_CPUFREQ";gov=CONSERVATIVE;V=AMD;;
*)CF1 GENERIC_CPU X86_GENERIC;;
esac
case "${CTARGET:-${CHOST}}:$CF" in
	x86_64*|*\ 64BIT\ *)CF1 -MPENTIUM4 -PENTIUMM -X86_GENERIC;;
	*)CF1 -MPSC -GENERIC_CPU;;
esac
use lguest && CF1 -HIGHMEM64G
use acpi && use embed-hardware && acpi_detect
use embed-hardware && [[ -n "$freq" ]] && CF1 -X86_POWERNOW_K8 -X86_ACPI_CPUFREQ $freq CPU_FREQ_GOV_${gov} CPU_FREQ_DEFAULT_GOV_${gov}
CF1 "-CPU_SUP_.*" "CPU_SUP_${V:-.*}"
[ "$V" != INTEL -a -n "$V" ] && CF1 -X86_INTEL_PSTATE
_is_CF1 NUMA || _is_CF1 PARAVIRT && CF1 RCU_NOCB_CPU RCU_NOCB_CPU_ALL
_is_CF1 -PARAVIRT && CF1 JUMP_LABEL
KERNEL_CONFIG="${CF//  / }"
}

_is_CF1(){
	local s='[ 	
]'
	[ -z "${CF//*$s$1$s*}" ]
}

march(){
local a=" ${CFLAGS} ${KERNEL_CFLAGS}"
a="${a##* -${1:-march}=}"
echo "${a%% *}"
}

kconfig(){
	einfo "Configuring kernel"

	# force /etc/kernels/kernel.conf to be last instance after embedding, etc
	local KERNEL_CONFIG="${KERNEL_CONFIG}"
	load_conf

	[[ -e .config ]] || kmake defconfig >/dev/null
	export ${!KERNEL_@}
	while cfg_loop .config.{3,4} ; do
		local ok=false o a
		for o in '' '-relax'; do
		for a in "$(arch)" ''; do
			SRCARCH="$a" /usr/bin/perl "${SHARE}/Kconfig.pl" $o && ok=true && break
		done
		$ok && break
		done
		$ok || die "Kconfig.pl failed"
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

_log(){
	echo "$*"
	"${@}"
	return $?
}

_cc(){
	local c
	einfo "Compiling '$1'"
	for c in "$(use klibc && echo "$klcc -static")" "$(use klibc && echo "$klcc -shared")" "$(tc-getCC)"; do
		[[ -n "$c" ]] && _log $c -I"${S}"/include ${KERNEL_UTILS_CFLAGS} ${LDFLAGS} $1 -s -o ${1%.c} && {
			[[ -n "$2" ]] && ( ( [[ -d "$2" ]] || mkdir -p "$2" ) && cp ${1%.c} "$2" )
			return 0
		}
	done
	return 1
}

_lsmod(){
	find "${@}" -name "*.c"|sed -e 's:^.*/\([^/]*\).c$:\1:' -e 's:-:_:g'
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
	# custom-arch
	use custom-arch && sed -i -e 's/-march=[a-z0-9\-]*//g' -e 's/-mtune=[a-z0-9\-]*//g' arch/*/Makefile*
	# prevent to build twice
#	sed -i -e 's%-I$(srctree)/arch/$(hdr-arch)/include%%' Makefile
	# gcc 4.5+ -O3 -ftracer
	if is-flagq -ftracer; then
		sed -i -e 's:^static unsigned long vmcs_readl:static noinline unsigned long vmcs_readl:' arch/x86/kvm/vmx.c
		sed -i -e 's:^static void sleep_delay:static noinline void sleep_delay:' drivers/media/radio/radio-aimslab.c
	fi
	# gcc 4.7 -O3 or -finline-functions
#	echo "CFLAGS_phy.o += -fno-inline-functions" >>drivers/net/ethernet/intel/e1000e/Makefile
#	echo "CFLAGS_e1000_phy.o += -fno-inline-functions" >>drivers/net/ethernet/intel/igb/Makefile
	sed -i -e 's:^s32 e1000e_phy_has_link_generic:s32 noinline e1000e_phy_has_link_generic:' drivers/net/ethernet/intel/e1000e/phy.c
	sed -i -e 's:^s32 igb_phy_has_link:s32 noinline igb_phy_has_link:' drivers/net/ethernet/intel/igb/e1000_phy.c
	# ;)
	sed -i -e 's:^#if 0$:#if 1:' drivers/net/tokenring/tms380tr.c
	# amdfam10 (???)
	if ( [[ "$a" == i?86-* ]] || [[ "$a" == x86_* ]] ) && is-flagq -fselective-scheduling2; then
	echo "CFLAGS_events.o += -fno-selective-scheduling2" >>drivers/xen/Makefile
	echo "CFLAGS_mballoc.o += -fno-selective-scheduling2" >>fs/ext4/Makefile
	echo "CFLAGS_virtio_balloon.o += -fno-selective-scheduling2" >>drivers/virtio/Makefile
	echo "CFLAGS_ba_action.o += -fno-selective-scheduling2" >>drivers/staging/rt2860/Makefile
	echo "CFLAGS_ba_action.o += -fno-selective-scheduling2" >>drivers/staging/rt2870/Makefile
	echo "CFLAGS_tail_conversion.o += -fno-selective-scheduling2" >>fs/reiser4/Makefile
	fi
	# core2+
	is-flagq -ftree-loop-distribution && echo "CFLAGS_ti_usb_3410_5052.o += -fno-tree-loop-distribution" >>drivers/usb/serial/Makefile
	# deprecated
	sed -i -e 's:defined(@:(@:' kernel/timeconst.pl
	if use multitarget && test_cc -S -m64 -march=nocona && ! test_cc -S -m64 2>/dev/null; then
		einfo "-m64 arch fix"
		i=" -march=nocona -mno-mmx -mno-sse -mno-sse2 -mno-sse3"
		sed -i -e "s/ -mcmodel=small/ -mcmodel=small$i/" arch/x86/boot/compressed/Makefile
		sed -i -e "s/\(KBUILD_AFLAGS += -m64\)$/\1$i/" arch/x86/Makefile*
	fi
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
			losetup $x && losetup -d $x
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
	if use update-boot; then
		mount_boot=false
		i="${ROOT}/boot"
		i="${i//\/\///}"
		! grep -q "^[^ ]* $i " /proc/mounts && mount $i && mount_boot=true
	fi
}

kernel-2_pkg_postinst() {
	[[ ${ETYPE} == sources ]] && postinst_sources
	####
	[[ ${ETYPE} == sources ]] && use build-kernel || return
	use pnp && use compressed && mount -o loop,ro "${ROOT}"/usr/src/linux-"${REAL_KV}"{.squashfs,} && elog "Mounted sources: ${REAL_KV}"
	if use update-boot; then
		local m g
		which grub2-mkconfig >/dev/null 2>&1 && m=grub2-mkconfig || m=grub-mkconfig
		for g in ${ROOT}/boot/grub{,2}/grub.cfg; do
			grep -sq "It is automatically generated by grub2*-mkconfig using templates" "$g" && $m -o "$g"
		done
		# todo: lilo?
		$mount_boot && umount ${ROOT}/boot
	else
		ewarn "If your /boot is not mounted, copy next files by hands:"
		ewarn `ls "${D}/boot"`
	fi
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

test_cc(){
	echo "int main(){}"|$(tc-getBUILD_CC) "${@}" -x c - -o /dev/null
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
for i in $(test_cc ${CFLAGS} "${@}" -v |& grep "^[ ]*[^ ]*/as"); do #"
	case "${i}" in
	-mtune=*)aflags="${aflags% ${i}} ${i}";;
	esac
done
echo "${aflags# }"
}

module_reconf(){
	local i c
	sed -e 's:^.*/::g' -e 's:\.ko$::g'|sort -u|while read i; do
		grep -Rh "^\s*obj\-\$[(]CONFIG_.*\s*\+=.*\s${i//[_-]/[_-]}\.o" "${TMPDIR}"/unmodule.tmp|sed -e 's:).*$::g' -e 's:^.*(CONFIG_::'|sort -u|while read c; do
			$1 "$c"
			echo "$i" >>"${TMPDIR}/unmodule.$1"
		done
	done
	echo ''
}

_unmodule(){
	local i a
	find "${@}" -name Makefile|while read i; do
		while read i; do
			a="${i%\\}"
			[[ "$a" == "$i" ]] && echo "$i" || echo -n "$a "
		done <$i
	done |grep "^obj-"|sed -e 's:=:= :' -e 's:\s\s*: :g' >"${TMPDIR}"/unmodule.tmp
}

modalias_reconf(){
	local a i
	sed -e 's:-:_:g'|sort -u|while read a; do
		modalias "$a"||continue
		# strip "later" concurrent drivers
		i="$ALIAS"
		i="${ALIAS%% 1 *}"
		#[[ "$i" != "$ALIAS" ]] && [[ -n "$i" ]] && echo "strip: $ALIAS" >&2
		if [[ -z "$i$2" ]] && use !monolythe; then
			# this module better to keep load later
			# unless monolythe
			sed -i -e "/^$a\$/d" "${WORKDIR}"/modules.pnp_
			continue
		fi
		i="${i:-${ALIAS# 1 }}"
		echo "${i// /
}"
		(cd "${WORKDIR}" && rm -f $i)
	done|module_reconf "${@}"
}

detects(){
	local i a b c d
	_unmodule .
	perl "${SHARE}"/mod2sh.pl "${WORKDIR}" >&2 || die "Unable to run '${SHARE}/mod2sh.pl'"
	. "${WORKDIR}"/modules.alias.sh
	sort -u "${WORKDIR}"/modules.pnp "${TMPDIR}"/overlay-rd/etc/modflags/* >>"${WORKDIR}"/modules.pnp_
	sort -u "${WORKDIR}"/modules.pnp0 "${SHARE}"/etc/modflags/* >>"${WORKDIR}"/modules.pnp0_
	{
		# /sys
		cat `find /sys -name modalias`
		grep -sh "^MODALIAS=" $(find /sys -name uevent)|sed -e 's:^MODALIAS=::'
		# rootfs
		while read a b c d; do
			[[ "$b" == / ]] && [[ "$c" != rootfs ]] && echo "$c" && {
				grep -s "^${a#/dev/} :" /proc/mdstat|grep -o 'raid[0-9]*'
			}
		done </proc/mounts
		# cpu flags
		(cd "${TMPDIR}"/overlay-rd/etc/modflags && cat $(grep "${PNP_VENDOR}^flags" /proc/cpuinfo) $(cat /sys/bus/acpi/devices/*/path|sed -e 's:^\\::') </dev/null 2>/dev/null)
	}|modalias_reconf m2y 1
	(cd "${TMPDIR}"/overlay-rd/etc/modflags && cat $(cat "${TMPDIR}/unmodule.m2y") </dev/null 2>/dev/null)|modalias_reconf m2y
}

detects_cleanup(){
	find "${@}" -name "*.ko" -delete >/dev/null
#	find "${@}" -name "*.o" -delete >/dev/null
	_unmodule "${@}"
	module_reconf m2n <"${WORKDIR}"/modules.pnp0_
}

m2y(){
	grep -q "^CONFIG_$1=[my]$" .config || return
	echo -n " &$1"
	# buggy dependences only
	case "$1" in
	ACPI_VIDEO)m2y VIDEO_OUTPUT_CONTROL;;
	esac
}

m2n(){
	grep -q "^CONFIG_$1=m$" .config || return
	# "-$1" may be too deep
	echo -n " $1="
	sed -i -e "s/^CONFIG_$1=m\$/# CONFIG_$1 is not set/" .config
}

mksquash(){
	local p=1 i
	for i in ${MAKEOPTS}; do
		[[ "$i" == -j* ]] && p=$((${i#-j}-1))
	done
	[[ "${p:-0}" == 0 ]] && p=1
	mksquashfs "${@}" ${comp:+-comp $comp }-b 1048576 -no-recovery -no-progress -processors $p || die "mksquashfs failed"
}

LICENSE(){
	grep -qF "#include <linux/module.h>" $1 || sed -i -e 's:^#include:#include <linux/module.h>\n#include:' $1
	grep -q "MODULE_LICENSE" $1 || echo "MODULE_LICENSE(\"${2:-GPL}\");" >>$1
}

userspace(){
	local i f t img='initramfs.lst' c='' k libdir="$(get_libdir)" mod="$BDIR/lib/modules/$REAL_KV/"
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
		k="usr"
		klcc="${S}/usr/bin/klcc"
		sed -i -e 's:^\(\$prefix = "\):\1$ENV{S}:' "$klcc"
	else
		k="$ROOT/usr/$libdir/klibc"
		klcc=klcc
	fi

	mkdir -p "${S}/usr/"{bin,src,etc}
	for i in "${SHARE}"/*.c; do
		einfo "Compiling $i"
		cp "$i" "${S}/usr/src/" || die
		f="${i##*/}"
		$klcc "${S}/usr/src/$f" -shared -s -o "${S}/usr/bin/${f%.*}" || die
	done
	einfo "Sorting modules to new order"
	mv "${mod}modules.alias" "$TMPDIR/" && bash "${SHARE}"/kpnp --sort "$TMPDIR/modules.alias" >"${mod}modules.alias" || die

	if use compressed; then
		einfo "Compressing lib.loopfs"
		[[ -z "$KERNEL_KLIBC_DIR" ]] && for i in "$ROOT/$libdir/klibc"*; do
			i="${i##*/}"
			ln -s "/usr/lib/$i" "$BDIR/lib/$i"
		done
		mksquash "${BDIR}/lib" lib.loopfs -all-root
		rm "$BDIR/lib/klibc"* -f 2>/dev/null
		c=NONE
	fi
	einfo "Preparing initramfs"
	mkdir "${S}/usr/sbin"
	cp "${SHARE}/kpnp" "${S}/usr/sbin/init"
	{
	echo "slink /init sbin/init 0755 0 0
slink /linuxrc init 0755 0 0
dir . 0755 0 0
dir /usr 0755 0 0
dir /usr/lib 0755 0 0
dir /proc 0755 0 0
dir /sys 0755 0 0"
	[[ -e "$k/bin/sh" ]] || echo "slink /bin/sh sh.shared 0755 0 0"
	use compressed && echo "file lib.loopfs lib.loopfs 0755 0 0"
	[[ "$libdir" != lib ]] && echo "slink /$libdir lib 0755 0 0
slink /usr/$libdir lib 0755 0 0"
	[[ -z "$KERNEL_KLIBC_DIR" ]] && for i in "$ROOT/$libdir/klibc"*; do
		i="${i//\/\///}"
		f="${i##*/}"
		echo "file /usr/lib/$f $i 0755 0 0"
		echo "slink /lib/$f /usr/lib/$f 0755 0 0"
	done
	for i in "${BDIR}/" "$k/bin/" "usr/lib/klibc*" '-L usr/'{bin,sbin,etc}/'*' "${TMPDIR}/overlay-rd/"; do
		f="${i##*/}"
		find ${i%/*} ${f:+-name} "${f}" 2>/dev/null
	done | while read i; do
		i="${i//\/\///}"
		[[ -e "$i" ]] || [[ -L "$i" ]] || continue
		f="${i#$BDIR}"
		f="${f#$ROOT}"
		f="/${f#/}"
		f="${f//\/usr\/$libdir\///usr/lib/}"
		f="${f#/usr/lib/klibc}"
		case "$f" in
		*/overlay-rd/*)f="/${f##*/overlay-rd/}";;
		/usr/lib*|*/loop.ko|*/squashfs.ko);;
		/lib*/*)use compressed && continue;;
		/usr/*)f="${f#/usr}";;
		esac
		if [[ -f "$i" ]]; then
			[[ -L "$i" ]] &&
			    echo "slink $f $(readlink "$i") 0755 0 0" ||
			    echo "file $f $i 0755 0 0"
			f="${f%/*}"
		fi
		while [[ -n "${f#/}" ]]; do
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
	mv "$TMPDIR/modules.alias" "${mod}"
}