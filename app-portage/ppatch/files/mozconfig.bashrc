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
		--enable-optimize=-O*)use custom-optimization && o=${CXXFLAGS##*-O} && [ "$o" != "$CXXFLAGS" ] && o=${o%% *} && [ -n "$o" ] && {
			reason=custom-optimization
			if [[ "${CFLAGS##*-O}" == "$o"* ]] || use !custom-cflags; then
				x="--enable-optimize=-O$o"
			else
				x="--enable-optimize=-w"
			fi
			[ "$o" = fast ] && o=3
			[[ "$o" == [123] ]] || o=2
			export CARGO_RUSTCFLAGS="$CARGO_RUSTCFLAGS -C opt-level=$o"
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
	[[ " $IUSE " == *' debug '* ]] && use debug ||
	    sed -i -e '/MOZ_GECKO_PROFILER/d' $(grep -lRw MOZ_GECKO_PROFILER "$WORKDIR" --include=moz.configure)
	export CARGO_RUSTCFLAGS="$CARGO_RUSTCFLAGS -C debuginfo=0"
	[[ "${CFLAGS##*-march=}" == native* ]] && export CARGO_RUSTCFLAGS="$CARGO_RUSTCFLAGS -C target-cpu=native"
	export CARGOFLAGS="$CARGOFLAGS --jobs 1"
	use custom-cflags && {
		case "$PN" in
		thunderbird);;
		seamonkey);;
		*)filter-flags -mtls-dialect=gnu2;;
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
			filter-flags '-Wl,--sort-*' # -pipe
			append-cxxflags $CFLAGS_SMALL -fno-reschedule-modulo-scheduled-loops
			# or --enable-optimize=-w
#			replace-flags '-O*' -O2
			filter-flags $CFLAGS_NATIVE
			append-flags $CFLAGS_CPU
			append-ldflags $CFLAGS_CPU
		}
		append-cxxflags -flifetime-dse=1 -fno-devirtualize -fno-ipa-cp-clone -fno-delete-null-pointer-checks -fno-fast-math
#		use x86 && append-cxxflags -fno-tree-vectorize -fno-tree-loop-vectorize -fno-tree-slp-vectorize
		export ALDFLAGS="${LDFLAGS}"
	}
;;
esac
