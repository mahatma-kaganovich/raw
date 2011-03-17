EAPI="3"
GIT=$([[ ${PVR} = *9999* ]] && echo "git")
EGIT_REPO_URI="git://anongit.freedesktop.org/mesa/mesa"

inherit autotools multilib flag-o-matic ${GIT} portability

OPENGL_DIR="xorg-x11"

MY_PN="${PN/m/M}"
MY_P="${MY_PN}-${PV/_/-}"
MY_SRC_P="${MY_PN}Lib-${PV/_/-}"
DESCRIPTION="OpenGL-like graphic library for Linux"
HOMEPAGE="http://mesa3d.sourceforge.net/"
if [[ $PV = *_rc* ]]; then
	SRC_URI="http://www.mesa3d.org/beta/${MY_SRC_P}.tar.gz"
elif [[ $PV = 9999 ]]; then
	SRC_URI=""
elif [[ $PVR = *-r9999 ]]; then
	EGIT_BRANCH="${PN}_${PV//./_}_branch"
	SRC_URI=""
else
	SRC_URI="mirror://sourceforge/mesa3d/${MY_SRC_P}.tar.bz2"
fi
LICENSE="LGPL-2"
SLOT="0"
KEYWORDS="~alpha ~amd64 ~arm ~hppa ~ia64 ~mips ~ppc ~ppc64 ~sh ~sparc ~x86 ~x86-fbsd raw"
IUSE_VIDEO_CARDS="
	video_cards_vmware
	video_cards_nouveau
	video_cards_radeonhd
	video_cards_intel
	video_cards_mach64
	video_cards_mga
	video_cards_none
	video_cards_r128
	video_cards_radeon
	video_cards_s3virge
	video_cards_savage
	video_cards_sis
	video_cards_sunffb
	video_cards_tdfx
	video_cards_trident
	video_cards_via"
IUSE="${IUSE_VIDEO_CARDS}
	+mmx
	+sse
	+3dnow
	debug
	doc
	pic
	motif
	nptl
	xcb
	kernel_FreeBSD
	+gallium
	glut
	xlib
	osmesa
	llvm
	X
	+fbdev
	+gles
	dricore
	selinux
	32bit
	64bit
	d3d"

RDEPEND="app-admin/eselect-opengl
	dev-libs/expat
	|| ( <x11-libs/libX11-1.3.99.901[xcb?] >=x11-libs/libX11-1.3.99.901 )
	x11-libs/libXext
	x11-libs/libXxf86vm
	x11-libs/libXi
	x11-libs/libXmu
	x11-libs/libXdamage
	x11-libs/libdrm
	x11-libs/libICE
	motif? ( x11-libs/openmotif )
	doc? ( app-doc/opengl-manpages )
	d3d? ( app-emulation/wine )
	llvm? (
		dev-libs/udis86
		>=sys-devel/llvm-2.7
		x11-libs/libdrm
	)
	gallium? (
		x11-libs/libdrm
		video_cards_intel? ( x11-libs/libdrm[video_cards_intel] )
		video_cards_radeon? ( x11-libs/libdrm[video_cards_radeon] )
	)
	video_cards_vmware? ( x11-libs/libdrm[video_cards_vmware] )
	video_cards_nouveau? ( x11-libs/libdrm[video_cards_nouveau] )
	!<=x11-base/xorg-x11-6.9"
DEPEND="${RDEPEND}
	glut? ( !media-libs/freeglut )
	!<=x11-proto/xf86driproto-2.0.3
	dev-util/pkgconfig
	x11-misc/makedepend
	dev-libs/libxml2[python]
	x11-proto/inputproto
	x11-proto/xextproto
	!hppa? ( x11-proto/xf86driproto )
	>=x11-proto/dri2proto-1.99.3
	x11-proto/xf86vidmodeproto
	>=x11-proto/glproto-1.4.8
	gallium? ( x11-base/xorg-server )
	motif? ( x11-proto/printproto )"

PROVIDE="glut? ( virtual/glut )"

S="${WORKDIR}/${MY_P}"

# Think about: ggi, svga, fbcon, no-X configs

pkg_setup() {
	if use debug; then
		append-flags -g
	fi

	# gcc 4.2 has buggy ivopts
	if [[ $(gcc-version) = "4.2" ]]; then
		append-flags -fno-ivopts
	fi

	# recommended by upstream
	append-flags -ffast-math
}

src_prepare() {
	cd "${S}"

	# FreeBSD 6.* doesn't have posix_memalign().
	[[ ${CHOST} == *-freebsd6.* ]] && sed -i -e "s/-DHAVE_POSIX_MEMALIGN//" configure.ac

	# Don't compile debug code with USE=-debug - bug #125004
	if ! use debug; then
	   einfo "Removing DO_DEBUG defs in dri drivers..."
	   find src/mesa/drivers/dri -name *.[hc] -exec egrep -l "\#define\W+DO_DEBUG\W+1" {} \; | xargs sed -i -re "s/\#define\W+DO_DEBUG\W+1/\#define DO_DEBUG 0/" ;
	fi

	# remove unused cpu features
	local i
	for i in mmx sse 3dnow; do
		use ${i} || sed -i -e s/-DUSE_${i}_ASM//i "${S}"/configure*
	done

#	use gallium && sed -i -e 's:GALLIUM_WINSYS_DIRS="":GALLIUM_WINSYS_DIRS="xlib":g' configure.ac

	eautoreconf
}

src_configure() {
	local myconf altconf=""
	local drv="dri"
	local targets=""
	# Configurable DRI drivers
	driver_enable swrast
	driver_enable video_cards_mach64 mach64
	driver_enable video_cards_mga mga
	driver_enable video_cards_r128 r128
	driver_enable video_cards_radeonhd radeon r200 r300 r600
	driver_enable video_cards_s3virge s3v
	driver_enable video_cards_savage savage
	driver_enable video_cards_sis sis
	driver_enable video_cards_sunffb ffb
	driver_enable video_cards_tdfx tdfx
	driver_enable video_cards_trident trident
	driver_enable video_cards_via unichrome
	if use gallium || use llvm || use video_cards_vmware || use video_cards_nouveau; then
		use myconf="--enable-gallium --enable-gallium-swrast"
	fi
	if use gallium; then
		driver_enable video_cards_intel i810
		myconf="${myconf} $(use_enable video_cards_intel gallium-i915)"
		myconf="${myconf} $(use_enable video_cards_intel gallium-i965)"
		myconf="${myconf} $(use_enable video_cards_radeon gallium-radeon)"
		myconf="${myconf} $(use_enable video_cards_radeon gallium-r600)"
		myconf="${myconf} --with-state-trackers=dri,egl,glx,xorg,vega$(use d3d && echo ",d3d1x")"
		ewarn "This gallium configuration required 'xorg-server' headers installed."
		ewarn "To avoid circular dependences install mesa without gallium before and re-emerge after."
	else
		driver_enable video_cards_radeon radeon r200 r300 r600
		driver_enable video_cards_intel i810 i915 i965
		myconf="${myconf} --disable-gallium-intel --disable-gallium-i915 --disable-gallium-i965 --disable-gallium-radeon --disable-gallium-r600 --with-state-trackers=dri,egl,glx"
	fi
	# unique gallium features: gallium will be locally enabled
	myconf="${myconf} $(use_enable video_cards_vmware gallium-svga)"
	myconf="${myconf} $(use_enable video_cards_nouveau gallium-nouveau)"
	myconf="${myconf} $(use_enable llvm gallium-llvm)"
	# Deactivate assembly code for pic build
	( use pic ) && myconf="${myconf} --disable-asm"
	# Get rid of glut includes
	use glut || rm -f "${S}"/include/GL/glut*h
	[[ "${drv}" == "dri" ]] && myconf="${myconf} --with-dri-drivers=${DRI_DRIVERS#,}"
	# dirty
	use osmesa && myconf="${myconf} --enable-gl-osmesa"
	use xlib && targets="${targets} libgl-xlib"
	[[ -n "${targets}" ]]  && sed -i -e 's:GALLIUM_TARGET_DIRS="":GALLIUM_TARGET_DIRS="'"${targets}"'":g' configure{,.ac}
	if use xlib || use osmesa; then
		sed -i -e 's%DRIVER_DIRS="dri"%DRIVER_DIRS="x11 dri"%g' configure{,.ac}
	fi
	econf ${myconf} \
		$(use_enable nptl glx-tls) \
		--with-driver=${drv} \
		$(use_enable glut) \
		$(use_enable xcb) \
		$(use_enable motif glw) \
		$(use_enable motif) \
		$(use_enable gles gles1) \
		$(use_enable gles gles2) \
		$(use_enable gles gles-overlay) \
		$(use_enable dricore shared-dricore) \
		$(use_enable selinux) \
		$(use_enable 32bit 32bit) \
		$(use_enable 64bit 64bit) \
		$(use_with X x) \
		--with-egl-platforms=x11,drm$(use fbdev && echo ,fbdev) \
		|| die
}

src_install() {
	dodir /usr
	emake \
		DESTDIR="${D}" \
		install || die "Installation failed"

	if ! use motif; then
		rm "${D}"/usr/include/GL/GLwMDrawA.h
	fi

	# Don't install private headers
	rm -f "${D}"/usr/include/GL/GLw*P.h

	fix_opengl_symlinks
	dynamic_libgl_install

	# Install libtool archives
	insinto /usr/$(get_libdir)
	# (#67729) Needs to be lib, not $(get_libdir)
	doins "${FILESDIR}"/lib/libGLU.la
	sed -e "s:\${libdir}:$(get_libdir):g" "${FILESDIR}"/lib/libGL.la \
		> "${D}"/usr/$(get_libdir)/opengl/xorg-x11/lib/libGL.la

	# On *BSD libcs dlopen() and similar functions are present directly in
	# libc.so and does not require linking to libdl. portability eclass takes
	# care of finding the needed library (if needed) witht the dlopen_lib
	# function.
	sed -i -e 's:-ldl:'$(dlopen_lib)':g' \
		"${D}"/usr/$(get_libdir)/libGLU.la \
		"${D}"/usr/$(get_libdir)/opengl/xorg-x11/lib/libGL.la

	# libGLU doesn't get the plain .so symlink either
	#dosym libGLU.so.1 /usr/$(get_libdir)/libGLU.so

	local i d
	d="/usr/$(get_libdir)/opengl/xorg-x11-xlib"
	for i in "${D}"/usr/$(get_libdir)/opengl/xorg-x11/lib/libGL.so.1.5*; do
		[[ -e "${i}" ]] || continue
		if ! [[ -d "${D}${d}"/lib ]]; then
			if eselect opengl list|grep -q "xorg-x11-xlib"; then
				OPENGL_DIR=`eselect opengl show`
			else
				OPENGL_DIR=xorg-x11-xlib
			fi
			export OPENGL_DIR
			dodir "${d}"/lib || die
			dosym ../xorg-x11/extensions "${d}"/extensions
			dosym ../xorg-x11/include "${d}"/include
			ewarn "You selected 'xlib' and|or 'osmesa' flag. Installing multiple 'libGL.so.*'"
			ewarn "into /usr/lib/opengl/*/lib/ and symlinks to it."
			ewarn "To use 'dri' (hardware) lib - say 'eselect opengl set xorg-x11'"
			ewarn "To use 'xlib/OSmesa' (software) - 'eselect opengl set xorg-x11-xlib'"
			ewarn "xlib/OSmesa library must emulate compiz-related texture calls anyware."
		fi
		mv "${i}" "${D}${d}"/lib
	done
}

pkg_postinst() {
		echo
		eselect opengl set --use-old ${OPENGL_DIR:-xorg-x11}
}

fix_opengl_symlinks() {
	# Remove invalid symlinks
	local LINK
	for LINK in $(find "${D}"/usr/$(get_libdir) \
		-name libGL\.* -type l); do
		rm -f ${LINK}
	done
	# Create required symlinks
	if [[ ${CHOST} == *-freebsd* ]]; then
		# FreeBSD doesn't use major.minor versioning, so the library is only
		# libGL.so.1 and no libGL.so.1.2 is ever used there, thus only create
		# libGL.so symlink and leave libGL.so.1 being the real thing
		dosym libGL.so.1 /usr/$(get_libdir)/libGL.so
	else
		dosym libGL.so.1.2 /usr/$(get_libdir)/libGL.so
		dosym libGL.so.1.2 /usr/$(get_libdir)/libGL.so.1
	fi
}

dynamic_libgl_install() {
	# next section is to setup the dynamic libGL stuff
	ebegin "Moving libGL and friends for dynamic switching"
		dodir /usr/$(get_libdir)/opengl/${OPENGL_DIR}/{lib,extensions,include}
		local x=""
		for x in "${D}"/usr/$(get_libdir)/libGL.so* \
			"${D}"/usr/$(get_libdir)/libGL.la \
			"${D}"/usr/$(get_libdir)/libGL.a; do
			if [ -f ${x} -o -L ${x} ]; then
				# libGL.a cause problems with tuxracer, etc
				mv -f ${x} "${D}"/usr/$(get_libdir)/opengl/${OPENGL_DIR}/lib
			fi
		done
		# glext.h added for #54984
		for x in "${D}"/usr/include/GL/{gl.h,glx.h,glext.h,glxext.h}; do
			if [ -f ${x} -o -L ${x} ]; then
				mv -f ${x} "${D}"/usr/$(get_libdir)/opengl/${OPENGL_DIR}/include
			fi
		done
	eend 0
}

# $1 - VIDEO_CARDS flag
# other args - names of DRI drivers to enable
driver_enable() {
	case $# in
		# for enabling unconditionally
		1)
			DRI_DRIVERS="${DRI_DRIVERS},$1"
			;;
		*)
			if use $1; then
				shift
				for i in $@; do
					DRI_DRIVERS="${DRI_DRIVERS},${i}"
				done
			fi
			;;
	esac
}
