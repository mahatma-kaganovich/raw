#!/bin/sh
# run as active profile with config "-mesa -opengl -osmesa -evdev"
# 2do: ebuild version sort

rm -f err* package.* partial*
echo "# rare mesa/opengl profile" >>package.mask

FL_MASK="opengl egl osmesa evdev"

PORTDIR=/usr/portage

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
}

unmask(){
	act=unmask
	pkg="$1"
}

masks(){
	cnt1=`grep -l virtual/opengl-7.0-r1 $l|wc -l`
	cnt0=`grep -l virtual/opengl $l|wc -l`
	cnt=`grep -L virtual/opengl $l|wc -l`
	echo -n " $cnt0:$cnt1:$cnt"
	[ $cnt0 = $cnt1 -a $cnt = 0 ] && {
		echo "$i" >>partial
		echo ' r1'
		[ -n "$fl_mask" ] && echo "$i$fl_mask" >>package.use.mask
		return 1
	}
	slots=' '
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
		grep -q virtual/opengl-7.0-r1 "$j" && ok=false || {
			grep -q virtual/opengl "$j" && ok=true
		}
		j="${j#$PORTDIR/}"
		j="${j%.ebuild}"
		pn="${j%/*}"
		j="${j//\/*\//\/}"
		# ??? may be on second pass?
		[ -z "$ok" -a "$cnt0" = 0 ] && (USE="$fl_mask" emerge -pv =$j 2>&1 | grep -q virtual/opengl-7.0-r1) && {
			echo -n "~"
			echo "$j" >>partial.dep
			ok=false
		}
		${ok:=true} || echo -n '!'
		echo -n "${j#$pn-}"
		slot="$(meta "$j" SLOT)" || {
#			e=`emerge -pv =$j --nodeps 2>&1`
#			_slot || continue
			echo " ERROR: meta $j"
			exit 1
		}
		slot="${slot// }"
		[ -n "${slots##* ${slot:-0} *}" ] && slots+="$slot "
		sl=${slot:+:$slot}
		echo -n "$sl"
		if [ "$ok" = "$ok1" -a "$slot1" = "$slot" ]; then
			continue
		elif [ "$slot1" != "$slot" ]; then
			! $ok0 && $ok && unmask "$pn$sl"
			$ok0 && ! $ok && mask "$pn$sl"
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
					echo "$pkg0" >>package.$act0
					[ -n "$fl_mask" ] && echo "$pkg0$fl_mask" >>package.use.$act0
					pkg0=
					act0=
				fi
				echo "$pkg" >>package.$act
				[ -n "$fl_mask" ] && echo "$pkg$fl_mask" >>package.use.$act
			fi
		fi
		[ -z "${slot}" ] && ok0=$ok
		ok1=$ok
		slot1=$slot
	done
	echo "$i" >>partial.lst
	true
}

for i in $(cd $PORTDIR && echo */*); do
#for i in $(cd $PORTDIR && echo dev-qt/qtopengl); do
	[ -d "$PORTDIR/$i" ] || continue
	[ "$i" = virtual/opengl ] && continue
	l=$(echo $PORTDIR/$i/*.ebuild)
	fl_mask=
	x="$(meta "$i-*" IUSE)"
	for j in $FL_MASK; do
		[ -z "${x##* $j *}" ] && fl_mask+=" $j"
	done
	[ -z "${fl_mask# }" ] && continue
	slots=
	slot=
	use0=
#	grep -sqF virtual/opengl $l || continue
	grep -sqFw opengl $l || continue
	echo -n $i
	grep -sqF virtual/opengl-7.0-r1 $l && ! masks && continue
	[ -z "$slots" ] && slots=$(meta "$i-*" SLOT)
	[ "${slots// }" = 0 ] && slots=
	for slot in '' $slots; do
		echo -n " :$slot"
		i="${i%%:*}${slot:+:$slot}"
		loop=false
		if e=`emerge -pv "$i" --nodeps 2>&1`; then
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
