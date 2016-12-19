#!/bin/bash
# make per-toolkit _auto/*

d=`pwd`
rm -f _auto/*/package.*.tmp

pkg(){
	local p="$1" x
	while [[ "$p" == */*-* ]]; do
		p="${p%-*}"
		x="/usr/portage/$p/${1#*/}*.ebuild"
		[ "$(echo $x)" != "$x" ] && echo "$p"
	done
}

# 1- list of concurrent useflags (or '+' if exclude next)
generate(){
local x=0 or1= or2= or= d="$d/_auto/$1"
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

l=$(grep -l " \($or\) " */*) || exit 1

[ -n "$3" ] && {
rm -f "$d/package.use.mask" "$d/package.use"
for i in `grep -l '\(\^\^\|??\) ([^()]* \('"$or1"'\) [^()]*)' $l`; do
	grep -oh '\(\^\^\|??\) ([^()]* \('"$or1"'\) [^()]*)' "$i"|while read q; do
		[ -z "${q##\?\?*}" ] && f=true || f=false
		q="${q#?? \(}"
		q="${q%\)}"
		[ -z "$q" ] && continue
		for p in $(pkg "$i"); do
			r=
			r1=
			for q in $q; do
				if [ -z "${l1##* $q *}" ]; then
					r+=" -$q"
					$f && ! grep -sqxF "$p $q" "$d/package.use" && echo "$p $q" >>"$d/package.use"
				elif [ -z "${l1##* -$q *}" ]; then
					r+=" $q"
				else
					r1+=" $q"
				fi
			done
			[ -n "$r" ] && echo "$p$r${r1:+ #$r1}"
		done
	done
done | uniq >>$d/package.use.mask
}

for i in $(grep -l "^IUSE=.*+\($or_\)" $l); do
	x=`grep "^IUSE=" "$i"` || continue
	x=" ${x#IUSE=} "
	for p in $(pkg "$i"); do
		r=
		for j in $1; do
			[ -z "${x##* $j *}" ] && r+=" $j" && continue
			[ -n "$6" -a -z "${x##* $6 *}" ] || continue
			if grep -q "$4" "$i"; then
				grep -q "$5" "$i" && continue
				r+=" $6"
			elif grep -q "$5" "$i"; then
				r+=" -$6"
			fi
		done
		[ -n "$r" ] &&
		for j in $2; do
			[ -z "${x##* +$j *}" ] && r+=" -$j"
		done
		[ -n "$r" ] && ! grep -sqxF "$p$r" "$d/package.use" && echo "$p$r" >>"$d/package.use"
	done
done

cd $d || return 1

return 0
}

(generate qt5 'qt5' 'qt4' 'gtk3 gtk2 gtk sdl' &&
generate qt5 'gtk3' 'gtk gtk2')&
generate gtk3 'gtk3' 'gtk gtk2' 'qt5 qt4 gtk sdl' 'x11-libs/gtk+:3\|x11-libs/gtk+-3' 'x11-libs/gtk+:2\|x11-libs/gtk+-2' 'gtk' &
generate gtk2 'gtk2' 'gtk3' 'qt5 qt4 gtk sdl' 'x11-libs/gtk+:2\|x11-libs/gtk+-2' 'x11-libs/gtk+:3\|x11-libs/gtk+-3' 'gtk' &
generate qt4 'qt4' 'qt5' 'gtk3 gtk2 gtk sdl' &
wait

