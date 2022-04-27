EAPI=6
MY_PN="smf-grey"
DIRS="/var/run/smfs /var/${MY_PN} /var/spool/smfs"
inherit smf git-r3
DESCRIPTION="Sendmail GreyList milter, extended cluster version"
HOMEPAGE="https://github.com/mahatma-kaganovich/smf-grey-"
SRC_URI=""
EGIT_REPO_URI="https://github.com/mahatma-kaganovich/smf-grey-.git"
DEPEND="!mail-filter/smf-grey !mail-filter/smf-grey+tym"
