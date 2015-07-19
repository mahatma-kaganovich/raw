#!/bin/sh
# run as active profile

rm -f err* package.* partial*

echo "# rare mesa/opengl profile" >>package.mask

FL_MASK_GOOD="evdev"
FL_MASK_BAD="opengl egl osmesa"
V0='virtual/opengl|media-libs/mesa|app-eselect/eselect-opengl|virtual/glu'
V1='[>=]virtual/opengl-7.0-r[0-9]|[^<]=?media-libs/mesa-[89]|[^<]=?app-eselect/eselect-opengl-1\.([3-9]|[0-9]{2})|[^<]=virtual/glu-9.0-r1|x11-libs/gtkglext'
FIND='opengl|mesa|glu'
NOMASK='media-libs/gst-plugins-bad|media-video/ffmpeg'

PORTDIR=/usr/portage

FL_MASK_OFF=" $FL_MASK_BAD $FL_MASK_GOOD"
FL_MASK_OFF="${FL_MASK_OFF// / -}"

meta(){
	local x=`grep -h "^$2=" $PORTDIR/metadata/md5-cache/${1%%:} |sed -e "s:^$2=::" -e 's: :\n:g'|sed -e 's:^\+::'|sort -u`
	echo " ${x//
/ } "
}

tst1(){
	local x u=
	for x in "${@}"; do
		[ -z "${e##*[\" ]-$x[\" \*]*}" ] && u+=" $x"
	done
	u="${u# }"
	[ -n "$u" ] &&
#	( USE="$USE $u" emerge -pv "$i" --nodeps ) && {
	( USE="$USE $u" emerge -pv "$i" --nodeps &>/dev/null ) && {
		echo -n " $u OK"
		echo "$i $u" >>package.use.force
	}
}

_slot(){
	local e1="$e"
	e=`echo " $e"|grep "^\[ebuild"` && slot="${e#*:}" && slot="${slot%%:*}" && return 0
	echo " $e" >>error.log
	return 1
}

mask(){
	act=mask
	pkg="$1"
	masked=true
}

unmask(){
	act=unmask
	pkg="$1"
	unmasked=true
}

msk(){
	if [ "$2" = mask ]; then
		(echo " $1"|grep -Pq "$NOMASK") || echo "$1" >>package.mask
	else
		echo "$1" >>package.unmask
	fi
	[ -n "$fl_mask" ] && echo "$1$fl_mask" >>package.use.$2
}

_dep(){
	local x=" $3 " j
	for j in $(grep -h "^[A-Z]*DEPEND=" $PORTDIR/metadata/md5-cache/${1%%:} |sed -e "s:^[A-Z]*DEPEND=::" -e 's:([^ ]*)::g'|grep -Po "[\S]+\? \([^\(\)]*($2)[^\(\)]*\)"|sed -e 's:\?.*::' -e 's::\n:' -e 's:\!::'|sort -u); do #'
		[ -z "${x##* $j *}" -o "$3" = '*' ] && return 0
	done
	return 1
}

badbaduse(){
	! _dep "$1" "$V1" "$FL_MASK_BAD" && _dep "$1" "$V1" "$FL_BAD"
}

masks(){
	cnt=0
	cnt0=0
	cnt1=0
	for j in $l; do
		grep -Pq "$V1" $j && cnt1=$[cnt1+1] && continue
		grep -Pq "$V0" $j && cnt0=$[cnt0+1] && continue
		cnt=$[cnt+1] && continue
	done
	cnt2=$[cnt0+cnt1]
	echo -n " $cnt0:$cnt1:$cnt"
	[ $cnt0 = 0 -a $cnt1 != 0 -a $cnt = 0 ] && {
		echo -n ' r1'
		[ -n "$fl_mask" ] && echo "$i$fl_mask" >>package.use.mask
		return 1
	}
	ok1=true
	slot1=
	ok0=true
	cnt=0
	pkg0=
	act0=
	for j in $l; do
		cnt=$[cnt+1]
		act=
		pkg=
		ok=
		echo -n ' '
		grep -Pq "$V1" "$j" && ok=false || {
			grep -Pq "$V0" "$j" && ok=true
		}
		j="${j#$PORTDIR/}"
		j="${j%.ebuild}"
		j="${j//\/*\//\/}"
		! $ok && badbaduse "$j" && ok=true
		# ??? may be on second pass?
		[ -z "$ok" -a "$cnt2" = 0 ] && (USE="$fl_mask" emerge -pv =$j 2>&1 | grep -Pq "$V1") && {
			echo -n "~"
			echo "$j" >>partial.dep
			ok=false
		}
		${ok:=true} || echo -n '!'
		echo -n "${j#$i-}"
		slot="$(meta "$j" SLOT)" || {
#			e=`emerge -pv =$j --nodeps 2>&1`
#			_slot || continue
			echo " ERROR: meta $j"
			exit 1
		}
		slot="${slot// }"
		[ "$slot" = 0 -a -z "$slots" ] && slot=
		sl=${slot:+:$slot}
		echo -n "$sl"
		if [ "$ok" = "$ok1" -a "$slot1" = "$slot" ]; then
			continue
		elif [ "$slot1" != "$slot" ]; then
			! $ok0 && $ok && unmask "$i$sl"
			$ok0 && ! $ok && mask "$i$sl"
		else
			$ok && unmask "=$j" || mask ">=$j$sl"
		fi
		if [ -n "$act" ]; then
			# don't touch single-version action
			if [ "$cnt" == 1 ]; then
				pkg0="$pkg"
				act0="$act"
			else
				if [ -n "$act0" ]; then
					msk "$pkg0" $act0
					pkg0=
					act0=
				fi
				msk "$pkg" $act
			fi
		fi
		[ -z "${slot}" ] && ok0=$ok
		ok1=$ok
		slot1=$slot
	done
	echo "$i" >>partial.lst
	true
}

iuse(){
	local j
	for j in "${@}"; do
		[ -z "${iuse##* $j *}" ] && echo -n " $j"
	done
}

param="$1"

for i in $(cd $PORTDIR && echo */${param:-*}); do
	[ -d "$PORTDIR/$i" -a "$i" != virtual/opengl -a -n "${i##distfiles/*}" ] || continue
	pn="${i##*/}"
	j="$PORTDIR/$i/$pn-*.ebuild"
	l=$(find "$PORTDIR/$i" -path "$j" -type f|sort -V)
	[ "$l" = "$j" -o -z "$l" ] && continue
	fl_mask=
	iuse="$(meta "$i-*" IUSE)"
	fl_mask=`iuse $FL_MASK_BAD $FL_MASK_GOOD`
	fl_mask_bad=`iuse $FL_MASK_BAD`
	slot=
	use0=
	grep -Psqv "$FIND" $l || continue
	slots=$(meta "$i-*" SLOT)
	[ "${slots// }" = 0 ] && slots=
	if grep -Psq "$V1" $l; then
		badbaduse "$i-*" && continue
		echo -n $i
		(! masks || [ -z "${fl_mask# }" ]) && echo '' && continue
	elif [ -z "${fl_mask# }" ]; then
		continue
	else
		echo -n $i
	fi
	for slot in '' $slots; do
		echo -n " :$slot"
		i="${i%%:*}${slot:+:$slot}"
		loop=false
		if e=`USE="$FL_MASK_OFF" emerge -pv "$i" --nodeps 2>&1`; then
			_slot || break
			if tst1 $fl_mask; then
				true
			else
				echo "$i" >>err2
				echo -n " failed|OK"
			fi
		else
			echo -n " err"
			_slot || {
				echo "$i" >>err2
				break
			}
			echo "$i" >>err1
		fi
	done
	echo ''
	continue
done

(emerge --info|grep "^USE="|grep -w opengl) && unlink package.use.force
