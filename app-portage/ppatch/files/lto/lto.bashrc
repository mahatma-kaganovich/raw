filterflag(){
local p v
for p in $* ; do
for v in LDFLAGS CFLAGS CPPFLAGS CXXFLAGS; do
	export $v="${!v// $p }"
	export $v="${!v#$p }"
	export $v="${!v% $p}"
done
done
}

case $CATEGORY/$PN in
dev-lang/swig|dev-lang/orc|media-plugins/live|sys-fs/mtools|dev-libs/gmp|dev-libs/ppl|app-benchmarks/bashmark|media-sound/wavpack|net-dialup/rp-l2tp|net-misc/iputils|sys-apps/dbus|sys-apps/hdparm|sys-apps/pciutils|sys-apps/sysvinit|sys-fs/dosfstools|sys-fs/squashfs-tools) filterflag -flto ;;
app-arch/bzip2) export LDFLAGS="$LDFLAGS -fPIC" ;;
esac
