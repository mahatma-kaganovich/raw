[[ " $IUSE " == *' custom-optimization '* ]] && [[ " $IUSE " == *' custom-cflags '* ]] &&
case "$EBUILD_PHASE" in
configure)
mozconfig_annotate() {
	declare reason=$1 x; shift
	[[ $# -gt 0 ]] || die "mozconfig_annotate missing flags for ${reason}\!"
	for x in ${*}; do
		case "$x" in
		--enable-optimize*)
			echo "MOZILLA_CONFIG=$MOZILLA_CONFIG"
			[ -n "$MOZILLA_CONFIG" ] && mozconfig_annotate '$MOZILLA_CONFIG' $MOZILLA_CONFIG
		;;&
		--enable-pie)gcc -v 2>&1 |grep -q "\--disable-default-pie" && continue;;
		--enable-linker=gold)filter-ldflags -Wl,--sort-section=alignment -Wl,--reduce-memory-overheads;;
		--enable-linker=lld)filter-ldflags -Wl,--reduce-memory-overheads;;
		--enable-optimize=-O*)use custom-optimization && o=${CXXFLAGS##*-O} && [ "$o" != "$CXXFLAGS" ] && o=${o%% *} && [ -n "$o" ] && {
			reason=custom-optimization
			# gcc vs clang: IMHO "-fno-fast-math -Ofast" positioning differ. force strict order anywere
			local i ff=
			for i in -fno-fast-math -fno-ipa-cp-clone -fno-tree-vectorize -fno-tree-loop-vectorize -fno-tree-slp-vectorize; do
				is-flagq "$i" && ff+=" $i"
			done
			if ([[ "${CFLAGS##*-O}" == "$o"* ]] && [ -z "$ff" ]) || use !custom-cflags; then
				x="-O$o"
			else
				x=-w
			fi
			x="--enable-optimize=$x"
			[ "$o" = fast ] && o=3
			[[ "$o" == [123] ]] || o=2
			export CARGO_RUSTCFLAGS="-C opt-level=$o $CARGO_RUSTCFLAGS"
		}
		;;
		esac
		echo "ac_add_options ${x} # ${reason}" >>.mozconfig
	done
}
use custom-optimization && filter-flags(){ true; }
use custom-cflags && append-cxxflags(){ true; }
;;

prepare)
	i='MOZ_GECKO_PROFILER\|MOZ_ENABLE_PROFILER_SPS'
	[[ " $IUSE " == *' debug '* ]] && use debug ||
	    sed -i -e "/$i/d" $(grep -lRw "$i" "$WORKDIR" --include=moz.configure)
	export CARGO_RUSTCFLAGS="-C debuginfo=0 $CARGO_RUSTCFLAGS"
	[[ "${CFLAGS##*-march=}" == native* ]] && export CARGO_RUSTCFLAGS="$CARGO_RUSTCFLAGS -C target-cpu=native"
	export CARGOFLAGS="$CARGOFLAGS --jobs 1"
	use custom-cflags && {
		case "$PN" in
		thunderbird);;
		seamonkey)append-cxxflags -fno-ipa-cp-clone;;
		*)filter-flags -mtls-dialect=gnu2;;
		esac
		[[ "$CXXFLAGS" == *fast* ]] && append-cxxflags -fno-fast-math
		#[[ " $IUSE " == *' lto '* ]] && use lto &&
		filter-flags -flto '-flto=*' -ffat-lto-objects
		replace-flags -mfpmath=both -mfpmath=sse
		replace-flags '-mfpmath=sse*387' -mfpmath=sse
		replace-flags '-mfpmath=387*sse' -mfpmath=sse
#		use x86 && append-cxxflags -fno-tree-vectorize -fno-tree-loop-vectorize -fno-tree-slp-vectorize
		export ALDFLAGS="${LDFLAGS}"
	}
;;
esac
