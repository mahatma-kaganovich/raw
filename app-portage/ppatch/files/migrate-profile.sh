#!/bin/bash

profset(){
	[ "`readlink "$1$2"`" = "$3" ] && return 0
	[ -e "$1$2" -o -L "$1$2" ] && return 1
	$4 && return 0
	ln -s "$3" "$1$2" && echo "$2=$3"
}

migrate_profile(){
	[ -z "$ROOT" -o "`readlink -f "$ROOT"`" = / ] || return 1
	[ -z "$EROOT" -o "`readlink -f "$EROOT"`" = / ] || return 1
	local R=
	local i p="$R/etc/portage/make.profile" pn='' pn1 ll raw pt pg pc pp='' pg='' mv=false fixed=false V=13.0
	l=`readlink "$p"` || return 1
	ll=`readlink -f "$p"` || return 1
	for i in '' /desktop /server; do
		[[ "$ll" == /usr/portage/profiles/default/linux/*/$V$i ]] || continue
		if [ "$1" != force ]; then
			echo "say 'force' to install"
			return 1
		fi
		pn="${i#/}"
		mv=true
		[ -z "$pn" ] && pn=server
		raw="${FILESDIR%/*/*/*}"
		pg="$raw/$pn"
		break
	done
	if [ -z "$pn" ]; then
		for i in target gentoo common; do
			[ -L "$p.$i" ] && return 1
		done
		pn="${l##*/profiles/}"
		raw="${l%%/profiles/*}"
		[ -n "$pn" -a "$pn" != "$l" ] && break
	fi
#	echo raw=$raw pn=$pn
	raw="$raw/profiles"
	[ -z "$pn" ] && return 1
	pt="$raw/targets/${pn#*/}"
	[ -z "$pg" ] && read pg <"$raw/${pn%%/*}/parent" || return 1
	pp="$R/usr/ppatch/profiles/native"
	pc="$raw/common/unroll2"
	[ -z "$raw" -o -z "$pn" -o -z "$pg" ] && return 1
	[ -e "$pt" -a -e "$pg" -a -e "$pc" -a -e "$pp" ] || return 1
	echo "current profile \"$pn\" $pn1 target=$pt"
	for i in true false; do
		profset "$p" .common "$pc" "$i" &&
		profset "$p" .target "$pt" "$i" || return 1
		if $mv; then
			rename profile profile.gentoo "$p" || return 1
			fixed=true
		else
			profset "$p" .gentoo "$pg" "$i" || return 1
			$i && continue
			unlink "$p" || return 1
		fi
		profset "$p" '' "$pp" "$i"  || return 1
	done
	$fixed && echo "profile fixed"
	return 0
}

migrate_profile $1
