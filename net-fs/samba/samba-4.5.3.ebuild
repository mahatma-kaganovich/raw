# Copyright 1999-2015 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/net-fs/samba/samba-4.2.0.ebuild,v 1.1 2015/03/08 13:21:55 polynomial-c Exp $

EAPI=6
PYTHON_COMPAT=( python2_7 )
PYTHON_REQ_USE='threads(+),xml(+)'

inherit python-single-r1 waf-utils multilib-minimal linux-info systemd eutils

MY_PV="${PV/_rc/rc}"
MY_P="${PN}-${MY_PV}"

SRC_PATH="stable"
[[ ${PV} = *_rc* ]] && SRC_PATH="rc"

SRC_URI="mirror://samba/${SRC_PATH}/${MY_P}.tar.gz
	https://dev.gentoo.org/~polynomial-c/samba-disable-python-patches-4.5.0_rc1.tar.xz"
KEYWORDS="~amd64 ~hppa ~x86"
[[ ${PV} = *_rc* ]] && KEYWORDS="~hppa"

DESCRIPTION="Samba Suite Version 4"
HOMEPAGE="http://www.samba.org/"
LICENSE="GPL-3"

SLOT="0"

IUSE="acl addc addns ads avahi client cluster cups dmapi fam gnutls iprint
ldap pam quota selinux syslog systemd test winbind afs sasl gpg"

MULTILIB_WRAPPED_HEADERS=(
	/usr/include/samba-4.0/policy.h
	/usr/include/samba-4.0/dcerpc_server.h
)

# useflag sasl control only cyrus-sasl linking, not own sasl wrapper

# sys-apps/attr is an automagic dependency (see bug #489748)
# libaio probably not required more. 2check
CDEPEND="${PYTHON_DEPS}
	>=app-arch/libarchive-3.1.2[${MULTILIB_USEDEP}]
	dev-lang/perl:=
	dev-libs/libaio[${MULTILIB_USEDEP}]
	dev-libs/libbsd[${MULTILIB_USEDEP}]
	dev-libs/iniparser:0
	dev-libs/popt[${MULTILIB_USEDEP}]
	sys-libs/readline:=
	virtual/libiconv
	dev-python/subunit[${PYTHON_USEDEP},${MULTILIB_USEDEP}]
	sys-apps/attr[${MULTILIB_USEDEP}]
	sys-libs/libcap
	>=sys-libs/ldb-1.1.27[ldap(+)?,${MULTILIB_USEDEP}]
	sys-libs/ncurses:0=[${MULTILIB_USEDEP}]
	>=sys-libs/talloc-2.1.8[python,${PYTHON_USEDEP},${MULTILIB_USEDEP}]
	>=sys-libs/tdb-1.3.10[python,${PYTHON_USEDEP},${MULTILIB_USEDEP}]
	>=sys-libs/tevent-0.9.31-r1[${MULTILIB_USEDEP}]
	sys-libs/zlib[${MULTILIB_USEDEP}]
	pam? ( virtual/pam )
	acl? ( virtual/acl )
	addns? ( net-dns/bind-tools[gssapi] )
	cluster? ( !dev-db/ctdb )
	cups? ( net-print/cups )
	dmapi? ( sys-apps/dmapi )
	fam? ( virtual/fam )
	gnutls? ( dev-libs/libgcrypt:0
		>=net-libs/gnutls-1.4.0 )
	ldap? ( net-nds/openldap[${MULTILIB_USEDEP}] )
	afs? ( net-fs/openafs )
	sasl? ( dev-libs/cyrus-sasl )
	!addc? ( || (
		app-crypt/mit-krb5[${MULTILIB_USEDEP}]
		>=app-crypt/heimdal-1.5[-ssl,${MULTILIB_USEDEP}]
	) )
	gpg? ( app-crypt/gpgme )
	systemd? ( sys-apps/systemd:0= )"
DEPEND="${CDEPEND}
	virtual/pkgconfig"
RDEPEND="${CDEPEND}
	client? ( net-fs/cifs-utils[ads?] )
	selinux? ( sec-policy/selinux-samba )
"

REQUIRED_USE="addc? ( gnutls )
	ads? ( acl gnutls ldap )
	gpg? ( addc )
	${PYTHON_REQUIRED_USE}"

S="${WORKDIR}/${MY_P}"

#PATCHES=(
#	"${FILESDIR}/${PN}-4.2.3-ctdb.patch"
#	)

#CONFDIR="${FILESDIR}/$(get_version_component_range 1-2)"
CONFDIR="${FILESDIR}/4.4"

WAF_BINARY="${S}/buildtools/bin/waf"

SHAREDMODS=""

pkg_setup() {
	python-single-r1_pkg_setup
	if use cluster ; then
		SHAREDMODS="${SHAREDMODS}idmap_rid,idmap_tdb2,idmap_ad"
	fi
}

src_prepare() {
	default

	use sasl || sed -i -e 's:HAVE_SASL:HAVE_SASL_:' source4/auth/wscript_configure
	sed -i -e 's:/tmp/ctdb.socket:/run/ctdb/ctdb.socket:g' {ctdb/doc,docs-xml/smbdotconf/misc}/*ml
	sed -i -e 's:<gpgme.h>:<gpgme/gpgme.h>:' source4/dsdb/samdb/ldb_modules/password_hash.c

	# install the patches from tarball(s)
	eapply "${WORKDIR}/patches/"

	# ugly hackaround for bug #592502
	cp /usr/include/tevent_internal.h "${S}"/lib/tevent/ || die

	multilib_copy_sources
}

automagic(){
	local i
	for i in "${@}"; do
		egrep "#define.*$i.*" "${S}"/bin/default/include/config.h
		sed -i -e "/#define.*$i.*/d" "${S}"/bin/default/include/config.h
	done
}

multilib_src_configure() {
	local myconf=()
	myconf=(
		--enable-fhs
		--sysconfdir=/etc
		--localstatedir=/var
		--with-modulesdir=/usr/$(get_libdir)/samba
		--with-piddir=/run/${PN}
		--bundled-libraries=$(usex addc heimdal NONE)
		--builtin-libraries=NONE
		--disable-rpath
		--disable-rpath-install
		--nopyc
		--nopyo
		 --without-ntvfs-fileserver
	)
	if multilib_is_native_abi ; then

		myconf+=(
			$(use_with acl acl-support)
			$(usex addc '' '--without-ad-dc')
			$(use_with addns dnsupdate)
			$(use_with ads)
			$(usex ads '--with-shared-modules=idmap_ad' '')
			$(use_enable avahi)
			$(use_with cluster cluster-support)
			$(use_enable cups)
			$(use_with dmapi)
			$(use_with fam)
			$(use_enable gnutls)
			$(use_enable iprint)
			$(use_with ldap)
			$(use_with pam)
			$(usex pam "--with-pammodulesdir=/$(get_libdir)/security" '')
			$(use_with quota quotas)
			$(use_with syslog)
			$(use_with systemd)
			$(use_with afs fake-kaserver)
			$(use !addc && has_version app-crypt/mit-krb5 && echo --with-system-mitkrb5)
			$(use_with winbind)
			$(use_with gpg gpgme)
			$(usex test '--enable-selftest' '')
			--with-shared-modules=${SHAREDMODS}
		)  #'"
	else
		myconf+=(
			--without-acl-support
			--without-ad-dc
			--without-dnsupdate
			--without-ads
			--disable-avahi
			$(use_with cluster cluster-support)
			--disable-cups
			--without-dmapi
			--without-fam
			--disable-gnutls
			--disable-iprint
			$(use_with ldap)
			--without-pam
			--without-quotas
			--without-syslog
			--without-systemd
			$(use !addc && has_version app-crypt/mit-krb5 && echo --with-system-mitkrb5)
			--without-winbind
			--disable-python
			--without-gpgme
		)
	fi
	CPPFLAGS="-I${SYSROOT}/usr/include/et ${CPPFLAGS}" \
		waf-utils_src_configure ${myconf[@]}

	einfo "Removing automagic definitions"
	# KDC wrong here
	use pam || automagic _PAM_ '_LIBPAM '
	use sasl || automagic SASL

}

multilib_src_install() {
	waf-utils_src_install

	# Make all .so files executable
	find "${D}" -type f -name "*.so" -exec chmod +x {} +

	if multilib_is_native_abi; then
		# install ldap schema for server (bug #491002)
		if use ldap ; then
			insinto /etc/openldap/schema
			doins examples/LDAP/samba.schema
		fi

		# create symlink for cups (bug #552310)
		if use cups ; then
			dosym /usr/bin/smbspool /usr/libexec/cups/backend/smb
		fi

		# install example config file
		insinto /etc/samba
		doins examples/smb.conf.default

		# Install init script and conf.d file
		newinitd "${CONFDIR}/samba4.initd-r1" samba
		newconfd "${CONFDIR}/samba4.confd" samba

		if use cluster; then
			newinitd "${CONFDIR}/ctdb.initd" ctdb
			newconfd "${CONFDIR}/ctdb.confd" ctdb
			exeinto /etc/ctdb/notify.d
			doexe "${CONFDIR}/10.samba"
		fi

		systemd_dotmpfilesd "${FILESDIR}"/samba.conf
		systemd_dounit "${FILESDIR}"/nmbd.service
		systemd_dounit "${FILESDIR}"/smbd.{service,socket}
		systemd_newunit "${FILESDIR}"/smbd_at.service 'smbd@.service'
		systemd_dounit "${FILESDIR}"/winbindd.service
		systemd_dounit "${FILESDIR}"/samba.service
	fi
}

multilib_src_test() {
	if multilib_is_native_abi ; then
		"${WAF_BINARY}" test || die "test failed"
	fi
}

pkg_postinst() {
	ewarn "Be aware the this release contains the best of all of Samba's"
	ewarn "technology parts, both a file server (that you can reasonably expect"
	ewarn "to upgrade existing Samba 3.x releases to) and the AD domain"
	ewarn "controller work previously known as 'samba4'."

	elog "For further information and migration steps make sure to read "
	elog "http://samba.org/samba/history/${P}.html "
	elog "http://samba.org/samba/history/${PN}-4.2.0.html and"
	elog "http://wiki.samba.org/index.php/Samba4/HOWTO "
}
