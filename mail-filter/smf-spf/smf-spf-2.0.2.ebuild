EAPI=7
inherit smf
DESCRIPTION="Sendmail SPF milter"
DEPEND="${DEPEND}
	mail-filter/libspf2"