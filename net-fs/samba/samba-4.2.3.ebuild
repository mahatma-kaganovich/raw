# Copyright 1999-2015 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/net-fs/samba/samba-4.2.0.ebuild,v 1.1 2015/03/08 13:21:55 polynomial-c Exp $

EAPI=5
PYTHON_COMPAT=( python2_7 )
PYTHON_REQ_USE='threads(+)'

inherit python-single-r1 waf-utils multilib linux-info systemd

MY_PV="${PV/_rc/rc}"
MY_P="${PN}-${MY_PV}"

SRC_PATH="stable"
[[ ${PV} = *_rc* ]] && SRC_PATH="rc"

SRC_URI="mirror://samba/${SRC_PATH}/${MY_P}.tar.gz"
KEYWORDS="~amd64 ~hppa ~x86"
[[ ${PV} = *_rc* ]] && KEYWORDS=""

DESCRIPTION="Samba Suite Version 4"
HOMEPAGE="http://www.samba.org/"
LICENSE="GPL-3"

SLOT="0"

IUSE="acl addns ads aio avahi client cluster cups dmapi fam gnutls iprint
ldap quota selinux syslog systemd test winbind afs minimal hardened pam sasl"

# useflag sasl control only cyrus-sasl linking, not own sasl wrapper

# sys-apps/attr is an automagic dependency (see bug #489748)
CDEPEND="${PYTHON_DEPS}
	virtual/krb5
	!<app-crypt/heimdal-1.5
	!app-crypt/heimdal[ssl]
	dev-libs/iniparser
	dev-libs/popt
	sys-libs/readline:=
	virtual/libiconv
	dev-python/subunit[${PYTHON_USEDEP}]
	>=net-libs/socket_wrapper-1.1.2
	sys-apps/attr
	sys-libs/libcap
	>=sys-libs/ldb-1.1.20
	>=sys-libs/nss_wrapper-1.0.2
	>=sys-libs/ntdb-1.0[python,${PYTHON_USEDEP}]
	>=sys-libs/talloc-2.1.1[python,${PYTHON_USEDEP}]
	>=sys-libs/tdb-1.3.6[python,${PYTHON_USEDEP}]
	>=sys-libs/tevent-0.9.25
	>=sys-libs/uid_wrapper-1.0.1
	sys-libs/zlib
	pam? ( virtual/pam )
	acl? ( virtual/acl )
	addns? ( net-dns/bind-tools[gssapi] )
	aio? ( dev-libs/libaio )
	cluster? ( !dev-db/ctdb )
	cups? ( net-print/cups )
	dmapi? ( sys-apps/dmapi )
	fam? ( virtual/fam )
	gnutls? ( dev-libs/libgcrypt:0
		>=net-libs/gnutls-1.4.0 )
	ldap? ( net-nds/openldap )
	afs? ( net-fs/openafs )
	sasl? ( dev-libs/cyrus-sasl )
	systemd? ( sys-apps/systemd:0= )"
DEPEND="${CDEPEND}
	virtual/pkgconfig"
RDEPEND="${CDEPEND}
	client? ( net-fs/cifs-utils[ads?] )
	selinux? ( sec-policy/selinux-samba )
"

REQUIRED_USE="ads? ( acl ldap )
	${PYTHON_REQUIRED_USE}"

RESTRICT="mirror"

S="${WORKDIR}/${MY_P}"

CONFDIR="${FILESDIR}/$(get_version_component_range 1-2)"

WAF_BINARY="${S}/buildtools/bin/waf"

pkg_setup() {
	python-single-r1_pkg_setup
	if use aio; then
		if ! linux_config_exists || ! linux_chkconfig_present AIO; then
				ewarn "You must enable AIO support in your kernel config, "
				ewarn "to be able to support asynchronous I/O. "
				ewarn "You can find it at"
				ewarn
				ewarn "General Support"
				ewarn " Enable AIO support "
				ewarn
				ewarn "and recompile your kernel..."
		fi
	fi
}

src_prepare(){
	cd "${S}" || die
	has_version app-crypt/heimdal && sed -i -e 's:USING_SYSTEM_KDC:USING_SYSTEM_KDC_:' source4/kdc/wscript_build
	use sasl || sed -i -e 's:HAVE_SASL:HAVE_SASL_:' source4/auth/wscript_configure
	sed -i -e 's:/tmp/ctdb.socket:/var/run/ctdb/ctdb.socket:g' {ctdb/doc,docs-xml/smbdotconf/misc}/*ml
}

automagic(){
	local i
	for i in "${@}"; do
		egrep "#define.*$i.*" "${S}"/bin/default/include/config.h
		sed -i -e "/#define.*$i.*/d" "${S}"/bin/default/include/config.h
	done
}

src_configure() {
	local myconf=''
	use "test" && myconf+=" --enable-selftest"
	has_version app-crypt/mit-krb5 && myconf+=" --with-system-mitkrb5"
	if use minimal; then
		ewarn "Selected minimal build may be failed, disabling AD DC"
		myconf+=" --without-ad-dc --without-libarchive"
		use !hardened && myconf+=" --without-pie" && ewarn "  & PIE"
	fi
	myconf="${myconf} \
		--enable-fhs \
		--sysconfdir=/etc \
		--localstatedir=/var \
		--with-modulesdir=/usr/$(get_libdir)/samba \
		--with-pammodulesdir=/$(get_libdir)/security \
		--with-piddir=/var/run/${PN} \
		--disable-rpath \
		--disable-rpath-install \
		--nopyc \
		--nopyo \
		--bundled-libraries=NONE \
		--builtin-libraries=NONE \
		$(use_with addns dnsupdate) \
		$(use_with acl acl-support) \
		$(use_with ads) \
		$(use_with aio aio-support) \
		$(use_enable avahi) \
		$(use_with cluster cluster-support) \
		$(use_enable cups) \
		$(use_with dmapi) \
		$(use_with fam) \
		$(use_enable gnutls) \
		$(use_enable iprint) \
		$(use_with ldap) \
		$(use_with pam) \
		$(use_with pam pam_smbpass) \
		$(use_with quota quotas) \
		$(use_with syslog) \
		$(use_with systemd) \
		$(use_with afs fake-kaserver) \
		$(use_with winbind)
		"
	use "ads" && myconf+=" --with-shared-modules=idmap_ad"

	CPPFLAGS="-I/usr/include/et ${CPPFLAGS}" \
		waf-utils_src_configure ${myconf}

	einfo "Removing automagic definitions"
	# KDC wrong here
	use pam || automagic _PAM_ '_LIBPAM '
#	use sasl || automagic SASL

}

src_install() {
	waf-utils_src_install

	# install ldap schema for server (bug #491002)
	if use ldap ; then
		insinto /etc/openldap/schema
		doins examples/LDAP/samba.schema
	fi

	# Make all .so files executable
	find "${D}" -type f -name "*.so" -exec chmod +x {} +

	# Install init script and conf.d file
	newinitd "${CONFDIR}/samba4.initd-r1" samba
	newconfd "${CONFDIR}/samba4.confd" samba

	if use cluster; then
		newinitd "${CONFDIR}/ctdb.initd" ctdb
		newconfd "${CONFDIR}/ctdb.confd" ctdb
	fi

	systemd_dotmpfilesd "${FILESDIR}"/samba.conf
	systemd_dounit "${FILESDIR}"/nmbd.service
	systemd_dounit "${FILESDIR}"/smbd.{service,socket}
	systemd_newunit "${FILESDIR}"/smbd_at.service 'smbd@.service'
	systemd_dounit "${FILESDIR}"/winbindd.service
	systemd_dounit "${FILESDIR}"/samba.service
}

src_test() {
	"${WAF_BINARY}" test || die "test failed"
}

pkg_postinst() {
	ewarn "Be aware the this release contains the best of all of Samba's"
	ewarn "technology parts, both a file server (that you can reasonably expect"
	ewarn "to upgrade existing Samba 3.x releases to) and the AD domain"
	ewarn "controller work previously known as 'samba4'."

	elog "For further information and migration steps make sure to read "
	elog "http://samba.org/samba/history/${P}.html "
	elog "http://samba.org/samba/history/${PN}-4.0.0.html and"
	elog "http://wiki.samba.org/index.php/Samba4/HOWTO "
}
