EAPI=5
SLOT=0
USE_RUBY="ruby18 ruby19"
[[ "$PV" == *999 ]] && unp="git-2" || unp="rpm"
inherit flag-o-matic $unp ruby-fakegem versionator
LICENSE="GPL-2"
DESCRIPTION="HA Web Konsole (Hawk). A web-based GUI for managing and monitoring Pacemaker HA clusters."
HOMEPAGE="http://clusterlabs.org/wiki/Hawk"

KEYWORDS=""
case "$PV" in
9999)
	EGIT_REPO_URI="git://github.com/ClusterLabs/hawk.git https://github.com/ClusterLabs/hawk.git"
	SRC_URI=""
;;
0.6.1)
	KEYWORDS="~amd64" # relative stable URL
	SRC_URI="http://download.opensuse.org/source/distribution/13.1/repo/oss/suse/src/hawk-0.6.1+git.1376993239.ab692f7-2.1.5.src.rpm"
;;
0.7.0)
	SRC_URI="http://download.opensuse.org/source/factory-snapshot/repo/oss/suse/src/hawk-0.7.0+git.1393841819.910a788-1.1.src.rpm"
;;
esac

KEYWORDS="~amd64"
IUSE="fcgi"
DEPEND="sys-cluster/pacemaker
	sys-cluster/crmsh
	sys-libs/pam
	dev-libs/glib
	dev-libs/libxml2
	www-servers/lighttpd
	fcgi? ( dev-ruby/fcgi app-misc/fdupes )
"
#	<dev-ruby/rails-3.3
RDEPEND="${DEPEND}"

ruby_add_bdepend "
	dev-ruby/activeresource
	virtual/rubygems
	dev-ruby/bundler
"

# dev-ruby/gettext_i18n_rails-0.10.0 incompatible with 
ruby_add_rdepend "
	|| (
		>=dev-ruby/gettext_i18n_rails-1.0.5
		(
			<dev-ruby/locale-2.1.0
			<dev-ruby/ruby-gettext-3.0
		)
	)
	dev-ruby/ruby-gettext
	dev-ruby/railties
	>=dev-ruby/rails-3.2
	dev-ruby/fast_gettext
	dev-ruby/gettext_i18n_rails
	virtual/ruby-threads
"
#	<dev-ruby/tzinfo-1.0

#base="/srv/www"
base="/usr/lib/hawk"

all_ruby_unpack() {
	${unp}_src_unpack
	[ -d "$S" ] || mv "${S}"* "$S" || die
}

all_ruby_prepare() {
	append-flags ${LDFLAGS}
	export RAILS_ENV=production
	local c="${S}/scripts/${PN}.gentoo.in"
	[ -e "$c" ] || cp "${FILESDIR}/${PN}.gentoo.in" "$c" || die
	if has_version '>=dev-ruby/rails-4.0.0'; then
		sed -i -e "s:gem 'rails', '~> 3\.2':gem 'rails', '>= 3.2'\ngem 'activeresource', '>= 4.0.0':" "${S}"/hawk/Gemfile
		sed -i -e 's%^\( *match .*\)$%\1, :via => [:get]%' "$S/hawk/config/routes.rb"
	fi
}

_make(){
	emake WWW_BASE="${base}" INIT_STYLE=gentoo DESTDIR="${D}" "${@}" || die
}

each_ruby_compile() {
	_make
}

each_ruby_install() {
	rm -f "${D}${base}/${PN}"/public/monitor
	_make install
#	use fcgi || rm "${D}"/srv/www/hawk/config/lighttpd.conf
}

each_ruby_test() {
	_make test
}

