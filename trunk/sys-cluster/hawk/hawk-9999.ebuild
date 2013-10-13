EAPI=5
SLOT=0
USE_RUBY="ruby18 ruby19"
[[ "$PV" == *999 ]] && unp="git-2" || unp="rpm"
inherit flag-o-matic $unp ruby-fakegem
LICENSE="GPL-2"
DESCRIPTION="HA Web Konsole (Hawk). A web-based GUI for managing and monitoring Pacemaker HA clusters."
HOMEPAGE="http://clusterlabs.org/wiki/Hawk"
if [[ "$PV" == *999 ]]; then
	EGIT_REPO_URI="git://github.com/ClusterLabs/hawk.git https://github.com/ClusterLabs/hawk.git"
	SRC_URI=""
else
#	SRC_URI="http://download.opensuse.org/source/distribution/12.3/repo/oss/suse/src/hawk-0.5.2-7.2.1.src.rpm"
	SRC_URI="http://download.opensuse.org/source/factory-snapshot/repo/oss/suse/src/hawk-0.6.1+git.1376993239.ab692f7-1.1.src.rpm"
fi
KEYWORDS="~amd64"
IUSE="fcgi"
DEPEND="sys-cluster/pacemaker
	sys-cluster/crmsh
	sys-libs/pam
	dev-lang/ruby
	virtual/rubygems
	dev-ruby/bundler
	>=dev-ruby/rails-3.2
	dev-ruby/fast_gettext
	dev-ruby/gettext_i18n_rails
	dev-ruby/ruby-gettext
	<dev-ruby/tzinfo-1.0
	dev-libs/glib
	dev-libs/libxml2
	www-servers/lighttpd
	fcgi? ( dev-ruby/fcgi app-misc/fdupes )
"
#	<dev-ruby/rails-3.3
RDEPEND="${DEPEND}"

#base="/srv/www"
base="/usr/lib/hawk"

all_ruby_unpack() {
	${unp}_src_unpack
	[ -d "$S" ] || mv "${S}"* "$S" || die
}

all_ruby_prepare() {
	append-flags ${LDFLAGS}
	local c="${S}/scripts/${PN}.gentoo.in"
	[ -e "$c" ] || cp "${FILESDIR}/${PN}.gentoo.in" "$c" || die
	# 4.0 looks working too
	sed -i -e "s:gem 'rails', '\~\> 3.2':gem 'rails', '>= 3.2':" "${S}"/Gemfile
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

