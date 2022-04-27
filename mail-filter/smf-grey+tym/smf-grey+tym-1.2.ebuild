EAPI=6
MY_P="smf-grey-2.0.0+tym${PV}"
MY_PN="smf-grey"
DIRS="/var/run/smfs /var/${MY_PN} /var/spool/smfs"
inherit smf
DESCRIPTION="Sendmail GreyList milter, extended version"
HOMEPAGE="http://smfs.takm.com/"
SRC_URI="http://smfs.takm.com/smf-grey-2.0.0%2Btym${PV}.tar.gz"
DEPEND="!mail-filter/smf-grey"