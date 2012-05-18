EAPI="4"
GIT=$([[ ${PVR} = *9999* ]] && echo "git-2")
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
LICENSE="MIT LGPL-3 SGI-B-2.0"
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
	+nptl
	xcb
	kernel_FreeBSD
	+gallium
	glut
	xlib
	osmesa
	llvm
	X
	+fbdev
	gles1
	gles2
	+dricore
	selinux
	+egl
	gbm
	g3dvl
	vdpau
	xa
	xvmc
	wayland
	openvg
	d3d"

REQUIRED_USE="
	g3dvl?  ( gallium )
	g3dvl? ( || ( vdpau xvmc ) )
	vdpau? ( g3dvl )
	xvmc?  ( g3dvl )
	xa? ( gallium )
	gbm? ( dricore )
	openvg? ( egl gallium )
	"

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
	vdpau? ( >=x11-libs/libvdpau-0.4.1 )
	wayland? ( dev-libs/wayland )
	xvmc? ( x11-libs/libXvMC )
	gbm? ( sys-fs/udev )
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
	sed -i -e '/GALLIUM_DRIVERS_DIRS i915 i965 r300 svga/d' -e '/GALLIUM_WINSYS_DIRS i915\/sw/d' "${S}"/configure*
	sed -i -e 's:^\(#include "fbdev\):#include <errno.h>\n\1:' src/gallium/state_trackers/egl/fbdev/native_fbdev.c

	eautoreconf
}

cfg2(){
	[[ -n "$1" ]] && sed -i -e "s:^$2=\":$2=\"$1 :g" configure{,.ac}
}

src_configure() {
	local myconf altconf="" ga=""
	local drv="dri"
	local targets="" trackers=""
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
	if [[ -e src/mesa/drivers/dri/openchrome ]]; then
		driver_enable video_cards_via openchrome
	else
		driver_enable video_cards_via unichrome
	fi
	if use gallium; then
		driver_enable video_cards_intel i810
		use video_cards_intel && ga+=" i915 i965"
		use video_cards_radeon && {
			ga+=" radeon r600"
			use llvm && ga+=" r300"
		}
		ewarn "This gallium configuration required 'xorg-server' headers installed."
		ewarn "To avoid circular dependences install mesa without gallium before and re-emerge after."
		use X && myconf+=" --enable-xorg"
		myconf+=" --enable-gallium-egl $(use_enable openvg)"
	else
		driver_enable video_cards_radeon radeon r200 r300 r600
		driver_enable video_cards_intel i810 i915 i965
	fi
	# unique gallium features: gallium will be locally enabled
	use video_cards_nouveau && ga+=" nouveau"
	use vmware && ga+=" svga"
	myconf+=" $(use_enable llvm gallium-llvm)"
	# Deactivate assembly code for pic build
	( use pic ) && myconf+=" --disable-asm"
	# Get rid of glut includes
	use glut || rm -f "${S}"/include/GL/glut*h
	[[ "${drv}" == "dri" ]] && myconf+=" --with-dri-drivers=${DRI_DRIVERS#,}"
	# dirty
	use osmesa && myconf+=" --enable-gl-osmesa"
	use xlib && targets+=" libgl-xlib" && trackers+=" glx"
	cfg2 "$targets" GALLIUM_TARGET_DIRS
	cfg2 "$trackers" GALLIUM_STATE_TRACKERS_DIRS
	if use xlib || use osmesa; then
		sed -i -e 's%DRIVER_DIRS="dri"%DRIVER_DIRS="x11 dri"%g' configure{,.ac}
	fi
	myconf+=" --with-gallium-drivers="
	if use gallium || [[ -n "$ga" ]]; then
		ga+=" swrast"
	fi
	for i in $ga; do
		grep -q '^\s*x'"$i)" configure && myconf+="$i,"
	done
	econf ${myconf%,} \
		$(use_enable !bindist texture-float) \
		$(use_enable egl) \
		$(use_enable gbm) \
		$(use_enable g3dvl gallium-g3dvl) \
		$(use_enable vdpau) \
		$(use_enable xvmc) \
		--enable-dri \
		--enable-glx \
		$(use_enable nptl glx-tls) \
		$(use_enable glut) \
		$(use_enable xcb) \
		$(use_enable motif glw) \
		$(use_enable motif) \
		$(use_enable gles1 gles1) \
		$(use_enable gles2 gles2) \
		$(use_enable dricore shared-dricore) \
		$(use_enable dricore shared-glapi) \
		$(use_enable selinux) \
		$(use_with X x) \
		$(use_enable xa) \
		$(use_enable d3d d3d1x) \
		--with-egl-platforms=x11,drm$(use fbdev && echo ,fbdev)$(use wayland && echo ,wayland) \
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

	local i d l="/usr/$(get_libdir)/opengl"
	d="$l/xorg-x11-xlib"
	[[ -e "$D/$d" ]] || for i in "$D/$l"/xorg-x11/lib/libGL.so.1.5* $(get_libdir)/gallium/libGL.so.1.5*; do
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
			ewarn "into $l/*/lib/ and symlinks to it."
			ewarn "To use 'dri' (hardware) lib - say 'eselect opengl set xorg-x11'"
			ewarn "To use 'xlib/OSmesa' (software) - 'eselect opengl set xorg-x11-xlib'"
			ewarn "xlib/OSmesa library must emulate compiz-related texture calls anyware."
		fi
		mv "${i}" "${D}${d}"/lib
		break
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
		local l='' i j
		for i in /usr/$(get_libdir)/libGL.so{.1.2,.1,}; do
			[[ -z "$l" ]] && for j in "$D$i".*; do
				[ -e "$j" ] || continue
				[ -e "$D$i" -a ! -L "$D$i" -a ! -L "$l" ]  && cmp -s "$D$i" "$j" && rm "$D$i"
				l="${j##*/}"
				break
			done
			[[ -n "$l" ]] && ! [[ -e "$D$i" ]] && dosym "$l" "$i"
		done
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
