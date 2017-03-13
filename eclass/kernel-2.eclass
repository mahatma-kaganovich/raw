: ${EAPI:=1} # 3 or neutral
inherit flag-o-matic global-compat
[[ "${PV}" == 9999* ]] && KV_FULL="${PV}"
# really newer work without, but check-robots want it
[ -e "${PORTDIR}/eclass/kernel-2.eclass" ] && source "${PORTDIR}/eclass/kernel-2.eclass"
EXPORT_FUNCTIONS src_configure src_prepare pkg_prerm

reexport(){
local i f p=$1
shift
for i in "${@}"; do
	f="$(declare -f ${p}_${i})"
	[[ -z "$f" ]] && f='f(){ return;}'
	eval "_saved_${i}() ${f/*()}"
done
}


case ${EAPI:-0} in
	0|1)	reexport kernel-2 pkg_setup src_compile src_install pkg_postinst pkg_preinst
		_saved_src_prepare(){ true; }
	;;
	*)	reexport kernel-2 pkg_setup src_compile src_install pkg_postinst pkg_preinst src_prepare;;
esac


#UROOT="${ROOT}"
UROOT=""
SHARE="${UROOT}/usr/share/genpnprd"
COMP='GZIP BZIP2'

if [[ ${ETYPE} == sources ]]; then

IUSE="${IUSE} +build-kernel custom-cflags +pnp +compressed integrated
	netboot custom-arch embed-hardware
	kernel-firmware +sources pnponly lzma xz lzo lz4
	external-firmware xen +smp kernel-tools +multitarget 64-bit-bfd thin
	lvm evms device-mapper unionfs luks gpg iscsi e2fsprogs mdadm btrfs
	lguest acpi klibc +genkernel monolythe update-boot"
DEPEND="${DEPEND}
	!<app-portage/ppatch-0.08-r16
	pnp? ( sys-kernel/genpnprd )
	lzma? ( app-arch/xz-utils )
	xz? ( app-arch/xz-utils )
	lzo? ( app-arch/lzop )
	lz4? ( app-arch/lz4 )
	build-kernel? (
		compressed? ( sys-kernel/genpnprd )
		kernel-firmware? ( !sys-kernel/linux-firmware )
		klibc? ( dev-libs/klibc )
		genkernel? (
			>=sys-kernel/genkernel-3.4.10.903
			luks? ( sys-fs/cryptsetup )
			evms? ( sys-fs/evms )
			btrfs? ( sys-fs/btrfs-progs )
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


SLOT="${PN%-sources}"
# 2do:
#SLOT=0

PROVIDE="sources? ( virtual/linux-sources )
	!sources? ( virtual/linux-kernel )"

#USEKEY="$(for i in ${!KERNEL_@} ; do
#	echo "${!i} , "
#done | md5sum)"
#IUSE="${IUSE} md5cfg:${USEKEY%% *}"

for i in "${SHARE}"/*.{-use,use}; do
	[[ "${i##*/}" == *_dep_* ]] && . "$i"
	i="${i##*[/:_]}"
	i="${i%.use}"
	i="${i%.-use}"
	IUSE+=" ${i#[0-9]}"
done

fi

BDIR="${WORKDIR}/build"

CF1(){
	local i s='[ 	
]'
	for i in "${@}"; do
		CF="${CF//$s[+-]${i#[+-]}$s/ }"
		CF="${CF//$s${i#[+-]}$s/ } ${i} "
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

external_kconfig(){
	false
}

load_conf(){
	[[ -e "${CONFIG_ROOT}${KERNEL_CONF:=/etc/kernels/kernel.conf}" ]] && {
		einfo "Loading ${CONFIG_ROOT}${KERNEL_CONF}"
		source "${CONFIG_ROOT}${KERNEL_CONF}"
	}
}

kconfig_init(){
	[ -n "$KERNEL_CONFIG" -o "${ETYPE}" != sources ] && return
	eval "`/usr/bin/perl ${SHARE}/Kconfig.pl -config`"
	KERNEL_CONFIG+=" +TR"
	load_conf
}

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

mknod(){
#	echo "mknod $*" >>"${TMPDIR}/overlay-rd/etc/mknod.sh"
	true
}

_filter_f() {
	local f x v=$1
	shift
	for f in ${!v} ; do
		for x in "$@" ; do
			[[ "$f" == $x ]] && continue 2
		done
		echo -n " $f"
	done
}

test_cc(){
	echo "int main(){}"|$(tc-getBUILD_CC) "${@}" -x c - -o /dev/null
}

kernel-2_src_configure() {
	[[ ${ETYPE} == sources ]] || return
	kconfig_init
	cd "${S}"
	cpu2K
	: ${KERNEL_UTILS_CFLAGS:="${CFLAGS}"}

	# ???
#	: ${KERNEL_GENKERNEL_LDFLAGS:="${LDFLAGS}"}
	local i
	[[ -z "$KERNEL_GENKERNEL_LDFLAGS" ]] && for i in $LDFLAGS; do
		[[ "$i" == -Wl,* ]] && KERNEL_GENKERNEL_LDFLAGS+=" $i"
	done
	KERNEL_GENKERNEL_LDFLAGS="$(flags_nosp "$KERNEL_GENKERNEL_LDFLAGS")"

	local cflags="${KERNEL_CFLAGS}" aflags="${KERNEL_ASFLAGS}" ldflags="${KERNEL_LDFLAGS}"
	if use custom-cflags; then
		use custom-arch || filter-flags "-march=*" "-mcpu=*"
#		case "${CTARGET:-${CHOST}}" in
#		i?86*)filter-flags -fschedule-insns;;
#		esac
#		for i in -fno-PIE; do
#			test_cc $i && cflags+=" $i"
#		done
		[[ "$(gcc-version)" == 4.8 ]] && append-flags -fno-inline-functions
		cflags="$(flags_nosp "$(_filter_f CFLAGS "-msse*" -mmmx -m3dnow -mavx "-mfpmath=*" '-flto*' '-*-lto-*' -fuse-linker-plugin) ${cflags}")" #"
		aflags="$cflags" # at least now
		ldflags="$(flags_nosp "$(extract_flags -Wl, ${LDFLAGS}) ${ldflags}")" #"
	fi
	use unionfs && KERNEL_UTILS_CFLAGS+=" -std=gnu89"
	cfg_ '###CFLAGS:'
	is-flagq -fstack-protector && cfg_ CC_STACKPROTECTOR{,_REGULAR}
	is-flagq -fstack-protector-strong && cfg_ CC_STACKPROTECTOR_STRONG
	[[ "$(cflg O)" == s ]] && cfg_ CC_OPTIMIZE_FOR_SIZE
	cfg_ "
"
	[[ -n "${cflags}" ]] && sed -i -e "s/^\(KBUILD_CFLAGS.*-O.\)/\1 ${cflags}/g" Makefile
	[[ -n "${aflags}" ]] && sed -i -e "s/^\(AFLAGS_[A-Z]*[	 ]*=\)$/\1 ${aflags}/" Makefile
	[[ -n "${ldflags}" ]] && sed -i -e "s/^\(LDFLAGS_[A-Z]*[	 ]*=\)$/\1 ${ldflags}/" Makefile
	export comp=''
	# kmake & genkernel
	export MAKEOPTS+=" DEPMOD=$([[ -x /sbin/depmod ]] && echo /sbin/depmod || echo /usr/bin/depmod)"
	use build-kernel || return
	mkdir -p "${TMPDIR}/overlay-rd/etc/"
	export -f mknod
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

ext_firmware(){
	local m f e d x=
	local s="$1"
	shift
	einfo "Checking firmware $s -> $*"
	use external-firmware && echo "Copying external firmware:"
	cd "$S"
	find . -name "*.ko" | while read m; do
		modinfo "$m"|grep "^firmware:"|sed -e 's:^.* ::'|while read f; do
			f="firmware/$f"
			m="${m##*/}"
			[ -e "$1/$f" ] && continue
			[ -e "$s/$f" ] && e=true || e=false
			echo " $m: ${f#firmware/}$($e || echo ' - not found')"
			use external-firmware || continue
			$e && for d in "${@}"; do
				if [ -n "$d" ]; then
					mkdir -p "$d/${f%/*}"
					cp -aT "$s/$f" "$d/$f" || die
				else
					x+=" $f"
				fi
			done
		done
	done
	[ -n "$x" ] && KERNEL_CONFIG+=" EXTRA_FIRMWARE=\"${x# }\" EXTRA_FIRMWARE_DIR=\"$s\""
}

kernel-2_src_compile() {
	kconfig_init

	if [[ "${EAPI}" == 1 ]]; then
		kernel-2_src_prepare
		kernel-2_src_configure
	fi
	####

	_saved_src_compile

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
			cp .config .config.stage1
			cfg_ "###detect: $(detects)"
#			use external-firmware && ext_firmware "$ROOT/lib" . "$WORKDIR/external-firmware"
			_cmdline "`modprobe_opt ''`"
			kconfig
			i="${KERNEL_CLEANUP:-arch/$(arch) drivers/dma}"
			einfo "Applying KERNEL_CLEANUP='$i'"
			cfg_ "###cleanup: ${KERNEL_CONFIG2} $(detects_cleanup $i)"
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
	if [ "$VIRT" = 2 ]; then
		rm -rf "${BDIR}/lib/firmware"
	else
		ln -s ../firmware lib/firmware
	fi
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
	use external-firmware && ext_firmware "$ROOT/lib" "$BDIR/lib"

	if use sources || use klibc; then
		einfo "Preparing kernel headers"
		kmake headers_install #$(use compressed && echo _all)
	fi

	[[ -n "$KERNEL_MAKE_ADD" ]] && kmake $KERNEL_MAKE_ADD

	use klibc && userspace

	if use kernel-tools; then
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
	use klibc && mv initrd-${REAL_KV}.img initrd-${REAL_KV}.klibc.img

	einfo "Generating initrd image"
	local p="$(use__ lvm lvm2) $(use__ evms) $(use__ luks) $(use__ gpg) $(use__ iscsi) $(use__ device-mapper dmraid) $(use__ unionfs) $(use__ e2fsprogs disklabel) $(use__ mdadm) $(use__ btrfs)"
	use netboot && p+=" --netboot"
	use monolythe && p+=" --static"
	if use pnp || use compressed; then
		use monolythe || p+=" --all-ramdisk-modules"
		[[ -e "${BDIR}/lib/firmware" ]] && p="${p} --firmware --firmware-dir=\"${BDIR}/lib/firmware\""
	fi
	run_genkernel ramdisk "--kerneldir=\"${S}\" --bootdir=\"${S}\" --module-prefix=\"${BDIR}\" --no-mountboot ${p}"
	r=`ls initramfs*-${REAL_KV}||ls "$TMPDIR"/genkernel/initramfs*` && mv "$r" "initrd-${REAL_KV}.img" || die "initramfs rename failed"
	einfo "Preparing boot image"
	bash "${SHARE}/genpnprd" "${S}/initrd-${REAL_KV}.img" "$( (use !pnp && echo nopnp)||(use pnponly && echo pnponly)||echo pnp )" "${TMPDIR}"/overlay-rd "${S}" ${comp:+--COMPRESS $comp} $(use thin||echo --THIN -)|| die
	local i="initrd-${REAL_KV}.cpio" i1="initrd-${REAL_KV}.img"
	( use pnp || use compressed || (use integrated && use !thin) ) &&
		gzip -dc "$i1"  >"$i" && rm "$i1"
	if use integrated && use thin; then
		i="initrd-${REAL_KV}.thin.cpio"
		i1="${i1%.img}.thin.img"
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

_dosym(){
	[[ -e "${D}/boot/$1" ]] && ! [[ -e "${D}/boot/$2" ]] && dosym "$1" "/boot/$2"
}

kernel-2_src_install() {
	if [[ ${ETYPE} == sources ]] && use build-kernel; then
		kconfig_init
		check_kv
		local slot0=false
		[ "$SLOT" = "${PN%-sources}" -o "$SLOT" = 0 ] && slot0=true
		cd "${S}" || die
		rm -f .config.old *.loopfs
		rm -f lib/firmware "lib/modules/${REAL_KV}/kernel"
		dodir /boot
		local f f1
		if ! use integrated; then
			insinto "/boot"
			for f in initrd-"${REAL_KV}"{,.thin,.klibc}.img; do
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
		use kernel-tools && mktools INSTALL_PATH="${D}" DESTDIR="${D}" install
		for f in vmlinuz System.map config ; do
			f1="${D}/boot/${f}"
			if [[ -e "${f1}" ]] ; then
				mv "$(readlink -f ${f1})" "${f1}-${REAL_KV}"
				rm "${f1}" -f &>/dev/null
			fi
		done
		for f in vmlinuz config; do
			$slot0 && _dosym "${f}-${REAL_KV}" "${f}-${SLOT}"
		done
		for f in vmlinuz; do
			for i in '' .thin .klibc .noinitrd; do
				[ "$i" = .noinitrd -o -e "${D}/boot/initrd-${REAL_KV}$i.img" ] || continue
				[ "$i" = .noinitrd ] && (use !embed-hardware || use integrated) && continue
				[ "$i" != '' -a "$f" != vmlinuz ] 
				_dosym "${f}-${REAL_KV}" "${f}-${REAL_KV}$i"
				$slot0 || continue
				_dosym "${f}-${REAL_KV}" "${f}-${SLOT}$i"
				_dosym "initrd-${REAL_KV}$i.img" "initrd-${SLOT}$i.img"
			done
		done
		f="${D}/boot/config-${REAL_KV}"
		[[ -e "$f" ]] || cp "${S}/.config" "$f"
		local sym=''
		$slot0 && use sources && sym="linux-${KV_FULL}"
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
		# inherited
		[[ -e "${S}" ]] || mv "${D}"/usr/src/linux* "${WORKDIR}" || mkdir -p "${S}"
		[[ -n "$sym" ]] && dosym "$sym" /usr/src/linux-${SLOT}
	fi
	_saved_src_install
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

unmcode(){
	# temporary workaround against cosher appended early microcode. until I cannot split concatenated cpios
	# single-cpio works too [on intel], but probably unsafe on too broken cpus
	sed -i -e "s:^CONFIG_MICROCODE=$1:CONFIG_MICROCODE=$2:" "$S"/.config
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
	unmcode y n
	CFLAGS="${KERNEL_UTILS_CFLAGS}" LDFLAGS="${KERNEL_GENKERNEL_LDFLAGS}" "${S}/genkernel" $opt\
		--config=/etc/kernels/genkernel.conf \
		--cachedir="${TMPDIR}/genkernel-cache" \
		--tempdir="${TMPDIR}/genkernel" \
		--logfile="${TMPDIR}/genkernel.log" \
		--arch-override=${a} \
		--compress-initramfs-type=bzip2 \
		--utils-arch=${a} --utils-cross-compile=${CTARGET:-${CHOST}}- \
		$* ${KERNEL_GENKERNEL} || {
			unmcode n y
			die "genkernel failed"
	}
	unmcode n y
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

_cmdline(){
	local i="$KERNEL_CONFIG_CMDLINE"
	einfo "cmdline $*"
	for i in '"' "'"; do # 2be removed, old def.config compat
		[ "${KERNEL_CONFIG_CMDLINE%$i}" != "$KERNEL_CONFIG_CMDLINE" ] && KERNEL_CONFIG_CMDLINE="${KERNEL_CONFIG_CMDLINE%$i} $*$i" && return
	done
	KERNEL_CONFIG_CMDLINE+="${KERNEL_CONFIG_CMDLINE:+ } $*"
}

cfg_loop(){
	local k=".config.loop.$1" i=0 k1 ne=true rm= l=false
	grep "CONFIG" .config >$k
	while [[ $i -lt $1 ]]; do
		k1=".config.loop.$[i++]"
		rm+=" $k1"
		if cmp -s $k1 $k ; then
			ne=false
		elif ! $ne; then
			if diff -U 0 $k1 $k >"$k1.diff"; then
				unlink "$k1.diff"
			else
				l=true
			fi
		fi
	done
	$l &&	if [ -z "$cfgloop" ]; then
			cfgloop=" `echo $(grep -oh "CONFIG_[^ =]*" .config.loop.*.diff|sort -u|sed -e 's:^CONFIG_::' -e 's:$:=m:')`"
			export KERNEL_CONFIG="$KERNEL_CONFIG #loop:$cfgloop"
			ne=true
		else
			ewarn "Config deadloop! Details in: $(echo .config.loop.*.diff)."
			ewarn "Dub options: $(grep -o "CONFIG_[^ =]*" .config.loop.*.diff|sort -u)"
		fi
	$ne || rm -f $rm $k
	$ne
}

useconfig(){
	einfo "Preparing KERNEL_CONFIG"
	local i o j
	if use !embed-hardware; then
		cfg EXT2_FS
		use compressed || use pnp && cfg +SQUASHFS +CRAMFS +BLK_DEV_LOOP
	fi
	local cfg_exclude=" HAVE_DMA_API_DEBUG "
	local cfg_exclude=
	use lzo && COMP+=' LZO'
	use lzma && COMP+=' LZMA'
	use lz4 && COMP+=' LZ4'
	use xz && COMP+=' XZ'
	for i in $COMP; do
		o="$i $o"
	done
	o="${o% }"
	cfg "KERNEL_${o// /;KERNEL_}"
	cfg $o
	cfg_ "
"
	ewarn "If failed here after update ('not in IUSE') - touch kernel-2.eclass"
	for i in "${SHARE}"/*use; do
		[[ "${i##*/}" == *_dep_* ]] && continue
		o="${i##*[/:_]}"
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
		_PR_.*|_SB_*.CP[0-9]*|_SB_*.SCK[0-9]*|_SB_.CPUS.C[0-9A-Z][0-9A-Z][0-9A-Z])let n=n+1;;
		esac
	done
	[ "$n" = 0 ] && for i in /sys/bus/acpi/devices/LNXCPU:*/; do
		[ -e "$i" ] && n=n+1
	done
	# On some of bare metal + ht flag without true HT, acpi reports double CPUs number.
	# Dividing to 2 can reduce SMP tables or even make code UP, but many of modern CPUs|MBs
	# use other logic, so try to /2 only if it can do UP (n=2) and USE=-smp
	# - to avoid complete loss of cores power (IMHO 2xSMP overhead is too small).
	# Also using all acpi reported cores have sense for CPU plugging.
	[[ "$CF" == *-PARAVIRT' '* ]] && [[ "$CF" == *-SCHED_SMT* ]] && $fakeHT && grep -q "^flags\s*:.*\sht\s" /proc/cpuinfo &&
		if [[ $n == 2 ]] && use smp; then
			ewarn "On my opinion you have SMP with 2 CPU cores. To force UP build - say USE=-smp"
#		elif [[ $n -gt 1 ]]; then
		elif [[ $n == 2 ]]; then # try UP
			let n=n/2
		fi
	[[ $n == 0 ]] && die "ACPI CPU enumeration wrong. Say 'USE=-acpi'"
	[[ $n -gt 1 ]] && CF1 SMP
	[[ $n -gt 8 ]] && CF1 X86_BIGSMP
	[[ $n -gt 512 ]] && CF1 MAXSMP
	CF1 NR_CPUS=$n
}

pre_embed(){
	use custom-arch || return
	# virtio: speedup build & smart embedding
	local ata='' vblk='' scsi='' vscsi='' e='+' qemu='' cc='' usb=false iuse=" $IUSE "
	use embed-hardware && e='&'
	while read s; do
		case "$s" in
		virtio:*d*v00001AF4): ${qemu:=true};;
		virtio:*d*v*)echo "virtio non-qemu device $s";qemu=false;;
		esac
		case "$s" in
		pci:v00001AF4d*)CF1 VIRTIO_PCI;: ${qemu:=true};;& # required for embedding
		# even if standard input devices still in system - enlight VM kernel or remove PV hw
		pci:v00001AF4d*sv00001AF4*bc09sc00*)CF1 -INPUT_KEYBOARD;;
		pci:v00001AF4d*sv00001AF4*bc09sc02*)CF1 -INPUT_MOUSE;;
		pci:v00001AF4d*sv00001AF4*bc09sc80*)CF1 -INPUT_TABLET;;
		pci:v00001AF4d*sv00001AF4*);; # just ignore all PCI aliases for qemu virtio
		virtio:d00000001v*)CF1 VIRTIO_NET -ETHERNET -PHYLIB -FDDI -ATM;;
		virtio:d00000002v*)CF1 VIRTIO_BLK;vblk=true;;
		pci:v00008086d00007010sv*sd*bc*sc*i*)CF1 ${e}ATA_PIIX;ata=true;;
		pci:v00008086d000025ABsv*sd*bc*sc*i*)CF1 _/drivers/watchdog/.+ I6300ESB_WDT;;
		pci:*bc02sc00i*)echo "ethernet $s";cc+=' ETHERNET +PHYLIB';;
		pci:*bc02sc02i*)echo "FDDI $s";cc+=' +FDDI';;
		pci:*bc02sc03i*)echo "ATM $s";cc+=' +ATM';;
#		pci:*bc04sc01i*)echo "sound $s";cc+=' +SND';;
		pci:*bc01sc06i01)cc+=" ${e}SATA_AHCI";ata=true;;
		pci:*bc01*)echo "storage $s";vblk=false;vscsi=false;;
		pci:v00008086d00007020sv*)CF1 USB_UHCI_HCD;usb=true;;
		pci:v00001B36d00000100sv*);; # qxl
		virtio:d00000008v*)CF1 SCSI_VIRTIO;vscsi=true;;
		virtio:d00000004v*)CF1 -HW_RANDOM_.+ HW_RANDOM_VIRTIO HW_RANDOM;;
		# ...
		virtio:d00000003v*)CF1 VIRTIO_CONSOLE;;
		virtio:d00000005v*)CF1 VIRTIO_BALLOON;;
		virtio:d00000009v*)CF1 NET_9P_VIRTIO;;
		virtio:d0000000Cv*)CF1 CAIF_VIRTIO;;
		virtio:d00000010v*)CF1 DRM_VIRTIO_GPU;;
		virtio:d00000012v*)CF1 VIRTIO_INPUT -INPUT_MISC;;
		*virtio,mmio*)CF1 VIRTIO_MMIO;;
#		pci:*v00001AF4*)echo "unknown possible qemu PCI device $s";unknown=true;;
#		*v00001AF4*)echo "unknown possible qemu device $s";;
		virtio:*)echo "virtio unknown device $s";;
		esac
	done <"${TMPDIR}/sys-modalias"
	if ${qemu:-false}; then
		export VIRT=$[VIRT+1]
		use xen && [[ " $CF " != *' -XEN '* ]] && continue # xen have virtio too + unknown 2me others
		einfo "QEMU virtio environment + USE=custom-arch"
		CF1 VIRTIO -HYPERV -XEN -X86_EXTENDED_PLATFORM
		CF1 _SENSORS_.+ -SERIAL_NONSTANDARD _SERIAL_.+ -SERIAL_8250_EXTENDED SERIAL_8250 -NEW_LEDS -POWER_SUPPLY -REGULATOR
		use iscsi && scsi=true && CF1 ISCSI_TARGET
		use !embed-hardware && vscsi=true && CF1 VIRTIO_.+ .+_VIRTIO
		# -machine ..,usb=off, but respect USE=usb while
		[ -z "${IUSE##* usb *}" ] || $usb || CF1 -USB -USB_.+
		if ${vblk:-${vscsi:-false}} ; then
			einfo " - skip hardware ATA & SCSI drivers"
			CF="_/drivers/(?:scsi|ata)/.+  $CF"
			if ${scsi:-${vscsi:-false}}; then
				CF1 SCSI
			elif ${ata:-false}; then
				CF1 ${e}SCSI +VIRTIO_SCSI # as soon...
			else
				CF1 -SCSI
			fi
			if ${ata:-false}; then
				CF1 ${e}ATA
			else
				CF1 -ATA
			fi
		fi
	fi
	CF1 $cc
}

ucode(){
	local d="${TMPDIR}/overlay-rd/kernel/x86/microcode" f="$TMPDIR/ucode.tmp"
	[ -s "$d/$2.bin" ] && return 1
	cat "$S"/lib/firmware/$1 >"$f" || ( use external-firmware && cat "$ROOT"/lib/firmware/$1 >"$f" ) || return 1
	mkdir -p "$d"
	cp "$f" "$d/$2.bin" && CF1 MICROCODE{,_EARLY}
}

# Kernel-config CPU from CFLAGS and|or /proc/cpuinfo (native)
# use smp: when 'native' = single/multi cpu, ht/mc will be forced ON
cpu2K(){
local i v V="" march=$(cflg) mcpu=$(cflg mcpu=) srcarch=$(arch) m64g="HIGHMEM64G -HIGHMEM4G -NOHIGHMEM" freq='' gov='ONDEMAND' fakeHT=false
local cpuinfo=' vendor_id model_name flags cpu_family model stepping cache_alignment fpu siblings cpu_cores processor cpu ncpus_probed ncpus_active cpucaps '
local knl='(?:INTEL_MIC|VOP|SKIF)_BUS'
march="$march${mcpu:+:$mcpu}"
local CF="#
${KERNEL_CONFIG//	/ }
-march=${march}# ${CF//  / }
"
for i in $cpuinfo; do
	local ${i}=''
done
export PNP_VENDOR="^vendor_id\|"
export VIRT=0
CF1 -SMP -X86{BIGSMP,GENERIC} X86_{X2APIC,UP_APIC,UP_IOAPIC} -SPARSE_IRQ -CPUSETS X86_INTEL_PSTATE INTEL_TXT -$knl
CF1 SPARC_.+_CPUFREQ US3_MC
use xen && CF1 -HIGHMEM64G -HIGHMEM4G NOHIGHMEM X86_PAE -X86_VSMP
use smp && CF1 SMP X86_BIGSMP SCHED_{SMT,MC} SPARSE_IRQ CPUSETS NUMA
# while disable knl features by default
#use smp && $knl
[[ "$(cflg mtune=)" == generic ]] && CF1 X86_GENERIC
if [[ -z "${march}" ]]; then
	CF1 GENERIC_CPU X86_GENERIC
	march="${CTARGET:-${CHOST}}"
	march="${march%%-*}"
fi
case "${march}" in
native|:native|native:native)
	einfo 'Found "-m{arch|cpu}=native" in CFLAGS, detecting CPU & arch hardware constants'
	while read i ; do
		v="${i%%:*}"
		v="${v//	}"
		v="${v// /_}"
		[[ -z "${cpuinfo##* $v *}" ]] && local ${v}="${i#*: }"
	done </proc/cpuinfo
	flags=" ${flags:-.} "

    case "$srcarch" in
    sparc)
	case "$cpu" in
	*UltraSparc\ III*);;
	*UltraSparc\ IIe*)CF1 -.+_US3_.+ -US3_.+;;
	*UltraSparc\ II*)CF1 '-.+_US(?:3|2E)_.+' -US3_.+;;
	esac
	[ "$ncpus_probed:$ncpus_active" = 1:1 ] && CF1 -SMP
    ;;
    *)
#    x86|i386)
	export PNP_VENDOR=""
	CF1 -SCHED_{SMT,MC} -X86_{UP_APIC,TSC,PAT,MSR,MCE,CMOV,X2APIC} -MTRR -INTEL_IDLE -KVM_INTEL -KVM_AMD -SPARSE_IRQ -CPUSETS -INTEL_TXT -$knl
	case "$srcarch" in
	x86|i386)
		if use multitarget || use 64-bit-bfd; then
			CF1 -64BIT
			[ "$KERNEL_ARCH" = x86_64 ] && CF1 64BIT
		fi
		CF1 -XEN # -KVM
		use lguest || CF1 -{PARAVIRT,LGUEST}{,_GUEST} -VIRTUALIZATION -HYPERVISOR_GUEST
	;;
	esac

	fakeHT=true
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
		lm)(use multitarget || use 64-bit-bfd) && CF1 64BIT;;
		cmp_legacy)CF1 SMP SCHED_MC -SCHED_SMT;;
		up)ewarn "Running SMP on UP. Recommended useflag '-smp' and '-SMP' in ${KERNEL_CONF}";;
		est)freq+=" X86_ACPI_CPUFREQ";;
		longrun)freq+=" X86_LONGRUN";;
		vmx)CF1 XEN +KVM{,_INTEL} VIRTUALIZATION;;
		svm)CF1 XEN +KVM{,_AMD} VIRTUALIZATION;;
		smx)CF1 INTEL_TXT;;
		hypervisor)
			export VIRT=$[VIRT+1]
			CF1 PARAVIRT{,_GUEST,_SPINLOCKS,_TIME_ACCOUNTING} XEN KVM_GUEST HYPERVISOR_GUEST
			case "`lscpu|grep "^Hypervisor vendor:"`" in
			*XEN)CF1 -KVM_GUEST -HYPERV -X86_EXTENDED_PLATFORM;;
			?*)CF1 -XEN;; # my KVM = "Microsoft"
			esac;
			# at least KVM migration & other asymmetry
			#CF1 -NO_HZ -SCHED_HRTICK -IRQ_TIME_ACCOUNTING
#			ewarn "*************************************************************"
#			ewarn "** With QEMU VM migration I get best results with cmdline: **"
#			ewarn "** nohz=off divider=10 clocksource=acpi_pm notsc  (FIXME!) **"
#			ewarn "*************************************************************"
		;;
		xtopology)fakeHT=false;;
		hwpstate)grep -qsF X86_FEATURE_HW_PSTATE "${S}/drivers/cpufreq/powernow-k8.c" && freq+=" X86_ACPI_CPUFREQ -X86_POWERNOW_K8";;
		esac
	done
	use xen && CF1 PARAVIRT{,_GUEST} HYPERVISOR_GUEST

	[[ "${processor:=0}" -gt 0 ]] && CF1 SMP
	[[ $((processor+1)) == "${cpu_cores:-1}" ]] && [[ "${siblings:-1}" == "${cpu_cores:-1}" ]] && CF1 -NUMA
	# xtopology & other flags present only on SMP running anymore
	[[ "${cpu_cores:-1}" -gt 1 ]] && CF1 SMP SCHED_MC
	[[ "${siblings:-0}" -gt "${cpu_cores:-1}" ]] && CF1 SMP SCHED_SMT
#	grep -Fqs ',' /sys/devices/system/cpu/cpu*/topology/thread_siblings_list && CF1 SMP SCHED_SMT
	[[ "$(grep "^siblings\s*:\|^cpu cores\s*:" /proc/cpuinfo|sort -u|wc -l)" -gt 2 ]] && CF1 SMP SCHED_{SMT,MC} NUMA
	[[ "${fpu}" != yes ]] && CF1 MATH_EMULATION

	use acpi && acpi_detect
	[[ -n "${CF##* -NUMA *}" ]] && CF1 SPARSE_IRQ CPUSETS

	case "${vendor_id}" in
	*Intel*)
		V=INTEL
		ucode "intel-ucode/$(printf '%02x-%02x-%02x' ${cpu_family} ${model} ${stepping})" $vendor_id
		case "${cpu_family}:${model}:${flags}:${model_name}" in
		*Atom*)CF1 MATOM;;
#		*)CF1 -IOSF_MBI -X86_INTEL_LPSS -X86_INTEL_MID;;&
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
			[[ "$model" -gt 87 ]] && CF $knl
		else
			CF1 -IOSF_MBI '-X86_INTEL_(?:LPSS|MID|CE|QUARK)'
		fi
	;;
	*AMD*)
		V=AMD
		local amf=
		[ "$cpu_family" -ge 21 ] && amf="{,_fam$(printf '%02x' ${cpu_family}})h"
		ucode "amd-ucode/microcode_amd${amf}.bin" $vendor_id
		CF1 -X86_AMD_PLATFORM_DEVICE
		case "${cpu_family}:${model}:${flags}:${model_name}" in
		4:[3789]:*)CF1 M486;;
		4:*\ mmx\ *)CF1 M586MMX;;
		4:*\ tsc\ *)CF1 M586TSC;;
		4:*)CF1 M586;;
		5:*)CF1 MK6;freq=X86_POWERNOW_K6;;
		6:*)CF1 MK7;freq="X86_POWERNOW_K7 X86_CPUFREQ_NFORCE2";;
		7:*|*\ k8\ *|*\ lm\ *)CF1 MK8;freq="X86_POWERNOW_K8 X86_ACPI_CPUFREQ $freq";gov=CONSERVATIVE;;
		*Geode*)CF1 GEODE_LX;;
		*)CF1 X86_AMD_PLATFORM_DEVICE;;& # latest models
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
	pre_embed
	if [ "$VIRT" = 2 ]; then
		rm -rf "${TMPDIR}/overlay-rd/kernel/x86/"
		CF1 -MICROCODE -CPU_FREQ
	fi
    ;;
    esac
	use xen && CF1 XEN
	CF1 MNATIVE
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
	case "$(cflg mtune=)" in
	pentium4|pentium4m|prescott|nocona)CF1 MPENTIUM4 MPSC $m64g;;
	?*)CF1 MPENTIUMM X86_GENERIC GENERIC_CPU $m64g;;
	*)CF1 MPENTIUM4 MPSC $m64g;;
	esac
	freq="X86_ACPI_CPUFREQ X86_P4_CLOCKMOD"
;;
core2)CF1 MCORE2 $m64g X86_INTEL_PSTATE;freq=X86_ACPI_CPUFREQ;;
atom|nehalem|westmere|sandybridge|ivybridge|haswell|broadwell|bonnell|silvermont)CF1 MCORE2 M${march^^} $m64g;freq=X86_ACPI_CPUFREQ;V=INTEL;;
knl)CF1 MCORE2 $m64g $knl;V=INTEL;;
k6-3)CF1 MK6 $m64g -SCHED_SMT;freq=X86_POWERNOW_K6;V=AMD;;
btver1|athlon|athlon-tbird|athlon-4|athlon-xp|athlon-mp)CF1 MK7 $m64g -SCHED_SMT;freq=X86_POWERNOW_K7;V=AMD;;
btver*|bdver*|k8*|opteron*|athlon64*|athlon-fx|amdfam10|barcelona)CF1 MK8 $m64g -SCHED_SMT;freq="X86_POWERNOW_K8 X86_ACPI_CPUFREQ";gov=CONSERVATIVE;V=AMD;;
*)	case "$srcarch" in
	*)CF1 GENERIC_CPU X86_GENERIC;;
	esac
esac
case "${CTARGET:-${CHOST}}:$CF" in
	x86_64*|*\ 64BIT\ *)CF1 -MPENTIUM4 -MPENTIUMM -X86_GENERIC;;
	*)CF1 -MPSC -GENERIC_CPU;;
esac
use lguest && CF1 -HIGHMEM64G
use acpi && use embed-hardware && acpi_detect
use embed-hardware && [[ -n "$freq" ]] && CF1 -X86_POWERNOW_K8 -X86_ACPI_CPUFREQ $freq CPU_FREQ_GOV_${gov} CPU_FREQ_DEFAULT_GOV_${gov}
CF1 -CPU_SUP_.+ "CPU_SUP_${V:-.+}"
[ -n "$V" ] && {
	CF1 -MICROCODE_AMD -MICROCODE_INTEL MICROCODE_$V
	[ "$V" = INTEL ] || CF1 -X86_INTEL_PSTATE -IOSF_MBI '-X86_INTEL_(?:LPSS|MID|CE|QUARK)' -$knl
	[ "$V" = AMD ] || CF1 -X86_AMD_PLATFORM_DEVICE -AMD_NUMA
}
[ -z "$V" -o "$V" = AMD ] && ucode "amd-ucode/*.bin" AuthenticAMD
[ -z "$V" -o "$V" = INTEL ] && ucode "intel-ucode/??-??-??" GenuineIntel
_is_CF1 NUMA || _is_CF1 PARAVIRT && CF1 RCU_NOCB_CPU RCU_NOCB_CPU_ALL
_is_CF1 -PARAVIRT && CF1 JUMP_LABEL
KERNEL_CONFIG="${CF//  / }"
}

_is_CF1(){
	local s='[ 	
]'
	[ -z "${CF//*$s$1$s*}" ]
}

cflg(){
local a=" ${CFLAGS} ${KERNEL_CFLAGS}"
a="${a##* -${1:-march=}}"
echo "${a%% *}"
}

kconfig(){
	einfo "Configuring kernel"

	# force /etc/kernels/kernel.conf to be last instance after embedding, etc
	local KERNEL_CONFIG="${KERNEL_CONFIG}"
	load_conf

	external_kconfig && {
		yes '' 2>/dev/null | kmake oldconfig
		return
	}
	[[ -e .config ]] || kmake defconfig >/dev/null
	export ${!KERNEL_@}
	local i=1 cfgloop=''
	while cfg_loop $[i++]; do
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
		i?86*) ( [[ -n "$2" ]] || ( (use multitarget || use 64-bit-bfd) && [[ "$(cflg)" == native ]] ) ) &&
			echo "x86" || echo "i386"
		;;
		x86_64*) [[ -z "$2" ]] && use multitarget && [[ "$(cflg)" == native ]] &&
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

fno(){
	use custom-cflags && is-flagq -f$1 && sed -i '1i \n#pragma GCC optimize ("'"no-$1"'")'  "$2"
}

kernel-2_src_prepare(){
	_saved_src_prepare
	[[ ${ETYPE} == sources ]] || return
	kconfig_init

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
	use custom-arch && sed -i -e 's/-m\(arch\|tune\|cpu\)=[a-z0-9\-]*//g' arch/*/Makefile*
	# prevent to build twice
#	sed -i -e 's%-I$(srctree)/arch/$(hdr-arch)/include%%' Makefile
	case "$(gcc-version)" in
	5.*)
		[ -e include/linux/compiler-gcc4.h -a ! -e include/linux/compiler-gcc5.h ] && {
			ln -s compiler-gcc4.h include/linux/compiler-gcc5.h
			append-flags -std=gnu89 # untested here, but must be good
		}
	;;
	4.9.*);;
	4.8.*)if use custom-cflags; then
		echo "CFLAGS_phy.o += -fno-ipa-cp-clone" >>drivers/net/ethernet/intel/e1000e/Makefile
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
	fi
	;;&
	# no time & reason to test all rare bugs with all kernels, so keep whole
	# jist build old kernel with old gcc or fix this "case"
	4.*)if use custom-cflags; then
		# gcc 4.5+ -O3 -ftracer
		fno tracer arch/x86/kvm/vmx.c
		# gcc 4.7 -O3 or -finline-functions
#		echo "CFLAGS_phy.o += -fno-inline-functions" >>drivers/net/ethernet/intel/e1000e/Makefile
#		echo "CFLAGS_e1000_phy.o += -fno-inline-functions" >>drivers/net/ethernet/intel/igb/Makefile
#		sed -i -e 's:^s32 e1000e_phy_has_link_generic:s32 noinline e1000e_phy_has_link_generic:' drivers/net/ethernet/intel/e1000e/phy.c
#		sed -i -e 's:^s32 igb_phy_has_link:s32 noinline igb_phy_has_link:' drivers/net/ethernet/intel/igb/e1000_phy.c
	fi;;
	esac
	# 2test more
	fno tracer drivers/media/radio/radio-aimslab.c
	sed -i -e 's:^static void sleep_delay:static noinline void sleep_delay:' drivers/media/radio/radio-aimslab.c
	# ;)
	sed -i -e 's:^#if 0$:#if 1:' drivers/net/tokenring/tms380tr.c
	# deprecated
	sed -i -e 's:defined(@:(@:' kernel/timeconst.pl
	if (use multitarget || use 64-bit-bfd) && test_cc -S -m64 -march=nocona && ! test_cc -S -m64 2>/dev/null; then
		einfo "-m64 arch fix"
		i=" -march=nocona -mno-mmx -mno-sse -mno-sse2 -mno-sse3"
		sed -i -e "s/ -mcmodel=small/ -mcmodel=small -m64 $i/" arch/x86/boot/compressed/Makefile
		sed -i -e "s/\(KBUILD_AFLAGS += -m64\)$/\1$i/" arch/x86/Makefile*
	fi
#	echo "CFLAGS_mdesc.o += -Wno-error=maybe-uninitialized" >>arch/sparc/kernel/Makefile
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
	[ -x /usr/bin/portageq ] && portageq() { /usr/bin/portageq "${@}";} # around bug
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

kernel-2_pkg_setup() {
	# once apon a time portage starts to check RO before pkg_prerm
	_umount
	_saved_pkg_setup
	# hardened protected
	{
		cat `find /sys -mount -name modalias`
		grep -sh "^MODALIAS=" $(find /sys -mount -name uevent)|sed -e 's:^MODALIAS=::'
	} >"${TMPDIR}/sys-modalias"

}

kernel-2_pkg_preinst() {
	local i p l r r1
	_saved_pkg_preinst
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
		if p=`grep "^[^ ]* $i vfat " /proc/mounts`; then
			p="${p%% *}"
			einfo "$i mounted to vfat, removing symlinks"
			find "${D}"/boot -type l -delete
			if grep "^CONFIG_EFI_STUB=y" "${D}"/boot/config*; then
				einfo "Renaming EFI-compatible"
				rename -- "-${REAL_KV}" "-${SLOT}.efi" "${D}"/boot/{vmlinuz,initrd}*
				# just help
				l="vmlinuz-${SLOT}.efi"
				r="initrd-${SLOT}.efi.img"
				[ -e "$D/boot/r" ] && r=" initrd=/$r" || {
					use integrated || return
					r=
				}
				i=`grep "/dev/[^ ]* / " /proc/mounts`
				i="${i%% *}"
				r="real_root=$i$r"
				i="${p#/dev/???}"
				if [ "$i" != "$p" -a -n "$i" -a -e "$l" -a -n "$r" ]; then
					einfo "To add this kernel  directly to EFI boot options, run command(s):"
					einfo " # efibootmgr -c -d "${p%$i}" -p $i -l $l -L vmlinuz-${SLOT} -u '$r'"
					use embed-hardware && use !integrated && {
						r="${r#real_}"
						r="${r%% *}"
						einfo " # efibootmgr -c -d "${p%$i}" -p $i -l $l -L vmlinuz-${SLOT}-nord -u '$r'"
					}
				fi
			fi
		fi
	fi
}

kernel-2_pkg_postinst() {
	_saved_pkg_postinst
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
	sed -e 's:^.*/::g' -e 's:\.ko$::g'|sort -u >"${TMPDIR}/unmodule1.tmp"
	grep -sqFxf "${TMPDIR}/unmodule1.tmp" "${TMPDIR}/unmodule.black" && return
	while read i; do
		grep -Rh "^\s*obj\-\$[(]CONFIG_.*\s*\+=.*\s${i//[_-]/[_-]}\.o" "${TMPDIR}"/unmodule.tmp|sed -e 's:).*$::g' -e 's:^.*(CONFIG_::'|sort -u|while read c; do
			$1 "$c"
			echo "$i" >>"${TMPDIR}/unmodule.$1"
		done
	done <"${TMPDIR}/unmodule1.tmp"
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

modprobe_d(){
	grep -h "^[ 	]*$1[ 	]*$2\([ 	]\|\$\)" "$ROOT"/etc/modprobe.d/*.conf|sed -e "s:^[ 	]*$1[ 	]*::"
}

modprobe_opt(){
	local i m p
	for i in "${@}" ;do
		modprobe_d options "$i"|while read m p; do
			for p in $p; do
				echo -n " $m.$p"
			done
		done
		modprobe_d blacklist "$i"|while read m; do
			echo "$m" >>"${TMPDIR}/unmodule.black"
			echo -n " $m.!"
		done
		modprobe_d alias "$i"|while read i m; do
			echo "$m" >>"${TMPDIR}/overlay-rd/etc/modflags/$i"
		done
#		modprobe_d install "$i" >>"${TMPDIR}/unmodule.install"
	done
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
		cat "${TMPDIR}/sys-modalias"
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

	use external-firmware || return
	# enabling firmware fallback only ondemand by security reason
	d="$TMPDIR/absent-firmware.lst"
	find . -name '*.ko'|while read i; do
		a="${i##*/}"
		grep -qFx "${a%.ko}" "$TMPDIR/unmodule.m2y" && modinfo "$i"
	done|grep "^firmware:"|sed -e 's:^.* ::'|while read i; do
		[ -e "$S/firmware/$i" ] || echo "$i"
	done >"$d"
	[ -s "$d" ] || return
	a=
	b=
	c=false
	# 2test, but IMHO too many embedding: for b43 usually need only 1 of *
	# but FALLBACK is deprecated
	( use monolythe || ! grep -qF FW_LOADER_USER_HELPER_FALLBACK "$S/.config" ) && grep -qFx 'CONFIG_FIRMWARE_IN_KERNEL=y' "$S/.config" && c=true
	while read i; do
		$c && [ -e "$ROOT/lib/firmware/$i" ] && b+=" $i" || a+=" $i"
	done <"$d"
	[ -n "$b" ] && echo " EXTRA_FIRMWARE=\"${b# }\" EXTRA_FIRMWARE_DIR=\"$ROOT/lib/firmware\" "
	[ -n "$a" ] && echo " ##${a// /,}: FW_LOADER_USER_HELPER_FALLBACK "
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
	local p=1 i c="${comp:+-comp $comp }"
	for i in ${MAKEOPTS}; do
		[[ "$i" == -j* ]] && p=$((${i#-j}-1))
	done
	[[ "${p:-0}" == 0 ]] && p=1
	case "$comp" in
	lzo)c+='-Xcompression-level 9 ';;
	lz4)c+='-Xhc ';;
	esac
	mksquashfs "${@}" $c-b 1048576 -no-recovery -no-progress ${p:+-processors $p} || die "mksquashfs failed"
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
		[ -e "$ROOT/usr/$libdir/klibc" ] || libdir=$(echo "$ROOT"/usr/lib*/klibc|sed -e 's:^.*/usr/::g' -e 's:/.*::g')
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
