[[ "$EBUILD_PHASE $IUSE " == configure*' custom-optimization '* ]] && mozconfig_annotate() {
	declare reason=$1 x ; shift
	[[ $# -gt 0 ]] || die "mozconfig_annotate missing flags for ${reason}\!"
	for x in ${*}; do
		case "$x:$reason" in
		--enable-pie:*)gcc -v 2>&1 |grep -q "\--disable-default-pie" && x='--disable-pie';;
		--enable-optimize=-O2:Workaround*)
			append-cflags -finline-functions
			append-flags -funswitch-loops -fpeel-loops -fpredictive-commoning -fgcse-after-reload -ftree-loop-distribute-patterns -fsplit-paths -fvect-cost-model -ftree-partial-pre
			# 2test
#			append-cflags -ftree-vectorize -fipa-cp-clone
#			append-flags -ffast-math
		;;
		esac
		echo "ac_add_options ${x} # ${reason}" >>.mozconfig
	done
}
