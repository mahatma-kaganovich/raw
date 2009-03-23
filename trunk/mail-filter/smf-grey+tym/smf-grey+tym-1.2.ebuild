MY_P="smf-grey-2.0.0+tym1.2"
MY_PN="smf-grey"
DIRS="/var/run/smfs /var/${MY_PN}"
inherit smf
DESCRIPTION="Sendmail GreyList milter, extended version"
HOMEPAGE="http://smfs.takm.com/"
SRC_URI="http://smfs.takm.com/smf-grey-2.0.0%2Btym1.2.tar.gz"
DEPEND="!mail-filter/smf-grey"