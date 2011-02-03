# Copyright 1999-2006 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/eclass/mercurial.eclass,v 1.10 2010/01/17 12:03:48 nelchael Exp $

# @ECLASS: mercurial.eclass
# @MAINTAINER:
# nelchael@gentoo.org
# @BLURB: This eclass provides generic mercurial fetching functions
# @DESCRIPTION:
# This eclass provides generic mercurial fetching functions. To fetch sources
# from mercurial repository just set EHG_REPO_URI to correct repository URI. If
# you need to share single repository between several ebuilds set EHG_PROJECT to
# project name in all of them.

inherit eutils

IUSE="release-branch release-tag"

EXPORT_FUNCTIONS src_unpack

DEPEND="dev-vcs/mercurial"

# @ECLASS-VARIABLE: EHG_REPO_URI
# @DESCRIPTION:
# Mercurial repository URI.

# @ECLASS-VARIABLE: EHG_REVISION
# @DESCRIPTION:
# Create working directory for specified revision, defaults to tip.
#
# EHG_REVISION is passed as a value for --rev parameter, so it can be more than
# just a revision, please consult `hg help revisions' for more details.
#[[ -z "${EHG_REVISION}" ]] && EHG_REVISION="tip"

# @ECLASS-VARIABLE: EHG_PROJECT
# @DESCRIPTION:
# Project name.
#
# This variable default to $PN, but can be changed to allow repository sharing
# between several ebuilds.
[[ -z "${EHG_PROJECT}" ]] && EHG_PROJECT="${PN}"

# @ECLASS-VARIABLE: EHG_QUIET
# @DESCRIPTION:
# Suppress some extra noise from mercurial, set it to 'OFF' to be louder.
: ${EHG_QUIET:="ON"}
[[ "${EHG_QUIET}" == "ON" ]] && EHG_QUIET_CMD_OPT="--quiet"

# @ECLASS-VARIABLE: EHG_CLONE_CMD
# @DESCRIPTION:
# Command used to perform initial repository clone.
[[ -z "${EHG_CLONE_CMD}" ]] && EHG_CLONE_CMD="hg clone ${EHG_QUIET_CMD_OPT} --pull --noupdate"

# @ECLASS-VARIABLE: EHG_PULL_CMD
# @DESCRIPTION:
# Command used to update repository.
[[ -z "${EHG_PULL_CMD}" ]] && EHG_PULL_CMD="hg pull ${EHG_QUIET_CMD_OPT}"

# @ECLASS-VARIABLE: EHG_OFFLINE
# @DESCRIPTION:
# Set this variable to a non-empty value to disable the automatic updating of
# a mercurial source tree. This is intended to be set outside the ebuild by
# users.
EHG_OFFLINE="${EHG_OFFLINE:-${ESCM_OFFLINE}}"

# @ECLASS-VARIABLE: @EHG_BRANCH
# @DESCRIPTION:
# if set, commit/pull only specified branch, not all repo
# for example, mozilla-central needs "default" now to avoid unresolved patch
# (+reduce traffic)

# @FUNCTION: mercurial_fetch
# @USAGE: [repository_uri] [module]
# @DESCRIPTION:
# Clone or update repository.
#
# If not repository URI is passed it defaults to EHG_REPO_URI, if module is
# empty it defaults to basename of EHG_REPO_URI.
function mercurial_fetch {
	debug-print-function ${FUNCNAME} ${*}

	EHG_REPO_URI=${1-${EHG_REPO_URI}}
	[[ -z "${EHG_REPO_URI}" ]] && die "EHG_REPO_URI is empty"

	local hg_src_dir="${PORTAGE_ACTUAL_DISTDIR-${DISTDIR}}/hg-src"
	local module="${2-$(basename "${EHG_REPO_URI}")}"

	# Should be set but blank to prevent using $HOME/.hgrc
	export HGRCPATH=

	# Check ${hg_src_dir} directory:
	addwrite "$(dirname "${hg_src_dir}")" || die "addwrite failed"
	if [[ ! -d "${hg_src_dir}" ]]; then
		mkdir -p "${hg_src_dir}" || die "failed to create ${hg_src_dir}"
		chmod -f g+rw "${hg_src_dir}" || \
			die "failed to chown ${hg_src_dir}"
	fi

	# Create project directory:
	mkdir -p "${hg_src_dir}/${EHG_PROJECT}" || \
		die "failed to create ${hg_src_dir}/${EHG_PROJECT}"
	chmod -f g+rw "${hg_src_dir}/${EHG_PROJECT}" || \
		echo "Warning: failed to chmod g+rw ${EHG_PROJECT}"
	cd "${hg_src_dir}/${EHG_PROJECT}" || \
		die "failed to cd to ${hg_src_dir}/${EHG_PROJECT}"

	rm "${hg_src_dir}/${EHG_PROJECT}/${module}"/.hg/{undo.,}{branch,dirstate,cache} -f

	# Clone/update repository:
	if [[ ! -d "${module}" ]]; then
		einfo "Cloning ${EHG_REPO_URI} to ${hg_src_dir}/${EHG_PROJECT}/${module}"
		${EHG_CLONE_CMD} "${EHG_REPO_URI}" "${module}" ${EHG_BRANCH:+-b $EHG_BRANCH} || {
			rm -rf "${module}"
			die "failed to clone ${EHG_REPO_URI}"
		}
		cd "${module}"
	elif [[ -z "${EHG_OFFLINE}" ]]; then
		einfo "Updating ${hg_src_dir}/${EHG_PROJECT}/${module} from ${EHG_REPO_URI}"
		cd "${module}" || die "failed to cd to ${module}"
		${EHG_PULL_CMD} ${EHG_BRANCH:+-b $EHG_BRANCH} || die "update failed"
	fi

	local EHG_REVISION
	# if release-branch|release-tag useflag given - use first named revision before tip or default
	if [[ -z "${EHG_REVISION}" ]]; then
		local i="EHG_BRANCH_${PN}"
		if use release-branch; then
			for EHG_REVISION in `hg branches -c -R "${hg_src_dir}/${EHG_PROJECT}/${module}" | sed -e 's: .*$::g' | egrep "${!i}"` ; do
				[[ "${EHG_REVISION}" == "default" ]] || break
			done
		fi
		i="EHG_TAG_${PN}"
		if use release-tag &&
		    ( ! use release-branch ||
			[[ "${EHG_REVISION}" == "default" ]] ||
			[[ -z "${EHG_REVISION}" ]] ); then
			for EHG_REVISION in `hg tags -R "${hg_src_dir}/${EHG_PROJECT}/${module}" | sed -e 's: .*$::g' | egrep "${!i}"` ; do
				[[ "${EHG_REVISION}" == "tip" ]] || break
			done
		fi
	fi

	# don't use empty/tip revision: to compatibility with '--date' EHG_EXTRA_OPT
	[[ -n "${EHG_REVISION}" ]] && EHG_REVISION="--rev ${EHG_REVISION}"

	# Checkout working copy:
	einfo "Creating working directory in ${WORKDIR}/${module} (${EHG_REVISION} ${EHG_EXTRA_OPT})"
	mkdir "${WORKDIR}/${module}"
	ln -s "${hg_src_dir}/${EHG_PROJECT}/${module}"/.hg "${WORKDIR}/${module}"/.hg || die
	hg update \
		${EHG_QUIET_CMD_OPT} \
		${EHG_REVISION} -C \
		-R "${WORKDIR}/${module}" ${EHG_EXTRA_OPT} || die "hg update failed"
	# commented for compatibility with clone
#	rm "${WORKDIR}/${module}"/.hg
}

# @FUNCTION: mercurial_src_unpack
# @DESCRIPTION:
# The mercurial src_unpack function, which will be exported.
function mercurial_src_unpack {
	mercurial_fetch
}
