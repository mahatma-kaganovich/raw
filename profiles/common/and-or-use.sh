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

ap(){
	grep -sqxF "$1" "$2" || echo "$1" >>"$2"
}

chk6(){
	local x1=false x2=false x
	for x in $4; do
		[ -z "${iuse1##* $x *}" ] && return 1
	done
	for x in $5; do
		[ -z "${iuse1##* $x *}" ] && return 0
	done
	grep -q "$1" "$i" && x1=true
	grep -q "$2" "$i" && x2=true
	! $x1 && ! $x2 && return $6
	$x1 && $x2  && return 0
	$x1 
}

generate(){
local x=0 or1= or2= or= d="$d/_auto/${1#+}"
[[ "$1" == +* ]] || rm -f "$d/package.use.mask" "$d/package.use"
shift
mkdir -p "$d"
cd "$d" && cd /usr/portage/metadata/md5-cache || return 1
for i in $1 $6; do
	or1+="\|$i"
done
for i in $2 $6; do
	or2+="\|$i"
done
for i in $3 $6; do
	or3+="\|$i"
done
or1="${or1#??}"
or="$or1$or2$or3"
or2="${or2#??}"
or_="$or2$or3"
or3="${or3#??}"
l1=" $2${3:+ $3}"
l1=" $1 ${l1// / -} "

l=$(grep -l " \($or\) " */*) || return 1 #"

[ -n "$3" ] && {
for i in `grep -l '\(\^\^\|??\) ([^()]* \('"$or1"'\) [^()]*)' $l`; do
	grep -oh '\(\^\^\|??\) ([^()]* \('"$or1"'\) [^()]*)' "$i"|while read q; do
		[ -z "${q##\?\?*}" ] && f=true || f=false
		q="${q#?? \(}"
		q="${q%\)}"
		[ -z "$q" ] && continue
		iuse=`grep "^IUSE=" "$i"`
		iuse=" ${iuse#IUSE=} "
		iuse1="${iuse// [+~-]/ }"
		q=" $q "
		x=
		for j in $1; do
			x="$j $x"
		done
		[ -n "$6" ] && chk6 "$4" "$5" "$6" "$1" "$2" 1 && x="$6 $x"
		x=" $x"
		for j in $x; do
			[ -z "${q##* $j *}" ] && q="$j ${q// $j / }"
		done
		for p in $(pkg "$i"); do
			r=
			r1=
			for q in $q; do
				if [ -z "${x##* $q *}" ]; then
					[[ "$r" == *' -'* ]] && r+=" $q" || r+=" -$q"
					$f && [ -n "${iuse##* +$q *}" ] &&  ap "$p $q" "$d/package.use"
				elif [ -z "${l1##* -$q *}" ]; then
					r+=" $q"
				else
					r1+=" $q"
				fi
			done
			[[ "$r" == *' -'* ]] && ap "$p$r${r1:+ #$r1}" "$d/package.use.mask"
		done
	done
done
}

for i in $(grep -l "^IUSE=.*+\($or_\)" $l); do
	iuse=`grep "^IUSE=" "$i"`
	iuse=" ${iuse#IUSE=} "
	iuse1="${iuse// [+~-]/ }"
	for p in $(pkg "$i"); do
		r=
		r1=
		# if flag exists "+" and new active flag is other - 
		for j in $1 $6; do
			[ -n "${iuse1##* $j *}" ] && continue
			[ "$j" = "$6" ] && ! chk6 "$4" "$5" "$6" "$1" "$2" 1  && continue
			r+=" $j"
			#break # ???
		done
		[ -z "$r" ] && continue
		r+=' '
		for j in $1 $2 $6; do
			[ -n "${iuse1##* $j *}" ] && continue
			[ -z "${r##* $j *}" ] && continue
			[ -z "${r##* -$j *}" ] && continue
			[ "$j" = "$6" ] && ! chk6 "$4" "$5" "$6" "$1" "$2" 1  && continue
			r+="-$j "
		done
		ap "$p${r% }" "$d/package.use"
	done
done


cd $d || return 1

return 0
}

gtk2='x11-libs/gtk+:2\|x11-libs/gtk+-2\|gnome2'
gtk3='x11-libs/gtk+:3\|x11-libs/gtk+-3\|gnome3'

{
generate common 'opengl egl' 'gles gles1 gles2' 'gles gles1 gles2 egl'
x1='kernel ssl openssl gnutls nss mhash cryptopp nettle' # enabled
x2='libressl yassl mbedtls embedded' # drop
generate +common "$x1" "$x1" "$x2"
} &
generate qt5 'qt5' 'qt4' 'gtk3 gtk2 gtk sdl' &
generate gtk3 'gtk3' 'gtk2' 'qt5 qt4 gtk sdl' "$gtk3" "$gtk2" gtk &
generate gtk2 'gtk2' 'gtk3' 'qt5 qt4 gtk sdl' "$gtk2" "$gtk3" gtk &
generate qt4 'qt4' 'qt5' 'gtk3 gtk2 gtk sdl' &
wait
