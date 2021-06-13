[ -v PORTDIR ] || PORTDIR=${PORTAGE_ECLASS_LOCATIONS[-1]}
[ -e "${PORTDIR}/eclass/mozcoreconf-2.eclass" ] && source "${PORTDIR}/eclass/mozcoreconf-2.eclass"

mozconfig_init() {
	declare enable_optimize pango_version myext x
	declare MOZ=$([[ ${PN} == mozilla || ${PN} == gecko-sdk ]] && echo true || echo false)
	declare FF=$([[ ${PN} == *firefox ]] && echo true || echo false)
	declare TB=$([[ ${PN} == *thunderbird ]] && echo true || echo false)
	declare SB=$([[ ${PN} == *sunbird ]] && echo true || echo false)
	declare EM=$([[ ${PN} == enigmail ]] && echo true || echo false)
	declare XUL=$([[ ${PN} == *xulrunner ]] && echo true || echo false)
	declare SM=$([[ ${PN} == seamonkey ]] && echo true || echo false)

	####################################
	#
	# Setup the initial .mozconfig
	# See http://www.mozilla.org/build/configure-build.html
	#
	####################################

	: >.mozconfig
	case ${PN} in
		mozilla|gecko-sdk)
			# The other builds have an initial --enable-extensions in their
			# .mozconfig.  The "default" set in configure applies to mozilla
			# specifically.
			mozconfig_annotate "" --enable-extensions=default ;;
		*firefox)
			cp browser/config/mozconfig .mozconfig \
				|| die "cp browser/config/mozconfig failed" ;;
		enigmail)
			cp mail/config/mozconfig .mozconfig \
				|| die "cp mail/config/mozconfig failed" ;;
		*xulrunner)
			cp xulrunner/config/mozconfig .mozconfig \
				|| die "cp xulrunner/config/mozconfig failed" ;;
		*sunbird)
			cp calendar/sunbird/config/mozconfig .mozconfig \
				|| die "cp calendar/sunbird/config/mozconfig failed" ;;
		*thunderbird)
			mozconfig_annotate "" --enable-application=mail ;;
		seamonkey)
			# The other builds have an initial --enable-extensions in their
			# .mozconfig.  The "default" set in configure applies to mozilla
			# specifically.
			mozconfig_annotate "" --enable-application=suite
			mozconfig_annotate "" --enable-extensions=default ;;
	esac

	####################################
	#
	# CFLAGS setup and ARCH support
	#
	####################################

	# Set optimization level
	if [[ ${ARCH} == hppa ]]; then
		mozconfig_annotate "more than -O0 causes segfaults on hppa" --enable-optimize=-O0
	elif use custom-optimization; then
		# Set optimization level based on CFLAGS
		if is-flag -O0; then
			mozconfig_annotate "from CFLAGS" --enable-optimize=-O0
		elif [[ ${ARCH} == ppc ]] && has_version '>=sys-libs/glibc-2.8'; then
			mozconfig_annotate "more than -O1 segfaults on ppc with glibc-2.8" --enable-optimize=-O1
		elif is-flag -O1; then
			mozconfig_annotate "from CFLAGS" --enable-optimize=-O1
		elif is-flag -Os; then
			mozconfig_annotate "from CFLAGS" --enable-optimize=-Os
		elif ${XUL}; then
			mozconfig_annotate "xulrunner default" --enable-optimize=-O2
		elif is-flag -O3; then
			mozconfig_annotate "from CFLAGS" --enable-optimize=-O3
		else
			mozconfig_annotate "Gentoo's default optimization" --enable-optimize=-O2
		fi
	else
		# Enable Mozilla's default
		mozconfig_annotate "mozilla default" --enable-optimize
	fi

	# Now strip optimization from CFLAGS so it doesn't end up in the
	# compile string
	filter-flags '-O*'

	use custom-cflags || strip-flags

	# Historically we have needed to add -fPIC manually for 64-bit.
	# I don't know why -fPIC needed for 64bit and want to off
	use pic && append-flags -fPIC

	# Additional ARCH support
	case "${ARCH}" in
	alpha)
		# Additionally, alpha should *always* build with -mieee for correct math
		# operation
		append-flags -mieee
		;;

	amd64)
		use debug || append-flags -fomit-frame-pointer
		;;

	ppc64)
		append-flags -mminimal-toc
		;;

	ppc)
		# Fix to avoid gcc-3.3.x micompilation issues.
		if [[ $(gcc-major-version).$(gcc-minor-version) == 3.3 ]]; then
			append-flags -fno-strict-aliasing
		fi
		;;

	sparc)
		# Sparc support ...
		replace-sparc64-flags
		;;

	x86)
		use debug || append-flags -fomit-frame-pointer
		if [[ $(gcc-major-version) -eq 3 ]]; then
			# gcc-3 prior to 3.2.3 doesn't work well for pentium4
			# see bug 25332
			if [[ $(gcc-minor-version) -lt 2 ||
				( $(gcc-minor-version) -eq 2 && $(gcc-micro-version) -lt 3 ) ]]
			then
				replace-flags -march=pentium4 -march=pentium3
				filter-flags -msse2
			fi
		elif [[ $(gcc-major-version).$(gcc-minor-version) == 4.4 ]] ; then
			if use sse ; then
				append-flags -msse -mstackrealign
			else
				append-flags -mno-sse
			fi
		fi
		;;
	esac

	if [[ $(gcc-major-version) -eq 3 ]]; then
		# Enable us to use flash, etc plugins compiled with gcc-2.95.3
		mozconfig_annotate "building with >=gcc-3" --enable-old-abi-compat-wrappers

		# Needed to build without warnings on gcc-3
		CXXFLAGS="${CXXFLAGS} -Wno-deprecated"
	fi

	# Go a little faster; use less RAM
	append-flags "$MAKEEDIT_FLAGS"

	####################################
	#
	# mozconfig setup
	#
	####################################

	mozconfig_annotate gentoo \
		--disable-installer \
		--disable-pedantic \
		--enable-crypto \
		--with-system-jpeg \
		--with-system-zlib \
		--with-system-bz2 \
		--disable-updater \
		--enable-pango \
		--enable-svg \
		--enable-system-cairo \
		--with-distribution-id=org.gentoo

	if ! use custom-optimization; then
		mozconfig_annotate -custom-optimization \
			--disable-strip \
			--disable-strip-libs \
			--disable-install-strip
	elif ${XUL} ; then
		mozconfig_annotate xulrunner \
			--disable-strip \
			--disable-strip-libs \
			--disable-install-strip
	else
		mozconfig_use_enable !debug strip
		mozconfig_use_enable !debug strip-libs
		mozconfig_use_enable !debug install-strip
	fi

	if [[ ${PN} != seamonkey ]]; then
		mozconfig_annotate gentoo \
			--enable-single-profile \
			--disable-profilesharing \
			--disable-profilelocking
	fi

	# Here is a strange one...
	if is-flag '-mcpu=ultrasparc*' || is-flag '-mtune=ultrasparc*'; then
		mozconfig_annotate "building on ultrasparc" --enable-js-ultrasparc
	fi

	# Currently --enable-elf-dynstr-gc only works for x86,
	# thanks to Jason Wever <weeve@gentoo.org> for the fix.
	if use x86 && [[ ${enable_optimize} != -O0 ]]; then
		mozconfig_annotate "${ARCH} optimized build" --enable-elf-dynstr-gc
	fi

	# jemalloc won't build with older glibc
	! has_version ">=sys-libs/glibc-2.4" && mozconfig_annotate "we have old glibc" --disable-jemalloc
}

# Simulate the silly csh makemake script
makemake() {
	typeset m topdir
	for m in $(find . -name Makefile.in); do
		topdir=$(echo "$m" | sed -r 's:[^/]+:..:g')
		sed -e "s:@srcdir@:.:g" -e "s:@top_srcdir@:${topdir}:g" \
			< ${m} > ${m%.in} || die "sed ${m} failed"
	done
}

makemake2() {
	for m in $(find ../ -name Makefile.in); do
		topdir=$(echo "$m" | sed -r 's:[^/]+:..:g')
		sed -e "s:@srcdir@:.:g" -e "s:@top_srcdir@:${topdir}:g" \
			< ${m} > ${m%.in} || die "sed ${m} failed"
	done
}

# mozconfig_annotate: add an annotated line to .mozconfig
#
# Example:
# mozconfig_annotate "building on ultrasparc" --enable-js-ultrasparc
# => ac_add_options --enable-js-ultrasparc # building on ultrasparc
mozconfig_annotate() {
	declare reason=$1 x ; shift
	[[ $# -gt 0 ]] || die "mozconfig_annotate missing flags for ${reason}\!"
	for x in ${*}; do
		echo "ac_add_options ${x} # ${reason}" >>.mozconfig
	done
}

# mozconfig_use_enable: add a line to .mozconfig based on a USE-flag
#
# Example:
# mozconfig_use_enable truetype freetype2
# => ac_add_options --enable-freetype2 # +truetype
mozconfig_use_enable() {
	declare flag=$(use_enable "$@")
	mozconfig_annotate "$(use $1 && echo +$1 || echo -$1)" "${flag}"
}

# mozconfig_use_with: add a line to .mozconfig based on a USE-flag
#
# Example:
# mozconfig_use_with kerberos gss-api /usr/$(get_libdir)
# => ac_add_options --with-gss-api=/usr/lib # +kerberos
mozconfig_use_with() {
	declare flag=$(use_with "$@")
	mozconfig_annotate "$(use $1 && echo +$1 || echo -$1)" "${flag}"
}

# mozconfig_use_extension: enable or disable an extension based on a USE-flag
#
# Example:
# mozconfig_use_extension gnome gnomevfs
# => ac_add_options --enable-extensions=gnomevfs
mozconfig_use_extension() {
	declare minus=$(use $1 || echo -)
	mozconfig_annotate "${minus:-+}$1" --enable-extensions=${minus}${2}
}

# mozconfig_final: display a table describing all configuration options paired
# with reasons, then clean up extensions list
mozconfig_final() {
	declare ac opt hash reason
	use moznosystem && sed -i -e 's/--enable-system-\([^ =]*\).*/--disable-system-\1/g' -e 's/--with-system-\([^ =]*\).*/--without-system-\1/g' .mozconfig
	echo
	echo "=========================================================="
	echo "Building ${PF} with the following configuration"
	grep ^ac_add_options .mozconfig | while read ac opt hash reason; do
		[[ -z ${hash} || ${hash} == \# ]] \
			|| die "error reading mozconfig: ${ac} ${opt} ${hash} ${reason}"
		printf "    %-30s  %s\n" "${opt}" "${reason:-mozilla.org default}"
	done
	echo "=========================================================="
	echo

	# Resolve multiple --enable-extensions down to one
	declare exts=$(sed -n 's/^ac_add_options --enable-extensions=\([^ ]*\).*/\1/p' \
		.mozconfig | xargs)
	sed -i '/^ac_add_options --enable-extensions/d' .mozconfig
	echo "ac_add_options --enable-extensions=${exts// /,}" >> .mozconfig
}
