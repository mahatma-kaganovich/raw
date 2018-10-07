[[ "$EBUILD_PHASE $IUSE " == configure*' custom-optimization '* ]] && [[ " $IUSE " == *' custom-cflags '* ]] && {
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
		--enable-optimize=-O*)
			o=${CFLAGS##*-O}
			[ "$o" = "$CFLAGS" ] || {
				o=${o%% *}
				[ -n "$o" ] && x="--enable-optimize=-O$o" && reason="CFLAGS"
			}
		esac
		echo "ac_add_options ${x} # ${reason}" >>.mozconfig
	done
}
case "$PN" in
seamonkey);;
*)CXXFLAGS="${CXXFLAGS//-mtls-dialect=gnu2/-mtls-dialect=gnu}";;
esac
CXXFLAGS="$CXXFLAGS -flifetime-dse=1 -fno-devirtualize -fno-ipa-cp-clone -fno-delete-null-pointer-checks"
CXXFLAGS="$CXXFLAGS -fno-fast-math"
#use abi_x86_32 &
#CXXFLAGS="$CXXFLAGS -fno-tree-vectorize -fno-tree-loop-vectorize -fno-tree-slp-vectorize"
export CXXFLAGS
use custom-optimization && filter-flags(){ true; }
use custom-cflags && append-cxxflags(){ true; }
}
