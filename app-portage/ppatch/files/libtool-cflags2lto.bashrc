# libtool strip C flags for linker, but LTO linker recompile bytecode
# fixing ltmain.* on prepare looks better, but breaks libtool self (?)
# keep both (patch & sed) versions until tests
case "$EBUILD_PHASE" in
compile)[[ " $LDFLAGS " == *\ -flto[\ =]* || " $LDFLAGS " == *\ -fuse-linker-plugin\ * ]] &&
	{
		case "$PN" in
		libtool);;
		*)find "$WORKDIR" -name ltmain.sh;;
		esac
		find "$WORKDIR" -name libtool
	}|while read i; do
	    patch -Ni /usr/ppatch/libtool-cflags2lto.patch "$i" && elog "libtool patched: $i" || {
		grep -q '\-O\*|-g\*|' "$i" &&
		sed -i -e 's/-O\*|-g\*|/-O*|-f*|-m*|*Wa,*|--param=*|-g*|/' "$i" && elog "libtool patched2: $i"
	    }
	    # if other solutions failed
	    patch -Ni /usr/ppatch/libtool-common.patch "$i"
	done
;;
esac
true
