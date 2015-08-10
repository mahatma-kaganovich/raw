 # Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/www-servers/apache/apache-2.2.21-r1.ebuild,v 1.7 2011/10/29 18:46:16 armin76 Exp $

# this 2 lines just for compatibility. all MPMs installing shared and selectable in any time, but you can select "default" one.
# "-D MPM_*" is preferred
EAPI="4"
IUSE_MPMS_FORK="itk prefork"
IUSE_MPMS_THREAD="event worker simple"

# latest gentoo apache files
GENTOO_PATCHSTAMP="20120518"
GENTOO_DEVELOPER=""
# We want the patch from r0
GENTOO_PATCHNAME="gentoo-${P}"

# now for USE=static only
IUSE_MODULES="cache_disk file_cache setenvif cern_meta case_filter expires authn_file unixd optional_hook_export proxy_ftp proxy_fdpass sed asis proxy_fcgi negotiation usertrack dialup dav_lock info proxy_balancer cache dumpio cgid optional_fn_import lbmethod_bytraffic dav_fs ident authz_user data proxy_connect reqtimeout authz_host vhost_alias lbmethod_heartbeat actions authn_anon isapi reflector log_config access_compat session_dbd echo charset_lite authn_dbd mime_magic authn_dbm log_forensic status slotmem_plain heartmonitor ext_filter authn_socache authz_core allowmethods optional_fn_export proxy_html proxy_http optional_hook_import request imagemap authz_owner logio auth_form alias socache_dbm authn_core watchdog auth_digest speling auth_basic autoindex userdir socache_memcache unique_id proxy authz_groupfile bucketeer heartbeat session_cookie authz_dbd authz_dbm xml2enc remoteip rewrite session cgi include dbd dav dir substitute log_debug env proxy_express buffer example_ipc slotmem_shm headers lbmethod_byrequests case_filter_in proxy_ajp socache_shmcb filter ratelimit proxy_scgi version example_hooks lbmethod_bybusyness privileges"

inherit apache-2

moduse="zlib:deflate +mime ldap ldap:authnz_ldap suexec ssl lua lua:luajit distcache:socache_dc serf"

DESCRIPTION="The Apache Web Server."
HOMEPAGE="http://httpd.apache.org/"

# some helper scripts are Apache-1.1, thus both are here
LICENSE="Apache-2.0 Apache-1.1"
SLOT="2"
KEYWORDS=""
IUSE="static"

for i in $moduse; do
	IUSE+=" ${i%%:*}"
done

DEPEND="${DEPEND}
	ssl? ( >=dev-libs/openssl-0.9.8m )
	lua? ( dev-lang/lua )
	distcache? ( net-misc/distcache )
	serf? ( net-libs/serf )
	zlib? ( sys-libs/zlib )"
#	threads? ( dev-libs/apr[-threads] )

# dependency on >=dev-libs/apr-1.4.5 for bug #368651
RDEPEND="${RDEPEND}
	>=dev-libs/apr-1.4.5
	ssl? ( >=dev-libs/openssl-0.9.8m )
	mime? ( app-misc/mime-types )"

S="${WORKDIR}/httpd-${PV}"
SRC_URI="mirror://apache/httpd/httpd-${PV}.tar.bz2
	http://mahatma.bspu.unibel.by/download/gentoo-apache-2.3+/${GENTOO_PATCH_A}"

src_prepare(){
#	cp -a "$FILESDIR" "$GENTOO_PATCHDIR"
	cd "$S"
	for i in "$GENTOO_PATCHDIR"/patches/*.sh{,.*}; do
		[[ -e "$i" ]] && sh "$i"
	done
	apache-2_src_prepare
}

src_configure(){
	use static || ewarn "APACHE2_MODULES variable ignored in this ebuild with -static. Building all shared."
	if use static; then
		MY_CONF=''
		s='=static'
	else
		MY_CONF='--enable-mpms-shared=all'
		s=''
	fi
	# session_crypto - APR does not include SSL/EVP
	for i in cgi cgid isapi watchdog bucketeer echo example_hooks case_filter case_filter_in example_ipc data reflector charset_lite xml2enc proxy_html log_forensic mime_magic cern_meta ident usertrack proxy_fdpass slotmem_plain optional_hook_export optional_hook_import optional_fn_import optional_fn_export dialup heartbeat heartmonitor asis cgi dav_lock imagemap privileges; do
		MY_CONF+=" --enable-$i"
	done
	for i in ${moduse//+}; do
		MY_CONF+=" $(use_enable ${i//:/ })$(use ${i%%:*} && echo "$s")"
	done
	MY_CONF+=' '
	use static && for i in ${IUSE_MODULES//-/_}; do
		use apache2_modules_$i && MY_CONF="${MY_CONF//--enable-$i } --enable-$i=static"
	done
	use threads || {
		ewarn "Threads really moderated by dev-libs/apr -> apr.h -> APR_HAS_THREADS.
	You may get hidden threads use anymore!"
		sed -i -e 's:ac_cv_define_APR_HAS_THREADS=yes:ac_cv_define_APR_HAS_THREADS=no:' configure
		MY_CONF+=" --disable-watchdog --disable-heartbeat"
	}
	apache-2_src_configure
}

src_install(){
	einfo "Default MPM: '$MY_MPM'. You can select any MPM via '-D MPM_*' command line option or 'LoadModule'."
	echo "# 2.2-style default MPM
LoadModule mpm_${MY_MPM}_module modules/mod_mpm_${MY_MPM}.so" >"$TMPDIR/my_mpm.conf"
	insinto /usr/share/apache2
	doins "$TMPDIR/my_mpm.conf"
#	for i in httpd-languages:00_languages httpd-autoindex:00_mod_autoindex; do
#		cp $S/docs/conf/extra/${i//:/ $GENTOO_PATCHDIR/}
#	done
	apache-2_src_install
	sed -i -e 's:^LoadModule \([^ ]*\) \(.*\)$:<IfModule !\1>\nLoadModule \1 \2\n</IfModule>:' "$D/etc/apache2/httpd.conf"
	cd "$S/modules" && tar -caf modules-docs.tar.bz2 $(find -name "docs") && dodoc modules-docs.tar.bz2

#	echo -n "SWITCHABLE MODULES:"
#	cd $S
#	./configure --help |grep -o "\--[^ 	]*" &>l
#	for i in $(find $D -name "mod*.so"); do
#		i=${i#*\mod_}
#		i=${i%.so}
#		i=${i//_/-}
#		grep -q "\--enable-$i\$\|--disable-$i\$" l && echo -n " $i"
#	done
#	echo

	# rm /var/lib/dav/lockdb
}
