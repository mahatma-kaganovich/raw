#!/bin/bash
# make per-toolkit _auto/*

d=`pwd`

pkg(){
	local p="$1" x
	while [[ "$p" == */*-* ]]; do
		p="${p%-*}"
		x="/usr/portage/$p/${1#*/}*.ebuild"
		[ "$(echo $x)" != "$x" ] && echo "$p"
	done
}

generate(){
local x=0 or1= or2= or= d="$d/_auto/${1#+}"
[[ "$1" == +* ]] || rm -f "$d/package.use.mask" "$d/package.use"
shift
mkdir -p "$d"
cd "$d" && cd /usr/portage/metadata/md5-cache || return 1
for i in $1; do
	or1+="\|$i"
done
for i in $2; do
	or2+="\|$i"
done
for i in $3; do
	or3+="\|$i"
done
or1="${or1#??}"
or="$or1$or2$or3"
or2="${or2#??}"
or_="$or2$or3"
or3="${or3#??}"
l1=" $2${3:+ $3}"
l1=" $1 ${l1// / -} "

l=$(grep -l " \($or\) " */*) || return 1

ap(){
	grep -sqxF "$1" "$2" || echo "$1" >>"$2"
}



[ -n "$3" ] && {
for i in `grep -l '\(\^\^\|??\) ([^()]* \('"$or1"'\) [^()]*)' $l`; do
	grep -oh '\(\^\^\|??\) ([^()]* \('"$or1"'\) [^()]*)' "$i"|while read q; do
		[ -z "${q##\?\?*}" ] && f=true || f=false
		$f && iuse=`grep "^IUSE=" "$i"` && iuse=" ${iuse#IUSE=} "
		q="${q#?? \(}"
		q="${q%\)}"
		[ -z "$q" ] && continue
		q=" $q "
		x=
		for j in $1; do
			x="$j $x"
		done
		for j in $x; do
			[ -z "${q##* $j *}" ] && q="$j ${q// $j / }"
		done
		for p in $(pkg "$i"); do
			r=
			r1=
			for q in $q; do
				if [ -z "${l1##* $q *}" ]; then
					[[ "$r" == *' -'* ]] && r+=" $q" || r+=" -$q"
					$f && [ -n "${iuse##* +$q *}" ] &&  ap "$p $q" "$d/package.use"
				elif [ -z "${l1##* -$q *}" ]; then
					r+=" $q"
				else
					r1+=" $q"
				fi
			done
			[ -n "$r" ] && ap "$p$r${r1:+ #$r1}" "$d/package.use.mask"
		done
	done
done
}

for i in $(grep -l "^IUSE=.*+\($or_\)" $l); do
	x=`grep "^IUSE=" "$i"` || continue
	x=" ${x#IUSE=} "
	for p in $(pkg "$i"); do
		r=
		r1=
		e=true
		for j in $1; do
			[ -z "${x##* +$j *}" ] && r=" " && r1="$j" && e=false && break
			[ -z "${x##* $j *}" ] && r=" $j" && e=false && break
			[ -z "${x##* [~-]$j *}" ] && e=false
		done
		if $e && [ -n "$6" -a -z "${x##* $6 *}" ]; then
			if grep -q "$4" "$i"; then
				grep -q "$5" "$i" && continue
				r+=" $6"
			elif grep -q "$5" "$i"; then
				r+=" -$6"
			fi
		fi
		[ -z "$r" ] && continue
		r1+="$r"
		for j in $2; do
			for i1 in $r1; do
				[ "$i1" = "$j" ] && continue 2
			done
			[ -z "${x##* +$j *}" ] && r+=" -$j"
		done
		[ "$r" = ' ' ] || ap "$p$r" "$d/package.use"
	done
done


cd $d || return 1

return 0
}

{
generate common 'opengl' 'gles gles1 gles2 egl' 'gles gles1 gles2 egl'
x1='kernel ssl openssl gnutls nss mhash cryptopp nettle' # enabled
x2='libressl yassl mbedtls embedded' # drop
generate +common "$x1" "$x1" "$x2"
} &
generate qt5 'qt5' 'qt4' 'gtk3 gtk2 gtk sdl' &
generate gtk3 'gtk3' 'gtk gtk2' 'qt5 qt4 gtk sdl' 'x11-libs/gtk+:3\|x11-libs/gtk+-3' 'x11-libs/gtk+:2\|x11-libs/gtk+-2' 'gtk' &
generate gtk2 'gtk2' 'gtk3' 'qt5 qt4 gtk sdl' 'x11-libs/gtk+:2\|x11-libs/gtk+-2' 'x11-libs/gtk+:3\|x11-libs/gtk+-3' 'gtk' &
generate qt4 'qt4' 'qt5' 'gtk3 gtk2 gtk sdl' &
wait

