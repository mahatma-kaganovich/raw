: ${EAPI:=1} # 3 or neutral
#+
inherit flag-o-matic global-compat
[[ "${PV}" == 9999* ]] && KV_FULL="${PV}"
# really newer work without, but check-robots want it
[ -v PORTDIR ] || PORTDIR=${PORTAGE_ECLASS_LOCATIONS[-1]}
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

reexport kernel-2 pkg_setup src_compile src_install pkg_postinst pkg_preinst src_prepare

#UROOT="${ROOT}"
UROOT=""
SHARE="${UROOT}/usr/share/genpnprd"
COMP='GZIP BZIP2'

if [[ ${ETYPE} == sources ]]; then

# things like bcache, btrfs, xfs works without special inclusion,
# but disaster recovering is good
IUSE="${IUSE} +build-kernel custom-cflags +pnp +compressed integrated
	netboot custom-arch embed-hardware +blobs
	kernel-firmware +sources pnponly lzma xz lzo lz4 zstd
	external-firmware xen +smp kernel-tools multitarget 64-bit-bfd thin
	lvm device-mapper unionfs luks gpg iscsi e2fsprogs mdadm btrfs bcache dropbear xfs +keymap blkid
	lguest acpi klibc +genkernel monolythe update-boot uml paranoid"
DEPEND="${DEPEND}
	!<app-portage/ppatch-0.08-r16
	pnp? ( sys-kernel/genpnprd )
	lzma? ( app-arch/xz-utils )
	xz? ( app-arch/xz-utils )
	lzo? ( app-arch/lzop )
	lz4? ( app-arch/lz4 )
	zstd? ( app-arch/zstd )
	build-kernel? (
		app-arch/cpio
		compressed? ( sys-kernel/genpnprd )
		kernel-firmware? ( !sys-kernel/linux-firmware )
		klibc? ( sys-kernel/klibc-sources )
		genkernel? (
			>=sys-kernel/genkernel-3.4.10.903
		)
		!klibc? ( !genkernel? (
			sys-apps/busybox
			blkid? ( sys-apps/util-linux )
			mdadm? ( sys-fs/mdadm )
			device-mapper? ( sys-fs/dmraid )
			lvm? ( sys-fs/lvm2 )
			unionfs? ( sys-fs/unionfs-fuse )
			iscsi? ( sys-block/open-iscsi )
			gpg? ( app-crypt/gnupg )
			luks? ( sys-fs/cryptsetup )
			btrfs? ( sys-fs/btrfs-progs )
			bcache? ( sys-fs/bcache-tools )
			xfs? ( sys-fs/xfsprogs )
			dropbear? ( net-misc/dropbear )
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
	i="${i##*[/:]}"
	[[ "$i" == video_cards_* ]] || i="${i##*_}"
	i="${i%.use}"
	i="${i%.-use}"
	IUSE+=" ${i#[0-9]}"
done

fi

BDIR="${WORKDIR}/build"

_CF1_(){
	local i s='[ 	
]'
	for i in "${@}"; do
		CF="${CF//$s[+-]${i#[+-]}$s/ }"
		CF="${CF//$s${i#[+-]}$s/ }"
	done
}

CF1(){
	_CF1_ "${@}"
	CF+=" $* "
}

_CF1(){
	_CF1_ "${@}"
	CF=" $* $CF"
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

_run_env(){
	# everything
	CC="$(tc-getCC)" LD="$(tc-getLD)" CXX="$(tc-getCXX)" CPP="$(tc-getCPP)" AS="$(tc-getAS)" AR="$(tc-getAR)" STRIP="$(tc-getSTRIP)" NM="$(tc-getNM)" OBJCOPY="$(tc-getOBJCOPY)" OBJDUMP="$(tc-getOBJDUMP)" RANLIB="$(tc-getRANLIB)" \
	HOSTCC="$(tc-getBUILD_CC)" HOSTLD="$(tc-getBUILD_LD)" HOSTCXX="$(tc-getBUILD_CXX)" HOSTCPP="$(tc-getBUILD_CPP)" HOSTAS="$(tc-getBUILD_AS)" HOSTAR="$(tc-getBUILD_AR)" HOSTSTRIP="$(tc-getBUILD_STRIP)" HOSTNM="$(tc-getBUILD_NM)" HOSTOBJCOPY="$(tc-getBUILD_OBJCOPY)" HOSTRANLIB="$(tc-getBUILD_RANLIB)" \
	srctree="$S" "${@}"
}

kernel-2_src_configure() {
	[[ ${ETYPE} == sources ]] || return
	kconfig_init
	cd "${S}"
	cpu2K
	use integrated || use thin && cfg_ '###integrated|thin:' FW_LOADER_COMPRESS
	filter-flags '-fopenmp*' '-*parallelize*'
	# unsure "random" miscompulations on 5.9 
	replace-flags -malign-data=cacheline -malign-data=compat
	: ${KERNEL_UTILS_CFLAGS:="${CFLAGS}"}

	# ???
#	: ${KERNEL_UTILS_LDFLAGS:="${LDFLAGS}"}
	local i
	[[ -z "$KERNEL_UTILS_LDFLAGS" ]] && for i in $LDFLAGS; do
		[[ "$i" == -Wl,* ]] && KERNEL_UTILS_LDFLAGS+=" $i"
	done
	KERNEL_UTILS_LDFLAGS="$(flags_nosp "$KERNEL_UTILS_LDFLAGS")"

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
		cflags="$(flags_nosp "$(_filter_f CFLAGS "-msse*" -mmmx -m3dnow -mavx "-mfpmath=*" '-flto*' '-*-lto-*' -fuse-linker-plugin -fdevirtualize-at-ltrans '-mindirect-branch*' '-mfunction-return=*' -fopenmp -fopenmp-simd -fopenacc -fgnu-tm) ${cflags}")" #"

		# dedup
		local i="$cflags"
		cflags=
		for i in $i; do
			local j="$cflags"
			cflags=
			for j in $j; do
				[ "${j%=*}" = "${i%=*}" ] || cflags+=" $j"
			done
			cflags+=" $i"
		done
		cflags="${cflags# }"

		aflags="$cflags" # at least now
		ldflags="$(flags_nosp "$(extract_flags -Wl, ${LDFLAGS}) ${ldflags}")" #"
	else
		# only KBUILD_USER*FLAGS, but starting from 5.15 wrong
		# USE=custom-cflags still unstripped
		strip-flags
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
	einfo "squashfs compression: $comp"
	export comp
}

_sort_f(){
	local f
	for f in "${@}"; do
		touch "$f"
		sed -e 's:^"::' -e 's:"$::' <"$f" | sort -u >"$f.tmp"
		rename .tmp '' "$f.tmp"
	done

}

# add to $1 lists modules, dependend from listed $1 & $2 modules and add names to $2
modules_deps(){
	sed -e 's:^.*/::g' -e 's:\.ko$::g' <"$1" >>"$2"
	sed -i -e 's:-:_:g' "$2"
	_sort_f "$2"
	while true; do
		sed -e 's:^: :' -e 's:$: :' <"$2" | grep -Ff - "$TMPDIR"/depends.lst | sed -e 's: .*::g' >"$2"1
		cat "$2" >>"$2"1
		_sort_f "$2"1
		cmp -s "$2"{1,} && break
		mv "$2"{1,}
	done
	rm "$2"1
	sed -e 's:^: :' -e 's:$: :' <"$2" | grep -Ff - "$TMPDIR/names.lst" | sed -e 's:^.* ::g' >>"$1"
	_sort_f "$1"
}

# better to do it once before install
mod_strip(){
	[ -z "$INSTALL_MOD_STRIP" ] && return
	local strip="$(tc-getSTRIP)"
	[ "$INSTALL_MOD_STRIP" = 1 ] && strip+=' --strip-debug' || strip+=" $INSTALL_MOD_STRIP"
	strip+=" $INSTALL_MOD_STRIP"
	if use paranoid; then
		find . -name '*.ko'|while read m; do
			$strip $m
		done
	else
		$strip $(find . -name '*.ko'|sed -e 's:^\./::')
	fi
}

_modinfo(){
	modinfo --basedir=/dev/null "${@}"
}

__mfw(){
	[ -e "firmware/$2" ] ||
	if use external-firmware && [ -e "/lib/firmware/$2" ]; then
		echo "$1: $2" >>"$TMPDIR"/mod-fw.lst
	else
		echo "$1" >>"$TMPDIR"/mod-exclude1.m2y
	fi
}

post_make(){
	local i x y m f n= d= n1=
	i="$TMPDIR/modules.builtin1"
	unlink "$i"
	[ -s modules.builtin ] && {
		cp -a modules.builtin "$i"
		grep -sqv "^kernel/" "$i" || sed -i -e 's:^kernel/::' "$i"
		rm $(cat "$i") -f
	}
	# all modinfo (fast or split cmdline)
	einfo "Preparing modules & firmware info"
	#echo -n|tee "$TMPDIR"/{{mod-fw,depends,names,mod-blob{,1,-names}}.lst,mod-exclude.m2y,unmodule.black}
	if use paranoid; then
		find . -name '*.ko'|while read m; do
			_modinfo "$m"
		done >"$TMPDIR"/modinfo.lst
	else
		_modinfo $(find . -name '*.ko'|sed -e 's:^\./::') >"$TMPDIR"/modinfo.lst
	fi
	# list modules without [configured] firmware and firmare to ext built
	# keep standalone
	while read x y; do
		case "$x" in
		filename:)
			m=${y#$S/}
			d=
			n=
			n1=${y##*/}
			n1=${n1%.ko}
			n1=${n1//-/_}
			$(tc-getNM) "$m"|grep -q 'firmware_request\|request_firmware\|release_firmware' && echo "$m" >>"$TMPDIR"/mod-blob1.lst
			echo " $n1 $m" >>"$TMPDIR/names.lst"
		;;
		firmware:)__mfw "$m" "$y";;
		depends:)
			[ -z "$y" ] && continue
			y="${y//,/ }"
			y="${y//-/_}"
			d+=" $y"
			echo "$n1 $y " >>"$TMPDIR"/depends.lst
		;;&
		name:)
			n="${y//-/_}" #??
			case "$n" in
			cfg80211)__mfw "$m" regulatory.db;;
			esac
			echo " $n $m" >>"$TMPDIR/names.lst"
		;;&
		depends:|name:)[ -n "$d" -a -n "$n" ] && echo "$n$d " >>"$TMPDIR"/depends.lst;;
		esac
	done <"$TMPDIR"/modinfo.lst
	while read i; do
		for i in ${i%%#*}; do
			[ -e "$i" ] && echo "$i"
		done
	done <"$SHARE"/modules-standalone >>"$TMPDIR"/mod-exclude.m2y
	sed -e 's/^.*: //' <"$TMPDIR"/mod-fw.lst | sort -u >"$TMPDIR"/fw-used1.lst
	sed -e 's/: .*$//' <"$TMPDIR"/mod-fw.lst >>"$TMPDIR"/mod-blob.lst
	grep -Fvxf "$TMPDIR"/mod-blob{,1}.lst >>"$TMPDIR"/mod-exclude1.m2y
	grep -vxf "$SHARE"/modules-fw-ignore "$TMPDIR"/mod-exclude1.m2y >>"$TMPDIR"/mod-exclude.m2y
	grep -vxf "$SHARE"/modules-fw-ignore "$TMPDIR"/mod-blob1.lst >>"$TMPDIR"/mod-blob.lst

	einfo "Search hidden firmware"
	for i in "$S" "$ROOT/lib"; do
		find "$i/firmware/" -type f | while read f;do
			f="${f#$i/firmware/}"
			case "$f" in
			*/.*|.*|*.[ch]|*Makefile|*cmake|LICENCE*|LICENSE*|*README|WHENCE|GPL-?|GPL|*/GPL|*configure)continue;;
			esac
			echo "\"$f\""
		done
	done | sort -u >"$TMPDIR"/fw-all.lst
	sort "$TMPDIR"/fw-{all,used1}.lst | uniq -u >"$TMPDIR"/fw-unknown.lst
	sed -e 's:^:":' -e 's:$:":' <"$TMPDIR"/fw-unknown.lst|grep -RFlf - --include "*.[ch]"|while read f; do
		[ -e "${f%?}o" ] || (use paranoid && ([[ "$f" == *include* ]] || [[ "$f" == *h && -n "`find "${f%/*}" -name "*.o"`" ]] ) ) && grep -Fohf "$TMPDIR"/fw-unknown.lst "$f"
	done | while read f; do
		i="${f%?}ko"
		[ -e "$m" ] && x=3 && (echo "$m" | tee -a "$TMPDIR"/mod-blob{,2}.lst) || x=2
		x="$TMPDIR"/fw-used$x.lst
		[[ "$f" == */* ]] && echo "$f" >>"$x" && continue
		grep -F "/${f#?}" "$TMPDIR"/fw-unknown.lst || echo "$f" >>"$x"
	done

	einfo "Sort data"
	_sort_f "$TMPDIR"/{fw-used{2,3},depends,names}.lst
	sort -u "$TMPDIR"/fw-used{1,2,3}.lst >"$TMPDIR"/fw-used.lst
	modules_deps "$TMPDIR"/mod-blob{,-names}.lst
	sed -e "s:^:lib/modules/${REAL_KV}/kernel/:" <"$TMPDIR"/mod-blob.lst | grep -vxf "$SHARE"/modules-fw-ignore >"$TMPDIR"/mod-blob_.lst
	modules_deps "$TMPDIR"/{mod-exclude.m2y,unmodule.black}

	use blobs && einfo "Copy firmware"
	while read i; do
		if [ -e "firmware/$i" ]; then
			m="firmware/$i"
		elif use external-firmware; then
			m="$ROOT/lib/firmware/$i"
		else
			ewarn "Required firmware not found: '$i'"
			continue
		fi
		use blobs || continue
		f="${BDIR}/lib/firmware/$i"
		mkdir -p "${f%/*}"
		cp "$m" "$f" || die
	done <"$TMPDIR"/fw-used.lst
}

extra_firmware(){
	local i e=
	einfo "Embedding firmware"
	{
	    for i in $KERNEL_CONFIG_EXTRA_FIRMWARE; do
		echo "$i"
	    done
	    # keep compressed firmware in userspace
	    grep -qx CONFIG_FW_LOADER_COMPRESS=y "$S/.config" ||
	    while read x y; do
		grep -sqFx "${x%:}" "$TMPDIR/modules.builtin1" && echo "$y"
	    done <"$TMPDIR"/mod-fw.lst
	}|sort -u >"$TMPDIR"/fw-embed.lst
	sort "$TMPDIR"/fw-used{1,2}.lst | uniq -u | grep -Fxf - "$TMPDIR"/fw-used2.lst >"$TMPDIR"/fw-embed2.lst
	while read i; do
		rm "${BDIR}/lib/firmware/$i" &&
		[ ! -e "firmware/$i" ] &&
		e+=" $i" || ewarn "Required embedded firmware not found: '$i'"
	done <"$TMPDIR"/fw-embed.lst
	while read i; do
		[ -e "${BDIR}/lib/firmware/$i" ] &&
		[ ! -e "firmware/$i" ] &&
		[[ "$e " != *" $i "* ]] &&
		e+=" $i" || ewarn "Possible required embedded firmware not found: '$i'"
	done <"$TMPDIR"/fw-embed2.lst
	e="${e# }"
	export KERNEL_CONFIG_EXTRA_FIRMWARE_DIR="$ROOT/lib/firmware"
	[ "$KERNEL_CONFIG_EXTRA_FIRMWARE" = "$e" ] && return 1
	export KERNEL_CONFIG_EXTRA_FIRMWARE="$e"
	return 0
}

umake(){
	kmake ARCH=um LDFLAGS="$(extract_flags -Wl, ${LDFLAGS})" CFLAGS="$(_filter_f CFLAGS '-flto*' '-*-lto-*' -fuse-linker-plugin)" "${@}"
}

_genpnprd(){
	set -- \
		--IMAGE "initrd-${REAL_KV}.img" \
		--S "${S}" \
		--OVERLAY "${TMPDIR}/overlay-rd" \
		${comp:+--COMPRESS $comp} \
		--ARCH "$(arch)" \
		--MAKEOPTS "$MAKEOPTS" \
		"${@}"
	use blobs || set -- --CLEAN @"$TMPDIR"/mod-blob_.lst "${@}"
	use thin && set -- --THIN - "${@}"
#	MAKEOPTS="$MAKEOPTS" bash -- "${SHARE}/genpnprd" "${@}" --IMAGE "${S}/initrd-${REAL_KV}.img"
	MAKEOPTS="$MAKEOPTS" /usr/bin/genpnprd "${@}"
}

kernel-2_src_compile() {
	kconfig_init
	case ${EAPI:-0} in
	0|1)
#		kernel-2_src_prepare # ->src_unpack
		kernel-2_src_configure
	;;
	esac
	####

	_saved_src_compile

	####
	[[ ${ETYPE} == sources ]] || return
	local KV0="${KV}"
	check_kv
	use build-kernel || return
	if use uml; then
		mv .config* "${WORKDIR}"
		# User-Mode Linux: build defconfig with all embedded
		umake defconfig
		cat {"${SHARE}",/etc/kernels}/config-uml >>.config
		umake oldconfig
		use paranoid
		umake all
		mv linux "umlinux-${REAL_KV}" || die "Build user-mode failed"
		mv .config .config-um
		umake mrproper
		mv "${WORKDIR}"/.config* "$S"
	fi
	local NN=0
	for i in true false false; do
		NN=$[NN+1]
		use paranoid && kmake clean
		if [[ -n "${KERNEL_MODULES_MAKEOPT}" ]]; then
			einfo "Compiling kernel (bzImage)"
			kmake bzImage
		fi
		einfo "Compiling kernel (all)"
		cp .config .config.stage$NN
		kmake all ${KERNEL_MODULES_MAKEOPT}
		grep -q "=m$" .config && [[ -z "`find . -name "*.ko" -print`" ]] && die "Modules configured, but not built"
		post_make
		$i || {
			use external-firmware && extra_firmware || break
			# final: embed firmware
			kconfig
			continue
		}
		i=false
		# else need repeat only if module with fw embeddeed by /etc/kernels/kernel.conf, don't care
		if use embed-hardware; then
			einfo "Reconfiguring kernel with hardware detect"
			_cmdline "`modprobe_opt ''`"
			cfg_ "###detect: $(sort_detects $(detects)|tee -a .detect-hardware)"
			paranoid_y
			i=true
		else
			paranoid_y && i=true
		fi
		if $i; then
#			use external-firmware && extra_firmware
			kconfig
			if use embed-hardware; then
				local c="${KERNEL_CLEANUP:-arch/$(arch) drivers/dma}"
				einfo "Applying KERNEL_CLEANUP='$c'"
				cfg_ "###cleanup: ${KERNEL_CONFIG2} $(detects_cleanup $c)"
				i=true
				kconfig
			fi
		fi
		rm "$TMPDIR/unmodule.tmp" "${WORKDIR}"/modules.alias.sh -f
		if use monolythe; then
			einfo "Reconfiguring kernel as 'monolythe'"
			use !embed-hadrware && [[ -z "$KERNEL_CLEANUP" ]] && {
				ewarn "Useflag 'monolythe' requires at least USE='embed-hadrware' KERNEL_CLEANUP='.'"
				ewarn "(or too global KERNEL_[CONFIG]) - You are warned!"
			}
			sed -i -e 's:^CONFIG_MODULES=y$:# CONFIG_MODULES is not set:' .config
			sed -i -e 's:=m$:=y:g' .config
			kmake oldconfig
			i=true
		fi
		$i || break
		( [[ -n "$KERNEL_CLEANUP" ]] || use monolythe ) && use sources && kmake clean
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

	use debug || mod_strip

	if use sources || use klibc; then
		einfo "Preparing kernel headers"
		kmake headers_install #$(use compressed && echo _all)
	fi

	[[ -n "$KERNEL_MAKE_ADD" ]] && kmake $KERNEL_MAKE_ADD

	use klibc && userspace

	if use kernel-tools; then
		einfo "Compiling tools"
		mktools all
	fi

	for i in `find Documentation -name "*.c"`; do
		_cc $i
	done

	if use !klibc && use !genkernel; then
		mkdir -p "${TMPDIR}/overlay-rd/lib"
		cp -an "$BDIR/lib/firmware" "${TMPDIR}/overlay-rd/lib"
		_genpnprd --IMAGE "initrd-${REAL_KV}.cpio" --STATIC true --FILES "/bin/busybox
			$(use blkid && echo /sbin/blkid)
			$(use mdadm && echo /sbin/mdadm /sbin/mdmon)
			$(use device-mapper && echo /usr/sbin/dmraid)
			$(use lvm && echo /sbin/lvm /sbin/dmsetup)
			$(use unionfs && echo /sbin/unionfs)
			$(use luks && echo /bin/cryptsetup)
			$(use gpg && echo /sbin/gpg)
			$(use iscsi && echo /usr/sbin/iscsistart)
			$(use btrfs && echo /sbin/btrfs /sbin/btrfsck /sbin/mkfs.btrfs)
			$(use bcache && echo /sbin/bcache)
			$(use xfs && echo /sbin/xfs_repair /sbin/mkfs.xfs)
			$(use dropbear && echo /usr/sbin/dropbear)
		" &&
		mv initrd-"${REAL_KV}".{cpio,img} ||
		die "genpnprd failed"
	fi
	use genkernel || return
	use klibc && mv initrd-${REAL_KV}.img initrd-${REAL_KV}.klibc.img

	einfo "Generating initrd image"
	# nfs: required --enable-static-nss in glibc, $(pkgconfig libtirpc --libs --static) in the END of line...
	local p=' --no-nfs'
	for i in 'lvm lvm2' luks gpg iscsi 'device-mapper dmraid' unionfs e2fsprogs mdadm btrfs keymap netboot 'monolythe static' 'dropbear ssh'; do
		use "${i% *}" && p+=" --${i##* }"
	done
	for i in bcache 'xfs xfsprogs'; do
		grep -qF "	--${i##* }	" /usr/share/genkernel/gen_cmdline.sh &&
		use "${i% *}" && p+=" --${i##* }"
	done
	for i in 'blkid disklabel'; do
		use "${i% *}" && i="${i##* }" || i="no-${i##* }"
		grep -qw "\--$i" "$UROOT/usr/share/genkernel/gen_cmdline.sh" && p+=" --$i"
	done
	if use pnp || use compressed; then
		use monolythe || p+=" --all-ramdisk-modules"
		[[ -e "${BDIR}/lib/firmware" ]] && p+=" --firmware --firmware-dir=\"${BDIR}/lib/firmware\"" || p+=' --no-firmware'
	fi
	run_genkernel ramdisk --kerneldir="${S}" --bootdir="${S}" --no-mountboot ${p}
	r=`ls initramfs*-"${REAL_KV}"* || ls "$TMPDIR"/genkernel/initramfs*` && mv "$r" "initrd-${REAL_KV}.img" || die "initramfs rename failed"
	einfo "Preparing boot image"
	_genpnprd --PNPMODE "$( (use !pnp && echo nopnp)||(use pnponly && echo pnponly)||echo pnp )" || die
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
	local i c="$2"
	[[ -z "$c" ]] && c=NONE && for i in $COMP; do
		[[ "$i" == zstd ]] && use integrated && ! _zstd_ok && continue
		grep -q "^CONFIG_RD_$i=y" .config && c="$i"
	done
	if use integrated; then
		einfo "Integrating initramfs"
		einfo "Integrated image compression: $c"
		echo "CONFIG_INITRAMFS_SOURCE=\"$1\"
CONFIG_INITRAMFS_ROOT_UID=0
CONFIG_INITRAMFS_ROOT_GID=0
CONFIG_INITRAMFS_COMPRESSION_$c=y" >>.config
		kmake oldconfig
		kmake bzImage
	else
		einfo "Initrd compression: $c"
		c="${c,,}"
		case "$c" in
		none)[[ -e "$1" ]] && rename .cpio .img "$1";;
		lzo)c+='p';;&
		lzo|gzip|lzma|lz4|bzip2)c+=' -9';;&
#		lz4)c+=' --best -l';;&
#		lzma)c+=' -e';;&
		gzip)c+=' -n';;&
		xz)c+=' --check=crc32 --lzma2=dict=1MiB';;&
		zstd)c+=' -19 -q';;&
		*)
			${c} -c "$1" >"${1%.cpio}.img" || die
			rm "$1"
		;;
		esac
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
		use uml && dobin "umlinux-${REAL_KV}"
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
		use kernel-tools && mktools install INSTALL_PATH="${D}" DESTDIR="${D}"
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
#			find "${S}" -name "*.cmd" | while read f ; do
#				sed -i -e 's%'"${S}"'%/usr/src/linux-'"${REAL_KV}"'%g' ${f}
			find "${S}" -name ".*.cmd"|sed -e 's:[^/]*$::'|sort -u | while read f ; do
				(cd "$f" && sed -i -e 's%'"${S}"'%/usr/src/linux-'"${REAL_KV}"'%g' .*.cmd) || die
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
	local i v c="$UROOT/usr/share/genkernel/gen_cmdline.sh"
	use paranoid && mkdir "${TMPDIR}/genkernel-cache"
	[[ ! -e "${TMPDIR}/genkernel-cache" ]] && cp "${UROOT}/var/cache/genkernel" "${TMPDIR}/genkernel-cache" -r
	if use netboot; then
		cp "$UROOT/usr/share/genkernel/netboot/busy-config" "$TMPDIR"
	else
		cp "$UROOT/usr/share/genkernel/defaults/busy-config" "$TMPDIR"
	fi
	for i in $(use selinux && echo SELINUX=y) PAM=n STATIC=y DEBUG=n NO_DEBUG_LIB=y DMALLOC=n EFENCE=n FEATURE_MOUNT_NFS=n \
	    FEATURE_MOUNT_CIFS=y MODPROBE_SMALL=n INSMOD=y RMMOD=y MODPROBE=y LSMOD=n FEATURE_MODPROBE_BLACKLIST=y TELNETD=y \
	    MKFS_EXT2=n 'FEATURE_VOLUMEID_[A-Z0-9]*=y'; do
		sed -i -e "s:^.*\(CONFIG_${i%=*}\)[= ].*\$:\1=${i#*=}:" "$TMPDIR/busy-config"
		grep -q "CONFIG_${i%%=*}[= ]" "$TMPDIR/busy-config" || echo "CONFIG_$i" >>"$TMPDIR/busy-config"
	done
	# cpio works fine without loopback, but may panish sandbox
	cp /usr/bin/genkernel "${S}" || die
	sed -i -e 's/has_loop/true/' "${S}/genkernel"
	local a="$(arch "" 1)" opt=
	ls "$UROOT/usr/share/genkernel/arch/$a/*busy*" >/dev/null 2>&1 || opt+=" --busybox-config=${TMPDIR}/busy-config"
	# e2fsprogs & mdraid need more crosscompile info
	unmcode y n
	grep -sq arch-override= "$c" && set -- "${@}" --arch-override="$a" --utils-arch="$a"
	grep -sq kernel-modules-prefix= "$c" && set -- "${@}" --kernel-modules-prefix="$BDIR" || set -- "${@}" --module-prefix="$BDIR"
	TEMPDIR="$TMPDIR" \
	ac_cv_target="${CTARGET:-${CHOST}}" ac_cv_build="${CBUILD}" ac_cv_host="${CHOST:-${CTARGET}}" \
	CFLAGS="${KERNEL_UTILS_CFLAGS}" LDFLAGS="${KERNEL_UTILS_LDFLAGS}" _run_env "${S}/genkernel" $opt\
		--config=/usr/share/genpnprd/genkernel.conf "${@}" ${KERNEL_GENKERNEL} || {
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
	[[ "$*" == '#'* ]] && KERNEL_CONFIG+="
"
	true
}

cfg_use(){
	local i u="$1"
	shift
	for i in $* "#use:$u
"; do
		use $u && cfg $i || cfg "-${i#[+=&]}"
	done
}

cfg_use_(){
	local i u="$1"
	shift
	cfg_ "
	#use:$u "
	for i in $* ; do
		use $u && cfg_ $i || cfg_ "-${i#[+=&]}"
	done
}

_cfg_use_(){
	local i u="$1"
	shift
	cfg_ "
	#use:$u "
	for i in $* "#use:$u
"; do
		use $u && cfg_ $i || cfg "-${i#[+=&]}"
	done
}

rd_add(){
	local i r="${TMPDIR}/overlay-rd/"
	for i in "${@}"; do
#		[ -e "$r$i" ] || cp --parents "$r" "$r"
		[ -e "$r$i" ] || bash "${SHARE}/genpkgrd" "$r" "$i"
	done
}

_append(){
	local v="KERNEL_CONFIG_$1"
	shift
	einfo "$v+=$*"
	export $v="${!v}${!v:+ }$*"
}

_cmdline(){
	_append CMDLINE "${@}"
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

_zstd_ok(){
#	[[ "${CBUILD}" == "${CTARGET:-${CHOST}}" ]] && use amd64 && (echo test|zstd -zqc -22 --ultra >/dev/null 2>&1)
	false
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
	# lz4hc still fastest, but have memory issue (on x86_32?) and x1.5-2 size
	# zstd kernel broken on x86 32bit
	use zstd && COMP+=' ZSTD'
	use xz && COMP+=' XZ'
	for i in $COMP; do
		[[ "$i" == ZSTD ]] && ! _zstd_ok && continue
		o="$i $o"
	done
	o="${o% }"
	cfg "KERNEL_${o// /;KERNEL_}"
	cfg $o
	cfg_ "
"
	ewarn "If failed here after update ('not in IUSE') - do 'emerge --regen' or 'rm $(find /var/cache/edb/dep -name "$PN-$PVR")'"
	for i in "${SHARE}"/*use; do
		[[ "${i##*/}" == *_dep_* ]] && continue
		o="${i##*[/:]}"
		[[ "$o" == video_cards_* ]] || o="${o##*_}"
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
			for j in $PORTDIR $PORTDIR_OVERLAY "${PORTAGE_ECLASS_LOCATIONS[@]}"; do
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
	CF1 -PCC_CPUFREQ -SMP -X86_BIGSMP -MAXSMP
#	CF1 -PCI
	for i in $(cat /sys/bus/acpi/devices/*/path|sed -e 's:^\\::'); do
		case "$i" in
		*.SRAT)CF1 NUMA;;
#		_SB_.PCI*)CF1 PCI;;
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
	[[ "$CF" == *-PARAVIRT' '* ]] && ! $smt && $fakeHT && grep -q "^flags\s*:.*\sht\s" /proc/cpuinfo &&
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
	local ata='' vblk='' scsi='' vscsi='' e='+' qemu='' cc='' cc1='' usb=false iuse=" $IUSE " i
	use embed-hardware && e='&'
	while read s; do
		case "$s" in
		virtio:*d*v00001AF4): ${qemu:=true};;
		virtio:*d*v*)echo "virtio non-qemu device $s";qemu=false;;
		esac
		case "$s" in
		pci:*)CF1 PCI;;&
		pci:v00001AF4d*)CF1 VIRTIO_PCI;: ${qemu:=true};;& # required for embedding
		# even if standard input devices still in system - enlight VM kernel or remove PV hw
		pci:v00001AF4d*sv00001AF4*bc09sc00*)CF1 -INPUT_KEYBOARD;;
		pci:v00001AF4d*sv00001AF4*bc09sc02*)CF1 -INPUT_MOUSE;;
		pci:v00001AF4d*sv00001AF4*bc09sc80*)CF1 -INPUT_TABLET;;
		pci:v00001AF4d*sv00001AF4*);; # just ignore all PCI aliases for qemu virtio
		virtio:d00000001v*)CF1 VIRTIO_NET -ETHERNET -PHYLIB -FDDI -ATM;;
		virtio:d00000002v*)CF1 VIRTIO_BLK;vblk=true;;
		pci:v00008086d00007010sv*sd*bc*sc*i*)cc1+=' ATA_PIIX';ata=true;;
		pci:v00008086d000025ABsv*sd*bc*sc*i*)CF1 _/drivers/watchdog/.+ I6300ESB_WDT;;
		pci:*bc02sc00i*)echo "ethernet $s";cc+=' ETHERNET +PHYLIB';;
		pci:*bc02sc02i*)echo "FDDI $s";cc+=' +FDDI';;
		pci:*bc02sc03i*)echo "ATM $s";cc+=' +ATM';;
#		pci:*bc04sc01i*)echo "sound $s";cc+=' +SND';;
		pci:*bc01sc06i01)cc1+=" SATA_AHCI";ata=true;;
		pci:*bc01*)echo "storage $s";vblk=false;vscsi=false;;
		pci:v00008086d00007020sv*)CF1 USB_UHCI_HCD;usb=true;;
		pci:v00001B36d00000100sv*);; # qxl
		# PCI host bridge: all subbuses detected over PCI bridges
		pci:*bc06sc00i*)CF1 -ISA -ISA_BUS -ISA_.+_API -EISA -EISA_PCI_EISA -PCCARD -PCMCIA -CARDBUS -INFINIBAND;;
		pci:*bc06sc01i*)cc+=' ISA __ISA_BUS ISA_.+_API';; # or lpc?
		pci:*bc06sc02i*)cc+=' EISA EISA_PCI_EISA';;
#		pci:*bc06sc03i*);; # mca
		pci:*bc06sc05i*)cc+=' PCCARD PCMCIA';;
		pci:*bc06sc06i*)cc+=' NUBUS';;
		pci:*bc06sc07i*)cc+=' PCCARD CARDBUS';;
		pci:*bc06sc0ai*)cc+=' INFINIBAND';;

		# cleanup renesas xhci if other xhci present
		# to prevent firmware_class embedding over xhci quirk on 5.9+
#		pci:v00001912d*sv*sd*bc0Csc03i30*);;
		pci:v00001912d*);;
		pci:v*d*sv*sd*bc0Csc03i30*)
			use embed-hardware && CF1 -USB_XHCI_PCI_RENESAS
			# just as detected
			usb=true
			use embed-hardware && CF1 '&USB_XHCI_PCI'
		;;

		virtio:d00000008v*)CF1 SCSI_VIRTIO BLK_DEV_SD;vscsi=true;;
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
		platform:iTCO_wdt)cc1+=' ITCO_WDT I2C';;
		platform:platform-framebuffer)CF1 X86_SYSFB;;
		platform:serial8250)cc1+=' SERIAL_8250';;
		platform:i8042)cc1+=' SERIO_I8042';;
		esac
	done <"${TMPDIR}/sys-modalias"
	if ${qemu:-false}; then
		export VIRT=$[VIRT+1]
		use xen && [[ " $CF " != *' -XEN '* ]] && continue # xen have virtio too + unknown 2me others
		einfo "QEMU virtio environment + USE=custom-arch"
		CF1 VIRTIO -HYPERV -XEN -X86_EXTENDED_PLATFORM
		CF1 _SENSORS_.+ -SERIAL_NONSTANDARD _SERIAL_.+ -SERIAL_8250_EXTENDED -NEW_LEDS -POWER_SUPPLY -REGULATOR -THERMAL -X86_PLATFORM_DEVICES -POWER_SUPPLY -PINCTRL -INPUT_TOUCHSCREEN
		use blobs || CF1 -FW_LOADER
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
				CF1 +SCSI ${e}SCSI +SCSI_VIRTIO +BLK_DEV_SD # as soon...
			else
				CF1 -SCSI
			fi
			if ${ata:-false}; then
				cc1+=' ATA'
			else
				CF1 -ATA
			fi
		fi
	fi
	CF1 $cc
	for i in $cc1; do
		CF1 +$i ${e}$i
	done
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
CF1 -SMP -X86{BIGSMP,GENERIC} X86_{X2APIC,UP_APIC,UP_IOAPIC} -SPARSE_IRQ -CPUSETS X86_INTEL_PSTATE INTEL_RAPL INTEL_TXT -$knl
CF1 SPARC_.+_CPUFREQ US3_MC
use xen && CF1 -HIGHMEM64G -HIGHMEM4G NOHIGHMEM X86_PAE -X86_VSMP
if use smp; then
	smt=true
	mc=true
	CF1 SMP X86_BIGSMP SPARSE_IRQ CPUSETS NUMA
else
	smt=false
	mc=false
	CF1 -SMP
fi
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
#    x86|i386|x86_64)
	export PNP_VENDOR=""
	CF1 -X86_{UP_APIC,TSC,PAT,MSR,MCE,CMOV,X2APIC,5LEVEL} -MTRR -INTEL_IDLE -KVM_INTEL -KVM_AMD -SPARSE_IRQ -CPUSETS -INTEL_TXT -$knl -INTEL_RDT_?A? X86_CPU_RESCTRL
	smt=false
	mc=false
	# X86_FEATURE_NAMES hwp broken
	CF1 -INTEL_TURBO_MAX_3
	case "$srcarch" in
	x86|i386|x86_64)
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
			ewarn "SMP+MC+SMT forced, recommended to re-ebuild kernel under new kernel."
			CF1 SMP
			smt=true
			mc=true
		fi;;
		tsc|pat|msr|mce|cmov|x2apic)CF1 X86_${i^^};;
		mtrr)CF1 ${i^^};;
		pae)CF1 X86_PAE $m64g;;
		mp)CF1 SMP;; # ?
		lm)(use multitarget || use 64-bit-bfd) && CF1 64BIT;;
		cmp_legacy)CF1 SMP;mc=true;; # ???
		up)ewarn "Running SMP on UP. Recommended useflag '-smp' and '-SMP' in ${KERNEL_CONF}";;
		est)freq+=" X86_ACPI_CPUFREQ";;
		longrun)freq+=" X86_LONGRUN";;
		vmx)CF1 XEN +KVM{,_INTEL} VIRTUALIZATION;;
		svm)CF1 XEN +KVM{,_AMD} VIRTUALIZATION;;
		smx)CF1 INTEL_TXT;;
		hypervisor)
			export VIRT=$[VIRT+1]
			CF1 PARAVIRT{,_GUEST,_SPINLOCKS,_TIME_ACCOUNTING} XEN KVM_GUEST HYPERVISOR_GUEST '&.+_KVM'
			# as seen on Clear Linux. IMHO for hw-core-agnostic case
			use smp && CF1 SLAB
			case "`lscpu|grep "^Hypervisor vendor:"`" in
			*XEN)CF1 -KVM_GUEST -HYPERV -X86_EXTENDED_PLATFORM;;
			?*)CF1 -XEN;; # my KVM = "Microsoft"
			esac;
			# at least KVM migration & other asymmetry
			#CF1 -NO_HZ -SCHED_HRTICK
			CF1 -IRQ_TIME_ACCOUNTING
#			ewarn "*************************************************************"
#			ewarn "** With QEMU VM migration I get best results with cmdline: **"
#			ewarn "** nohz=off divider=10 clocksource=acpi_pm notsc  (FIXME!) **"
#			ewarn "*************************************************************"
		;;
		xtopology)fakeHT=false;;
		hwpstate)grep -qsF X86_FEATURE_HW_PSTATE "${S}/drivers/cpufreq/powernow-k8.c" && freq+=" X86_ACPI_CPUFREQ -X86_POWERNOW_K8";;
#		hwp)CF1 -INTEL_TURBO_MAX_3;; # ? - 1) need acpi support 2) flag broken now
		rdt_a)CF1 INTEL_RDT_?A? X86_CPU_RESCTRL;;
		# la57 may be disabled
		gfni|la57)CF1 X86_5LEVEL;;
		esac
	done
	use xen && CF1 PARAVIRT{,_GUEST} HYPERVISOR_GUEST

	[[ "${processor:=0}" -gt 0 ]] && CF1 SMP
	[[ $((processor+1)) == "${cpu_cores:-1}" ]] && [[ "${siblings:-1}" == "${cpu_cores:-1}" ]] && CF1 -NUMA
	# xtopology & other flags present only on SMP running anymore
	[[ "${cpu_cores:-1}" -gt 1 ]] && mc=true && CF1 SMP
	[[ "${siblings:-0}" -gt "${cpu_cores:-1}" ]] && smt=true && CF1 SMP
#	grep -Fqs ',' /sys/devices/system/cpu/cpu*/topology/thread_siblings_list && smt=true && CF1 SMP
	# ???
	[[ "$(grep "^siblings\s*:\|^cpu cores\s*:" /proc/cpuinfo|sort -u|wc -l)" -gt 2 ]] && smt=true && mc=true && CF1 SMP NUMA
	[[ "${fpu}" != yes ]] && CF1 MATH_EMULATION

	use acpi && acpi_detect
	if [[ -n "${CF##* -NUMA *}" ]]; then
		CF1 SPARSE_IRQ CPUSETS
		# use SLAB for NUMA, but with low/middle number of CPUs
		[[ -n "${CF##* MAXSMP *}" ]] && CF1 'MAXSMP==y;=SLAB' 'MAXSMP=!y;=SLOB'
	fi

	case "${vendor_id}" in
	*Intel*)
		V=INTEL
		ucode "intel-ucode/$(printf '%02x-%02x-%02x' ${cpu_family} ${model} ${stepping})" $vendor_id
		case "${cpu_family}:${model}:${flags}:${model_name}" in
		6:79:*|6:85:*)CF1 SCHED_MC_PRIO INTEL_TURBO_MAX_3;;& # broadwell-x, skylake-x
#		*)CF1 -IOSF_MBI -X86_INTEL_LPSS -X86_INTEL_MID;;&
		5:*\ mmx\ *)CF1 M586MMX;;
		5:*\ tsc\ *)CF1 M586TSC;;
		15:*\ M\ *)CF1 MPENTIUM4 MPSC;: ${freq:=X86_SPEEDSTEP_ICH};;
		15:*)CF1 MPENTIUM4 MPSC;[[ -z "$freq" ]] && freq=X86_P4_CLOCKMOD && gov='';;

		6:28:*|6:38:*)CF1 MATOM MBONNELL;; # bonnell: "true atom"
		6:*\ sse4*)CF1 MCORE2;; # ??? 2do: try to Atom'ize: -X86_INTEL_USERCOPY -X86_P6_NOP
		6:*\ movbe\ *)CF1 MATOM MBONNELL;; # alt way - bonnell: "true atom"

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

			# detect MID. may be omitted most exotic series
			[[ "$model_name" != *Z[0-9]* ]] && CF1 -X86_INTEL_MID
			CF1 '-(?:.+_)?(?:MRFLD|MERRIFIELD)(?:_.+)?' '-(?:.+_)?(?:MFLD|MEDFIELD)(?:_.+)?'
			case "${model}" in
			38)CF1 X86_INTEL_MID;; # Silverthorne, Lincroft
			39|54|53)CF1 X86_INTEL_MID '(?:.+_)?(?:MFLD|MEDFIELD)(?:_.+)?';; # Penwell/Cedarview/Cloverview = Medfield
			74)CF1 X86_INTEL_MID '(?:.+_)?(?:MRFLD|MERRIFIELD)(?:_.+)?';; # Merriefield
			90|60)CF1 X86_INTEL_MID;; # Moorefield
			60)CF1 X86_INTEL_MID;; # TANGIER
			esac

			[[ "$model" -gt 25 ]] && CF1 INTEL_IDLE
			# 42 or 45, but+
			if [[ "$model" -lt 42 ]]; then
				CF1 -X86_INTEL_PSTATE -INTEL_RAPL -INTEL_TURBO_MAX_3
			elif [[ "$(grep INTEL_FAM6 "${S}"/drivers/platform/x86/intel_turbo_max_3.c|wc -l)" != [12] ]]; then
				ewarn "intel_turbo_max_3.c unusual. forced INTEL_TURBO_MAX_3"
				CF1 SCHED_MC_PRIO INTEL_TURBO_MAX_3
			fi
			[[ "$model" -gt 87 ]] && CF $knl
		else
			CF1 -IOSF_MBI '-X86_INTEL_(?:LPSS|MID|CE|QUARK)' -INTEL_TURBO_MAX_3 -X86_INTEL_PSTATE -INTEL_RAPL
		fi
	;;
	*AMD*)
		V=AMD
		local amf=
		[ "$cpu_family" -ge 21 ] && amf="{,_fam$(printf '%02x' ${cpu_family}})h"
		ucode "amd-ucode/microcode_amd${amf}.bin" $vendor_id
		CF1 -X86_AMD_PLATFORM_DEVICE -PAGE_TABLE_ISOLATION
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
winchip-c6)CF1 MWINCHIPC6;smt=false;;
winchip2)CF1 MWINCHIP3D;smt=false;;
c3)CF1 MCYRIXIII;smt=false;;
c3-2)CF1 MVIAC3_2;smt=false;V=CENTAUR;;
geode)CF1 MGEODE_LX;smt=false;;
k6|k6-2)CF1 MK6;smt=false;freq=X86_POWERNOW_K6;V=AMD;;
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
core2)CF1 MCORE2 $m64g;freq=X86_ACPI_CPUFREQ;;
atom|bonnell)CF1 MATOM MBONNELL $m64g;freq=X86_ACPI_CPUFREQ;V=INTEL;;
nehalem|westmere|sandybridge|ivybridge|haswell|broadwell|silvermont)CF1 MCORE2 M${march^^} $m64g;freq=X86_ACPI_CPUFREQ;V=INTEL;;
knl)CF1 MCORE2 $m64g $knl;V=INTEL;;
k6-3)CF1 MK6 $m64g;smt=false;freq=X86_POWERNOW_K6;V=AMD;;
btver1|athlon|athlon-tbird|athlon-4|athlon-xp|athlon-mp)CF1 MK7 $m64g;smt=false;freq=X86_POWERNOW_K7;V=AMD;;
btver*|bdver*|k8*|opteron*|athlon64*|athlon-fx|amdfam10|barcelona)CF1 MK8 $m64g;smt=false;freq="X86_POWERNOW_K8 X86_ACPI_CPUFREQ";gov=CONSERVATIVE;V=AMD;;
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
CF1 -CPU_SUP_.+
CF1 "CPU_SUP_${V:-.+}"
[ -n "$V" ] && {
	CF1 -MICROCODE_AMD -MICROCODE_INTEL
	CF1 "&MICROCODE_$V" MICROCODE_$V
	[ "$V" = INTEL ] || CF1 -X86_INTEL_PSTATE -INTEL_RAPL -IOSF_MBI '-X86_INTEL_(?:LPSS|MID|CE|QUARK)' -$knl -INTEL_TURBO_MAX_3 '-.*_SOC_.*INTEL_.*'
	[ "$V" = AMD ] || CF1 -X86_AMD_PLATFORM_DEVICE -AMD_NUMA '-.*_SOC_AMD_.*'
	for i in INTEL AMD; do
		[ "$V" = $i ] || CF1 "-(?:.+_)?SOC_(?:.+_)?${i}(?:_.+)?" -${i}_IOMMU
	done
}
[ -z "$V" -o "$V" = AMD ] && ucode "amd-ucode/*.bin" AuthenticAMD
[ -z "$V" -o "$V" = INTEL ] && ucode "intel-ucode/??-??-??" GenuineIntel
#_is_CF1 NUMA || _is_CF1 PARAVIRT && CF1 RCU_NOCB_CPU # ??
_is_CF1 -PARAVIRT && CF1 JUMP_LABEL

# probably 4.14+ kernels have forced SMT x86
if $smt && $mc; then
	CF1 SCHED_SMT SCHED_MC
elif $smt; then
	CF="~SCHED_SMT -SCHED_MC $CF SCHED_SMT;SCHED_MC"
elif $mc; then
	CF="~SCHED_SMT -SCHED_MC $CF SCHED_SMT==y;SCHED_MC;SCHED_SMT"
#	if (use x86 || use amd64) && grep -qF 'config SCHED_SMT' "${S}"/arch/x86/Kconfig &&
#		grep -qF 'SMT (Hyperthreading) scheduler support' "${S}"/arch/x86/Kconfig; then
#		CF1 SCHED_SMT -SCHED_MC
#	fi
#else
#	CF1 -SCHED_SMT -SCHED_MC
fi

KERNEL_CONFIG="${CF//  / }"
}

_is_CF1(){
	local s='[ 	
]'
	[ -z "${CF//*$s$1$s*}" ]
}

cflg(){
local a=" ${CFLAGS} ${CPPFLAGS} ${KERNEL_CFLAGS}" f="${1:-march=}" r
r="${a##* -D__FAKE_FLAG=-$f}"
[ "$r" = "$a" ] && r="${a##* -$f}"
echo "${r%% *}"
}

kconfig(){
	einfo "Configuring kernel"

	# force /etc/kernels/kernel.conf to be last instance after embedding, etc
	local KERNEL_CONFIG="${KERNEL_CONFIG}"
	load_conf

	external_kconfig && {
		kmake oldconfig
		return
	}
	[[ -e .config ]] || kmake defconfig >/dev/null
	export ${!KERNEL_@}
	local i=1 cfgloop=''
	while cfg_loop $[i++]; do
		local ok=false o a
		for o in '' '-relax'; do
		for a in "$(arch)" ''; do
			SRCARCH="$a" _run_env /usr/bin/perl "${SHARE}/Kconfig.pl" $o "${@}" && ok=true && break
		done
		$ok && break
		done
		$ok || die "Kconfig.pl failed"
		if use paranoid; then
			kmake oldconfig
		else
			kmake oldconfig >/dev/null 2>&1
		fi
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
	# say always ''
	# input from /dev/null looks works same, but also may be safe against "file bombing" bugs
#	yes '' 2>/dev/null |
	_run_env emake \
		CC="$(tc-getCC)" LD="$(tc-getLD)" CXX="$(tc-getCXX)" CPP="$(tc-getCPP)" AS="$(tc-getAS)" AR="$(tc-getAR)" STRIP="$(tc-getSTRIP)" NM="$(tc-getNM)" OBJCOPY="$(tc-getOBJCOPY)" OBJDUMP="$(tc-getOBJDUMP)" RANLIB="$(tc-getRANLIB)" \
		HOSTCC="$(tc-getBUILD_CC)" HOSTLD="$(tc-getBUILD_LD)" HOSTCXX="$(tc-getBUILD_CXX)" HOSTCPP="$(tc-getBUILD_CPP)" HOSTAS="$(tc-getBUILD_AS)" HOSTAR="$(tc-getBUILD_AR)" HOSTSTRIP="$(tc-getBUILD_STRIP)" HOSTNM="$(tc-getBUILD_NM)" HOSTOBJCOPY="$(tc-getBUILD_OBJCOPY)" HOSTRANLIB="$(tc-getBUILD_RANLIB)" \
		KBUILD_USERCFLAGS="$CFLAGS" KBUILD_USERLDFLAGS="$LDFLAGS" \
		ARCH=$(arch) $o "${@}" ${KERNEL_MAKEOPT} </dev/null || die
}

mktools(){
	kmake -i tools/"${@}" CFLAGS="${KERNEL_UTILS_CFLAGS}"
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

	local i reg=false
	test_cc -mgeneral-regs-only && reg=true
	to_overlay
	einfo "Fixing compats"
	echo "Supporting -mgeneral-regs-only: $reg"
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
	use custom-arch && {
		# mtune?
		for i in arch/*/Makefile*; do
			perl -E 'while(defined($s=<STDIN>)){
			$ok=$ok1 || ($s=~/\$\(CONFIG_/);
			$ok1=$ok && ($s=~/\\$/);
			if($ok){
			#while($s=~s/(\=| |cc-option,+)-march=[a-zA-Z0-9\-]*/$1/ig){
			$s=~s/-march=[a-zA-Z0-9\-]*//g;
			}
			print $s;
			};exit 0' <$i >$i._tmp && rename ._tmp '' $i._tmp
		done
		#sed -i -e 's/\(\$(CONFIG_\)-m\(arch\|tune\|cpu\)=[a-z0-9\-]*)/$1/g' arch/*/Makefile*
	}
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
	grep -q sysmacros arch/um/os-Linux/file.c || sed -i -e "s:^#include <sys/types\\.h>:#include <sys/sysmacros.h>\n#include <sys/types.h>:" arch/um/os-Linux/file.c
	sed -i -e 's:^static void sleep_delay:static noinline void sleep_delay:' drivers/media/radio/radio-aimslab.c
	# ;)
	sed -i -e 's:^#if 0$:#if 1:' drivers/net/tokenring/tms380tr.c
	# deprecated
	sed -i -e 's:defined(@:(@:' kernel/timeconst.pl
#	i=" -march=nocona"
	i=" -march=x86-64"
	$reg && i+=' -mgeneral-regs-only' || i+=' -mno-mmx -mno-sse -mno-sse2 -mno-sse3'
	if (use multitarget || use 64-bit-bfd) && test_cc -S -m64 $i && ! test_cc -S -m64 2>/dev/null; then
		einfo "-m64 arch fix"
		sed -i -e "s/ -mcmodel=small/ -mcmodel=small -m64$i/" arch/x86/boot/compressed/Makefile drivers/firmware/efi/libstub/Makefile
		sed -i -e "s/\(KBUILD_AFLAGS += -m64\|biarch := -m64\)$/\1$i/" arch/x86/Makefile*
		sed -i -e "s/^\(CC_OPTION_CFLAGS .*\)$/\1$i/" scripts/Kbuild.include
		touch "$TMPDIR/_cross"
	fi
	# broken in 5.17: -e '/KBUILD_CFLAGS += .*-mno-\(avx\|80387\|fp-ret-in-387\)/d' 
	$reg && ! grep -Fq mgeneral-regs-only arch/x86/Makefile && sed -i -e 's:-mno-mmx -mno-sse$:-mgeneral-regs-only:' -e 's:-mno-sse -mno-mmx -mno-sse2 -mno-3dnow:-mgeneral-regs-only:' {arch/x86,arch/x86/boot/compressed,drivers/firmware/efi/libstub}/Makefile
#	echo "CFLAGS_mdesc.o += -Wno-error=maybe-uninitialized" >>arch/sparc/kernel/Makefile
	chmod 770 tools/objtool/sync-check.sh
#	use zstd && [[ "${CBUILD}" != "${CTARGET:-${CHOST}}" ]] || ! (echo test|zstd -zqc -22 --ultra >/dev/null) &&
#		sed -i -e 's:(ZSTD) -22 --ultra:(ZSTD) -19:' scripts/Makefile.lib
	# pnp
#	use paranoid && return
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
	: ${KV_PATCH:=0}
	# once apon a time portage starts to check RO before pkg_prerm
	_umount
	_saved_pkg_setup
	# hardened protected
	{
		# some of modalias'es have no \n
		echo '
' >CRtmp
		cat $(find /sys -mount -name modalias|sed -e 's:$: CRtmp:')
		unlink CRtmp
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
				[ -e "$D/boot/$r" ] && r=" initrd=/$r" || {
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
			else
				# make static bootloaders happy too
				einfo "Renaming to slot *"
				rename -- "-${REAL_KV}" "-${SLOT}" "${D}"/boot/{vmlinuz,initrd}*
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
	sed -e 's:^.*/::g' -e 's:\.ko$::g' -e 's:-:_:g' | while read i; do
		grep -qFx "$i" "${TMPDIR}/unmodule.$1" && continue
		grep -Rh "^\s*obj\-\$[(]CONFIG_.*\s*\+=.*\s${i//_/[_-]}\.o" "${TMPDIR}"/unmodule.tmp|sed -e 's:).*$::g' -e 's:^.*(CONFIG_::'|sort -u|while read c; do
			$1 "$c" "$i" && echo "$i" >>"${TMPDIR}/unmodule.$1"
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
	modules_deps "$TMPDIR"/{mod-exclude.m2y,unmodule.black}
}

load_modinfo(){
	local i
	[ -e "$TMPDIR/unmodule.tmp" ] || _unmodule .
	[ -e "${WORKDIR}"/modules.alias.sh ] ||
		perl "${SHARE}"/mod2sh.pl "${WORKDIR}" >&2 || die "Unable to run '${SHARE}/mod2sh.pl'"
	. "${WORKDIR}"/modules.alias.sh || die "Broken modules.alias.sh, check mod2sh.pl!"
}

sort_detects(){
	local i p=
	for i in "${@}"; do
		case "$i" in
		+*)p+=" $i";;
		*)echo -n " $i";;
		esac
	done
	echo "$p"
}

broken_deps(){
	local i i1 j d="$TMPDIR/depends.lst"
	[ -s "$1" -a -s "$d" ] &&
	while read i; do
		grep "^$i " "$d" | while read i1 j; do
			[[ "$i1" == "$i" ]] &&
			for j in $j; do
				grep -qxF "$j" "$1" && continue
				ewarn "Embedding broken dependence: $i -> $j"
				echo $j >>"$1"
			done
		done
	done <"$1"
}

detects(){
	local i a b c d
	load_modinfo
	sort -u "${WORKDIR}"/modules.pnp "${TMPDIR}"/overlay-rd/etc/modflags/* >>"${WORKDIR}"/modules.pnp_
	sort -u "${WORKDIR}"/modules.pnp0 "${SHARE}"/etc/modflags/* >>"${WORKDIR}"/modules.pnp0_
	_sort_f "$TMPDIR"/unmodule.m2{y,n}
	{
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
	# embed depends Kconfig += modinfo
	broken_deps "$TMPDIR"/unmodule.m2y
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
	# buggy dependences only
	case "$1" in
	ACPI_VIDEO)m2y VIDEO_OUTPUT_CONTROL;;
	esac
	if grep -qFx "$2" "${TMPDIR}/unmodule.black"; then
		echo -n " +$1"
		return 1
	else
		echo -n " &$1"
		return 0
	fi
}

m2n(){
	grep -q "^CONFIG_$1=m$" .config || return
	# "-$1" may be too deep
	echo -n " $1="
	sed -i -e "s/^CONFIG_$1=m\$/# CONFIG_$1 is not set/" .config
}

mksquash(){
	local p=1 i c="${comp:+-comp $comp}"
	for i in ${MAKEOPTS}; do
		[[ "$i" == -j* ]] && p=${i#-j}
	done
	p=$[p+1-1]
	[ "${p:-0}" = 0 ] && p=1
	# reduce jobs only if look like cpus|cores+1
	[ "$p" != 1 ] && i=$(nproc) && while [ "${i:-0}" -gt 1 ]; do
		[ $p = $[i+1] ] && p=$[p-1] && break
		[ $p = $i ] && break
		i=$[i>>1]
	done
	case "$comp" in
	lzo)c+=' -Xcompression-level 9';;
	lz4)c+=' -Xhc -mem 700m';;
	zstd)c+=' -Xcompression-level 19';;
	xz)for i in X86:x86 ARM:arm,armthumb ARM64:arm,armthumb POWERPC:powerpc SPARC:sparc IA64:ia64; do
		grep -q "^CONFIG_${i%:*}=y$" "$S/.config" && c+=" -Xbcj ${i#*:}" && break
	done;;
	esac
	mksquashfs "${@}" $c -b 1m -all-root -no-recovery -no-exports -always-use-fragments -no-progress ${p:+-processors $p} || die "mksquashfs failed"
}

LICENSE(){
	grep -qF "#include <linux/module.h>" $1 || sed -i -e 's:^#include:#include <linux/module.h>\n#include:' $1
	grep -q "MODULE_LICENSE" $1 || echo "MODULE_LICENSE(\"${2:-GPL}\");" >>$1
}

userspace(){
	local k="klibc" kldir="$ROOT/usr/share/klibc"
	local i f t kb="$S/$k" img='initramfs.lst' c='' k libdir="$(get_libdir)" mod="$BDIR/lib/modules/$REAL_KV/" l sdir
	mkdir -p "$kb/"{bin,src,etc}
	if [[ -z "$KERNEL_KLIBC_SRC" ]]; then
		einfo "Copying KLIBC sources from $kldir"
		KERNEL_KLIBC_SRC=$(ls -1 "$kldir"/klibc-*.tar.*|tail -n 1)
		[[ -z "$KERNEL_KLIBC_SRC" ]] && die
		KERNEL_KLIBC_PATCHES+=" $kldir/*.patch"
	fi
	einfo "Using KLIBC $KERNEL_KLIBC_SRC"
	sdir="$kb/src/${KERNEL_KLIBC_SRC##*/}"
	sdir="${sdir%.tar.*}"
	tar -xaf "$KERNEL_KLIBC_SRC" -C "${sdir%/*}" && [ -d "$sdir" ] || die
	echo '
KLIBCOPTFLAGS += -fno-move-loop-invariants --param=max-grow-copy-bb-insns=1 -fcommon' | tee -a "$sdir"/usr/klibc/arch/*/MCONFIG
	echo 'KLIBCOPTFLAGS += -fno-asynchronous-unwind-tables' | tee -a "$sdir"/usr/klibc/arch/{i386,ppc,arm64}*/MCONFIG
	for i in $KERNEL_KLIBC_PATCHES; do
		[ -e "$i" ] || continue
		(cd "$sdir" && epatch $i) || die
	done
	einfo "Making KLIBC"
#	export CFLAGS="$CFLAGS --sysroot=${S}"
#	export KERNEL_UTILS_CFLAGS="$KERNEL_UTILS_CFLAGS --sysroot=${S}"
	i=$(arch)
	case "$i:${CTARGET:-${CHOST}}" in
	x86:i?86*)i=i386;;
	x86:*)i=x86_64;;
	riscv:riscv64*)i=riscv64;;
	mips:mips64*)i=mips64;;
	powerpc:powerpc64*)i=ppc64;;
	powerpc:*)i=ppc32;;
	esac
	[ -e "$sdir/usr/klibc/arch/$i" ] || ewarn "Kernel arch: $i, klibc has: $(cd "$sdir/usr/klibc/arch" && echo *)"
	#KERNEL_ARCH="$i"
	kmake -C "$sdir" KLIBCKERNELSRC="${S}"/usr INSTALLDIR=/ INSTALLROOT="$kb" KLIBCARCH="$i" all install
	klcc="$kb/usr/bin/klcc"
	[ -e "$klcc" ] || klcc="$kb/bin/klcc"
	sed -i -e 's%^\(\$prefix = \)"[^"]*"%\1`readlink -f $0`;$prefix=~s/(?:\\/usr)?\\/bin\\/klcc\\s*$//s%' "$klcc" || die
	l="$k/$libdir"
	[ -e "$l" ] || l="$k/lib"
	for i in "${SHARE}"/*.c; do
		einfo "Compiling $i"
		cp "$i" "$kb/src/" || die
		f="${i##*/}"
		$klcc "$kb/src/$f" -shared -s -o "$kb/bin/${f%.*}" || die
	done
	einfo "Sorting modules to new order"
	mv "${mod}modules.alias" "$TMPDIR/" && bash "${SHARE}"/kpnp --sort "$TMPDIR/modules.alias" >"${mod}modules.alias" || die
	use !blobs && [ -s "$TMPDIR/mod-blob_.lst" ] && (cd "$BDIR" && tar cf "$TMPDIR/exclude.tar" --remove-files $(cat "$TMPDIR/mod-blob_.lst"))
	if use compressed; then
		einfo "Compressing lib.loopfs"
		for i in "$l"/klibc*; do
			f="${i##*/}"
			ln -s "/usr/lib/$f" "$BDIR/lib/$f"
		done
		for i in bin; do
			mkdir -p "${BDIR}/lib/$i"
			for f in "$k/$i"/*; do
				[ -e "$f" ] &&
				case "${f##*/}" in
				cat|true|false|insmod|ln|losetup|ls|mkdir|mknod|mount|mv|nuke|readlink|sh|uname);;
				*)cp -a "$f" "${BDIR}/lib/$i/";;
				esac
			done
		done
		grep -qx CONFIG_FW_LOADER_COMPRESS=y "$S/.config" && mv "${BDIR}"/{lib/firmware,} && {
			ln -s ../firmware "${BDIR}"/lib/firmware
			find "$BDIR"/firmware/ -type f|while read i; do
				[[ "$i" == *.xz ]] || xz -z --check=crc32 --lzma2=dict=1MiB "$i"
			done
		}
		mksquash "${BDIR}/lib" lib.loopfs
		rm "$BDIR/lib/klibc"* -f 2>/dev/null
		c=NONE
	fi
	einfo "Preparing initramfs"
	mkdir "$kb/sbin"
	cp "${SHARE}/kpnp" "$kb/sbin/init"
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
	[[ -e "${BDIR}"/firmware ]] && echo 'slink /lib/firmware ../firmware 0755 0 0'
	[[ "$libdir" != lib ]] && echo "slink /$libdir lib 0755 0 0
slink /usr/$libdir lib 0755 0 0"
	for i in "$l"/klibc*; do
		f="${i##*/}"
		echo "file /usr/lib/$f ${i//\/\///} 0755 0 0"
		echo "slink /lib/$f /usr/lib/$f 0755 0 0"
	done
	for i in "${BDIR}/" "$k/bin/" "$k/usr/lib/klibc*" "-L $k"/{,usr/}{bin,sbin,etc}/'*' "${TMPDIR}/overlay-rd/"; do
		f="${i##*/}"
		find ${i%/*} ${f:+-name} "${f}" 2>/dev/null
	done | while read i; do
		i="${i//\/\///}"
		[[ -e "$i" ]] || [[ -L "$i" ]] || continue
		f="${i#$BDIR}"
		f="${f#$ROOT}"
		f="${f#$k}"
		f="/${f#/}"
		f="${f/\/usr\/$libdir\///usr/lib/}"
		f="${f#/usr/lib/klibc}"
		case "$f" in
		*/overlay-rd/*)f="/${f##*/overlay-rd/}";;
		/lib/firmware/regulatory.*)grep -qx CONFIG_CFG80211=y "$S"/.config || continue;;
		/usr/lib*|*/loop.ko|*/squashfs.ko);;
		/lib*/*)use compressed && continue;;
		/usr/*)f="${f#/usr}";;
		/bin/*)	use compressed && case "${f#/bin/}" in
			cat|true|false|insmod|ln|losetup|ls|mkdir|mknod|mount|mv|nuke|readlink|sh|uname);;
			*)echo slink "$f" "/lib$f 0755 0 0";continue;;
			esac
		esac
		if [ -L "$i" ]; then
			echo "slink $f $(readlink "$i") 0755 0 0"
			f="${f%/*}"
		elif [ -f "$i" ]; then
			echo "file $f $i 0755 0 0"
			f="${f%/*}"
		fi
		while [[ -n "${f#/}" ]]; do
			echo "dir $f 0755 0 0"
			f="${f%/*}"
		done
	done
	} | sort -u >"$img"
	if use integrated; then
		use thin || c=NONE
	else
		f="initrd-${REAL_KV}.cpio"
		"${S}"/usr/gen_init_cpio "$img" >$f || die
		img="$f"
	fi
	initramfs "$img" $c
	[ -e "$TMPDIR/exclude.tar" ] && (cd "$BDIR" && tar xf "$TMPDIR/exclude.tar" && rm "$TMPDIR/exclude.tar")
	mv "$TMPDIR/modules.alias" "${mod}"
}



_paranoid_y1(){
	[ -n "$a" ] && echo "$n$a$d" >>"$TMPDIR/aliased.lst" || echo "$i" >>"$TMPDIR/unaliased.lst"
	i=
	n=
	a=
	d=
}

_paranoid_y(){
local x y i j l n1 i= n= a= d=
rm "$TMPDIR/aliased.lst" "$TMPDIR/unaliased.lst" -f
while read x y; do
	[ -n "$y" ] &&
	case "$x" in
	filename:)
		_paranoid_y1
		i="$y"
		n=${i##*/}
		n=${n%.ko}
		n=${n//-/_}
	;;
	name:)n="$y";;
	alias:)a+="
$y";;
	depends:)
		y="${y//-/_}"
		d+="
${y//,/
}"
	;;
	esac
done <"$TMPDIR/modinfo.lst"
_paranoid_y1
load_modinfo
l=`cat "$SHARE/paranoid.m2y"`
while read i; do
	n=
	for j in $l; do
		[[ "$i" == "${S%/}$j"* ]] && n="$i" && break
	done
	[ -z "$n" ] && continue
	n=${n##*/}
	n=${n%.ko}
	n1=${n//-/_}
	grep -qFx "$n1" "$TMPDIR/aliased.lst" || echo "$n
$n1"
done <"$TMPDIR/unaliased.lst"|sort -u |modalias_reconf m2y 1
}

paranoid_y(){
	use paranoid || return 1
	einfo "Searching unaliased hw modules, bounded by $SHARE/paranoid.m2y"
	local x="$(_paranoid_y)"
	[ -z "$x" ] && return 1
	cfg_ "###paranoid: $x"
	return 0
}
