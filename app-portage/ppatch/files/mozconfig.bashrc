[[ " $IUSE " == configure*' custom-optimization '* ]] && [[ " $IUSE " == *' custom-cflags '* ]] &&
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
		--enable-optimize=-O*)use custom-optimization && {
			o=${CFLAGS##*-O}
			[ "$o" = "$CFLAGS" ] || {
				o=${o%% *}
				[ -n "$o" ] && x="--enable-optimize=-O$o" && reason=custom-optimization
			}
		}
		;;
		esac
		echo "ac_add_options ${x} # ${reason}" >>.mozconfig
	done
}
use custom-optimization && filter-flags(){ true; }
use custom-cflags && append-cxxflags(){ true; }
;;
setup)
case "$PN" in
thunderbird);;
seamonkey);;
*)
	filter-flags -mtls-dialect=gnu2
;;
esac
[[ " $IUSE " == *' lto '* ]] && use lto && filter-flags '-flto*'
filter-flags -ffat-lto-objects -flto-odr-type-merging
(is-flagq -Ofast || is-flagq -ffast-math) && CXXFLAGS+=' -fno-fast-math'
CXXFLAGS+=' -flifetime-dse=1 -fno-devirtualize -fno-ipa-cp-clone -fno-delete-null-pointer-checks'
#use x86 && CXXFLAGS+=" -fno-tree-vectorize -fno-tree-loop-vectorize -fno-tree-slp-vectorize"
export CXXFLAGS
;;
esac

