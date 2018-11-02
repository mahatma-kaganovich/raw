[[ " $IUSE " == *' custom-optimization '* ]] && [[ " $IUSE " == *' custom-cflags '* ]] &&
case "$EBUILD_PHASE" in
configure)
mozconfig_annotate() {
	declare reason=$1 x ; shift
	[[ $# -gt 0 ]] || die "mozconfig_annotate missing flags for ${reason}\!"
	for x in ${*}; do
		case "$x" in
		--enable-optimize*)
			echo "MOZILLA_CONFIG=$MOZILLA_CONFIG"
			[ -n "$MOZILLA_CONFIG" ] && mozconfig_annotate '$MOZILLA_CONFIG' $MOZILLA_CONFIG
		;;&
		--enable-pie)gcc -v 2>&1 |grep -q "\--disable-default-pie" && x='--disable-pie';;
		--enable-linker=gold)filter-ldflags -Wl,--sort-section=alignment -Wl,--reduce-memory-overheads;;
		--enable-optimize=-O*)use custom-optimization && o=${CFLAGS##*-O} && [ "$o" != "$CFLAGS" ] &&
			o=${o%% *} && [ -n "$o" ] && x="--enable-optimize=-O$o" && reason=custom-optimization
		;;
		esac
		echo "ac_add_options ${x} # ${reason}" >>.mozconfig
	done
}
use custom-optimization && filter-flags(){ true; }
use custom-cflags && append-cxxflags(){ true; }
;;
prepare)
case "$PN" in
thunderbird);;
seamonkey);;
*)
	filter-flags -mtls-dialect=gnu2
;;
esac
#[[ " $IUSE " == *' lto '* ]] && use lto &&
	filter-flags '-flto*' '*-lto-*' -fuse-linker-plugin -fdevirtualize-at-ltrans
[[ " $CFLAGS" == *' -flto'* ]] && {
	filter-flags -ffat-lto-objects -flto-odr-type-merging -fdevirtualize-at-ltrans
	append-flags -flto-partition=none
	append-ldflags -flto-partition=none
}
[[ "${CFLAGS##*-O}" != 2* ]] && [[ "${CXXFLAGS##*-O}" == 2* ]] && {
	elog "C != -O2 && CXX = -O2 - optimize size & build"
	filter-flags '-Wl,--sort-*' -pipe
	[[ "$CXXFLAGS" == *-floop-nest-optimize* ]] && append-cxxflags -fno-loop-nest-optimize
	[[ "$CXXFLAGS" == *-floop-nest-optimize* ]] && append-cxxflags -malign-data=abi
	append-cxxflags -fno-reschedule-modulo-scheduled-loops
	append-cxxflags -fno-unroll-loops -fno-prefetch-loop-arrays -fno-tree-vectorize
	append-cxxflags -O2
	append-flags $CFLAGS_CPU
	append-ldflags $CFLAGS_CPU
}
append-cxxflags -flifetime-dse=1 -fno-devirtualize -fno-ipa-cp-clone -fno-delete-null-pointer-checks -fno-fast-math
#use x86 && append-cxxflags -fno-tree-vectorize -fno-tree-loop-vectorize -fno-tree-slp-vectorize
export CARGOFLAGS="$CARGOFLAGS --jobs 1"
;;
esac

