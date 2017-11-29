mozconfig_annotate() {
	declare reason=$1 x ; shift
	[[ $# -gt 0 ]] || die "mozconfig_annotate missing flags for ${reason}\!"
	for x in ${*}; do
		case "$x:$reason" in
		--enable-pie:*)gcc -v 2>&1 |grep -q "\--disable-default-pie" && x='--disable-pie';;
		--enable-optimize=-O2:Workaround*)append-cflags -finline-functions -funswitch-loops -fpeel-loops;;
		esac;
		echo "ac_add_options ${x} # ${reason}" >>.mozconfig
	done
}
