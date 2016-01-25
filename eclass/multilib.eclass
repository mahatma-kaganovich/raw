source "${PORTDIR}/eclass/multilib.eclass"

# CPP= for samba-4.3.4
# https://bugs.gentoo.org/show_bug.cgi?id=572104

multilib_toolchain_setup() {
	local v vv

	export ABI=$1

	# First restore any saved state we have laying around.
	if [[ ${_DEFAULT_ABI_SAVED} == "true" ]] ; then
		for v in CHOST CBUILD AS CC CXX F77 FC LD PKG_CONFIG_{LIBDIR,PATH} ; do
			vv="_abi_saved_${v}"
			[[ ${!vv+set} == "set" ]] && export ${v}="${!vv}" || unset ${v}
			unset ${vv}
		done
		unset _DEFAULT_ABI_SAVED
	fi

	# We want to avoid the behind-the-back magic of gcc-config as it
	# screws up ccache and distcc.  See #196243 for more info.
	if [[ ${ABI} != ${DEFAULT_ABI} ]] ; then
		# Back that multilib-ass up so we can restore it later
		for v in CHOST CBUILD AS CC CXX CPP F77 FC LD PKG_CONFIG_{LIBDIR,PATH} ; do
			vv="_abi_saved_${v}"
			[[ ${!v+set} == "set" ]] && export ${vv}="${!v}" || unset ${vv}
		done
		export _DEFAULT_ABI_SAVED="true"

		# Set the CHOST native first so that we pick up the native
		# toolchain and not a cross-compiler by accident #202811.
		export CHOST=$(get_abi_CHOST ${DEFAULT_ABI})
		export CC="$(tc-getCC) $(get_abi_CFLAGS)"
		export CXX="$(tc-getCXX) $(get_abi_CFLAGS)"
#		export CPP="$(tc-getCPP)"
		unset -v CPP
		export F77="$(tc-getF77) $(get_abi_CFLAGS)"
		export FC="$(tc-getFC) $(get_abi_CFLAGS)"
		export LD="$(tc-getLD) $(get_abi_LDFLAGS)"
		export CHOST=$(get_abi_CHOST $1)
		export CBUILD=$(get_abi_CHOST $1)
		export PKG_CONFIG_LIBDIR=${EPREFIX}/usr/$(get_libdir)/pkgconfig
		export PKG_CONFIG_PATH=${EPREFIX}/usr/share/pkgconfig
	fi
}
