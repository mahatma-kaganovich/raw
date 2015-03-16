#!/bin/sh

rm -f err* package.* partial*

tst1(){
	local x u=
	for x in "${@}"; do
		[ -z "${e##*[\" ]-$x[\" \*]*}" ] && u+=" $x"
	done
	u="${u# }"
	[ -n "$u" ] &&
#	( USE="$u" emerge -pv "$i" --nodeps ) && {
	( USE="$u" emerge -pv "$i" --nodeps &>/dev/null ) && {
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

masks(){
	grep -vlF virtual/opengl-7.0-r1 $(grep -lF virtual/opengl $l) >>partial || {
		echo ' r1'
		echo "$i opengl egl" >>package.use.mask
		return 1
	}
	ok1=true
	slot1=
	ok0=true
	for j in $l; do
		grep -q virtual/opengl-7.0-r1 "$j" && ok=false || ok=true
		j="${j#/usr/portage/}"
		j="${j%.ebuild}"
		pn="${j%/*}"
		j="${j//\/*\//\/}"
		echo -n ' '
		$ok || echo -n '!'
		echo -n "${j#$pn-}"
		e=`emerge -pv =$j --nodeps 2>&1`
		_slot || continue
		sl=${slot:+:$slot}
		echo -n "$sl"
		if [ "$ok" = "$ok1" -a "$slot1" = "$slot" ]; then
			continue
		elif [ "$slot1" != "$slot" ]; then
			! $ok0 && $ok && echo "$pn$sl" >>package.unmask
			$ok0 && ! $ok && echo "$pn$sl" >>package.mask
		else
			$ok && echo "=$j" >>package.unmask || echo ">=$j$sl" >>package.mask
		fi
		[ -z "${slot}" ] && ok0=$ok
		ok1=$ok
		slot1=$slot
	done
	echo "$i" >>partial.lst
	true
}

for i in $(cd /usr/portage && echo */*); do
#for i in dev-qt/qtgui; do
	[ "$i" = virtual/opengl ] && continue
	l=$(echo /usr/portage/$i/*.ebuild)
	slot=
	use0=
	grep -sqF virtual/opengl $l || continue
	echo -n $i
	grep -sqF virtual/opengl-7.0-r1 $l && ! masks && continue
	while true; do
		echo -n "${slot:+ :$slot}"
		loop=false
		if e=`emerge -pv "$i" --nodeps 2>&1`; then
			_slot || break
			if tst1 evdev egl opengl osmesa; then
				true
			else
				echo "$i" >>err2
				echo -n " failed|OK"
			fi
		else
			echo -n " err"
			_slot || break
			echo "$i" >>err1
		fi
		[ -z "$slot" -o "$slot" = 0 -o "$slot" = 1 -o -n "${slot//[0-9]}" ] && break
		[ -n "${slot//[0-9]}" ] && echo -n " SLOT=$slot" && break
		slot=$[slot-1]
		i="${i%%:*}${slot:+:$slot}"
	done
	echo ''
	continue
done
