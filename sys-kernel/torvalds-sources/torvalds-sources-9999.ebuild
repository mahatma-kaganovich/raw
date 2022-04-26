# Copyright 1999-2013 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/sys-kernel/vanilla-sources/vanilla-sources-3.7.7.ebuild,v 1.1 2013/02/11 22:38:17 ago Exp $

EAPI="8"
K_NOUSENAME="yes"
K_NOSETEXTRAVERSION="yes"
K_SECURITY_UNSUPPORTED="1"
K_DEBLOB_AVAILABLE="1"
ETYPE="sources"
#KV_PATCH=0
KV="" # autodetect by overlayed kernel-2.eclass
inherit kernel-2 git-r3
#detect_version

n="${PN%%-*}"
DESCRIPTION="Linux-$n"
HOMEPAGE="http://www.kernel.org"
EGIT_REPO_URI="https://git.kernel.org/pub/scm/linux/kernel/git/$n/linux.git"
EGIT_REPO_URI+=" ${EGIT_REPO_URI/https:/git:}"

KEYWORDS="~alpha ~amd64 ~arm ~hppa ~ia64 ~mips ~ppc ~ppc64 ~s390 ~sh ~sparc ~x86"
#IUSE="deblob"

S="${WORKDIR}/linux-$n-$PVR"
EGIT_CHECKOUT_DIR="$S"
