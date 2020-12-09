[[ " $IUSE " == *' custom-optimization '* ]] && [[ " $IUSE " == *' custom-cflags '* ]] && {
_rust_add(){
	local i
	for i in RUSTFLAGS CARGO_RUSTCFLAGS MOZ_RUST_DEFAULT_FLAGS; do
		export $i="$* ${!i}"
	done
}
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
#		--enable-release)use custom-optimization && x=${x//enable/disable};;
		--enable-pie)use custom-cflags && (gcc -v 2>&1 |grep -q "\--disable-default-pie") && continue;;
		--enable-linker=gold)
			! which ld.gold && x=--enable-linker=bfd && reason='no ld.gold' ||
			filter-ldflags -Wl,--sort-section=alignment -Wl,--reduce-memory-overheads
		;;
		--enable-linker=lld)filter-ldflags -Wl,--reduce-memory-overheads -Wl,--no-ld-generated-unwind-info;;
		--enable-lto=*|--enable-lto)
			filter-flags -fno-asynchronous-unwind-tables
			filter-ldflags -Wl,--no-ld-generated-unwind-info -Wl,--no-eh-frame-hdr
		;;
		--enable-optimize=-O*)use custom-optimization && o=${CXXFLAGS##*-O} && [ "$o" != "$CXXFLAGS" ] && o=${o%% *} && [ -n "$o" ] && {
			reason=custom-optimization
			local i= i1= f= f1=
			use custom-cflags || replace-flags -Ofast -O3
			case "$o" in
			3|fast)
				#i1+=' -fno-ipa-cp-clone'
				#[[ ${ARCH} == x86 ]] &&
				{
				    test-flag-CC -fvect-cost-model=cheap &&
					i+=' -fvect-cost-model=cheap -fsimd-cost-model=cheap' ||
					i+=' -fno-tree-vectorize -fno-tree-loop-vectorize -fno-tree-slp-vectorize'
				}
			;;&
			fast)
				# math moved to flags.bashrc
				#i1+=' -fno-fast-math'
				#i1+=' -ftrapping-math'
				use custom-cflags || o=3
			;;
			esac
			for i in $i; do
				test-flag-CC "$i" && f+=" $i"
			done
			for i in $i1; do
				test-flag-CXX "$i" && f1+=" $i"
			done
			[ -n "$f$f1" ] && {
				use custom-cflags || {
					strip-flags
					strip-flags(){ true; }
				}
				# over stubs
				export CFLAGS="$CFLAGS$f"
				export CXXFLAGS="$CXXFLAGS$f$f1"
			}
			x="-O$o"
			[[ "${CFLAGS##*-O}" != "$o"* ]] && x=-w
			x="--enable-optimize=$x"
			[ "$o" = fast ] && o=3
			[[ "$o" == [123] ]] || o=2
			_rust_add "-Copt-level=$o"
#			export RUSTC_OPT_LEVEL=$o
			#[ -e Cargo.toml ] && {
			#	echo "mk_add_options MOZ_RUST_DEFAULT_FLAGS=\"$RUSTFLAGS\"" >>.mozconfig
			#	echo "mk_add_options RUSTFLAGS=\"$RUSTFLAGS\"" >>.mozconfig
			#	sed -i -e "s:^opt-level = [0-3]$:opt-level = $o:" Cargo.toml
			#}
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
	# unsure now
	: ${RUSTFLAGS:=$CARGO_RUSTCFLAGS}
	: ${CARGO_RUSTCFLAGS:=$RUSTFLAGS}
	: ${MOZ_RUST_DEFAULT_FLAGS:=$RUSTFLAGS}
	_rust_add -Cdebuginfo=0
	i="${CFLAGS##*-march=}"
	[ "$i" != "$CFLAGS" ] && i="${i%% *}" && (rustc --print target-cpus|grep -q "^ *$i ") &&
		_rust_add -Ctarget-cpu=$i
	# todo? - disable also "rustc --print target-features" by CFLAGS
	export CARGOFLAGS="$CARGOFLAGS --jobs 1"
	use custom-cflags && {
		case "$PN" in
		thunderbird|seamonkey)replace-flags -Wl,--strip-all -Wl,--strip-debug;;&
		esac
#		[[ "$CXXFLAGS" == *[Of]fast* ]] && append-cxxflags -fno-fast-math # -ftrapping-math
		filter-flags -ffat-lto-objects
#		[[ " $IUSE " == *' lto '* ]] && use lto &&
			filter-flags -flto '-flto=*'
#		is-flagq -flto || is-flagq '-flto=*' && {
		[ "$PN" = seamonkey ] || {
			filter-flags -fno-asynchronous-unwind-tables
			filter-ldflags -Wl,--no-ld-generated-unwind-info -Wl,--no-eh-frame-hdr
		}
		replace-flags -mfpmath=both -mfpmath=sse
		replace-flags '-mfpmath=sse*387' -mfpmath=sse
		replace-flags '-mfpmath=387*sse' -mfpmath=sse
#		use x86 && append-cxxflags -fno-tree-vectorize -fno-tree-loop-vectorize -fno-tree-slp-vectorize
		export ALDFLAGS="${LDFLAGS}"
	}
;;
esac
}
