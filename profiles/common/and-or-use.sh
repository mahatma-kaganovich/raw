#!/bin/bash
# make per-toolkit _auto/*

force=.force
d=`pwd`
export LANG=C
list="${@:-*/*}"

pkg(){
	local p="$1" x
	while [[ "$p" == */*-* ]]; do
		p="${p%-*}"
		x="/usr/portage/$p/${1#*/}*.ebuild"
		[ "$(echo $x)" != "$x" ] && echo "$p"
	done
}

deps(){
local i i1 p x s
grep -h "^[A-Z]DEPEND=" "$1"|sed -e 's:^[A-Z]DEPEND=::'|grep -ohi "[<>\!=]*[a-z][a-z0-9]*-[a-z0-9]*/[^ :\[]*"|while read i; do
	i1="$i"
	s="${i%%[a-z]*}"
	i="${i#$s}"
	[ "$s" = '!' ] && continue
	r=
	for p in $i*; do
		[ -e "$p" ] && r+=" $i*" && break
		while [[ "$p" == */*-* ]]; do
			p="${p%-*}"
			x="$(echo $p*)"
			[ "$x" != "$p*" ] && r+=" $p*" && break
		done
	done
	if [ -z "$s" ]; then
		echo "$r"
	elif [ "$s" = '>=' ]; then
		for p in $r; do
			[[ "$p" > "$i" || "$p" == "$i"* ]] && echo "$p"
		done
	elif [ "$s" = '<=' ]; then
		for p in $r; do
			[[ "$p" < "$i" || "$p" == "$i"* ]] && echo "$p"
		done
	else
		echo " ???? '$s' $i1" >&2
	fi
done
}

ap(){
	local i s="### precise"
	[ -e "$4" ] || echo "$s
" >"$4"
	i="=$1$3"
	grep -sqxF "$i" "$4" || echo "$i" >>"$4"
	i="$2$3"
	grep -sqxF "$i" "$4" || sed -i -e "s:^$s\$:$i\n$s:" "$4"
}

chk6(){
	local x1=false x2=false x r1 r2 rr=
	for x in $4; do
		[ -z "${iuse1##* $x *}" ] && return 1
	done
	for x in $5; do
		[ -z "${iuse1##* $x *}" ] && return 0
	done
	r1=`grep -c "$1" "$i"` && x1=true
	r2=`grep -c "$2" "$i"` && x2=true
	! $x1 && ! $x2 && {
		x=$(deps $i)
		r1=`cat $i $x|grep -c "$1"` && x1=true
		r2=`cat $i $x|grep -c "$2"` && x2=true
		rr='+'
	}
	$x1 && $x2 && [ "$7" = 1 -a "$r1" != "$r2" ] && {
		[ $r1 -lt $r2 ] && x1=false || x2=false
		rr+='?'
	}
	[ -n "$rr" ] &&  echo " $rr $4/$5 $r1/$r2 $x1 $x2	$i" >&2
	! $x1 && ! $x2 && return $6
	$x1 && $x2  && return $7
	$x1
}

generate(){
local x=0 or1= or2= or= d="$d/_auto/${1#+}"
[[ "$1" == +* ]] || rm -f "$d/package.use"*
shift
mkdir -p "$d"
cd "$d" && cd /usr/portage/metadata/md5-cache || return 1
v=${6#+}
[ "$v" = "$6" ] && prob=0 || prob=1
x='\|'
for i in $1 $v; do
	or1+="$x$i"
done
for i in $2 $v; do
	or2+="$x$i"
done
for i in $3 $v; do
	or3+="$x$i"
done
or1="${or1#??}"
or="$or1$or2$or3"
or2="${or2#??}"
or_="$or2$or3"
or3="${or3#??}"
l1=" $2${3:+ $3}"
l1=" $1 ${l1// / -} "

or1='!*\('"$or1"'\)'
or_='!*\('"$or_"'\)'
#ww='[^()?\*\[\]]*'
ww='[^()?\*\[]*'
#ww='[^()]*'

re1='\(\^\^\|??\) '"($ww $or1 $ww)"
re2='^IUSE=.*+'"$or_"
re31="$or1? ($ww $or_ $ww)"
re32="$or_? ($ww $or1 $ww)"
re3='\(E=\| \)\('"$re1$x$re31$x$re32"'\)'

l=$(grep -l " \($or\) " $list) || return 1 #"

[ -n "$3" ] && {
for i in $(grep -l "^REQUIRED_US.*$re3" $l); do
	grep -oh "$re3" "$i"|while read q; do
		q="${q#E=}"
		q0="${q% \( *}"
		q="${q#* \( }"
		q="${q% \)}"
		[ -z "${q##*[*?\[\]]*}" -o -z "${q//[ !]/}" ] && echo "Wrong REQUIRED_USE in $i - '$q'" >&2 && continue
		q=" $q "
		f=true
		if1=false
		if2=false
		iuse=`grep "^IUSE=" "$i"`
		iuse=" ${iuse#IUSE=} "
		iuse1="${iuse// [+~-]/ }"
		if [ "$q0" = '??' ]; then
			true
			f=false
		elif [ "$q0" = '^^' ]; then
			true
		else
			q0="${q0%\?}"
			x=" $1 "
			if [ -z "${x##* ${q0#!} *}" ]; then
				if1=true
			else
				if2=true
				j="$q"
				q=" $q0 "
				q0="$j"
				for j in $q0; do
					[ -n "${x##* ${j#!} *}" ] && q0="${q0// $j / }"
				done
				continue
			fi
			
			[ "$q0" = "$v" ] && ! chk6 "$4" "$5" "$v" "$1" "$2" $prob $prob && continue
#			continue
		fi

		q="${q//  / }"
		q="${q// !/ -}"
		# unify both results
		if $if1; then
			x=" $1 "
			q="${q// / -} "
			q="${q// - / }"
		else
			# sort $q in $1 order, first - unmasked
			x=
			for j in $1; do x="$j $x";done
			[ -n "$v" ] && chk6 "$4" "$5" "$v" "$1" "$2" $prob $prob && x="$v $x"
			x=" $x"
			for j in $x; do [ -z "${q##* $j *}" ] && q="$j ${q// $j / }"; done

			# get first. according to regex - it verified
			while [[ "$q" == ' '* ]]; do q="${q# }"; done
			q0="${q%% *}"
			q=" ${q#* }"
		fi

		q="${q// --/ }" # ???
		while [[ "$q" == *'  '* ]]; do q="${q//  / }"; done

		[ -z "$q0" ] && continue
		if [[ "$q0" == '!'* ]]; then
			q0="${q0#!}"
			q="${q// / -}"
			q="${q%-}"
			q="${q// --/ }"
		fi
		[ -n "${x##* $q0 *}" ] && continue

		r1=
		for j in $q; do
			[ -n "${x##* ${j#-} *}" -a -n "${l1##* -${j#-} *}" ] && r1+=" $j" && q="${q// $j / }"
		done
		r=" -$q0${q% }"
		u=
		$f && {
			u=" $q0${q// / -}"
			u="${u%-}"
			u="${u// --/ }"
			for j in $u; do
				[ "${j#-}" = "$6" -o -z "${iuse##* +${j#-} *}" ] && u="${u// $j / }"
			done
			u="${u% }"
		}

		for p in $(pkg "$i"); do
			[[ "$r" == *' -'* ]] && ap "$i" "$p" "$r${r1:+ #$r1}" "$d/package.use.mask"
			[ -n "$u" ] && ap "$i" "$p" "$u" "$d/package.use$force"
		done
	done
done
}

for i in $(grep -l "$re2" $l); do
	iuse=`grep "^IUSE=" "$i"`
	iuse=" ${iuse#IUSE=} "
	iuse1="${iuse// [+~-]/ }"
	for p in $(pkg "$i"); do
		r=
		r1=
		# if flag exists "+" and new active flag is other - 
		for j in $1 $v; do
			[ -n "${iuse1##* $j *}" ] && continue
			[ "$j" = "$6" ] && continue
			[ "$j" = "$v" ] && ! chk6 "$4" "$5" "$v" "$1" "$2" 1 0 && continue
			r+=" $j"
			#break # ???
		done
		[ -z "$r" ] && continue
		r+=' '
		for j in $1 $2 $v; do
			[ -n "${iuse1##* $j *}" ] && continue
			[ -z "${r##* $j *}" ] && continue
			[ -z "${r##* -$j *}" ] && continue
			[ "$j" = "$v" ] && ! chk6 "$4" "$5" "$v" "$1" "$2" 0 0 && continue
			r+="-$j "
		done
		ap "$i" "$p" "${r% }" "$d/package.use"
	done
done

cd $d
}

sl(){
	echo '\( \|D=\)\(\|=\|[<>=]=\)\('"$1"'\)\(:'"$2"'\|-'"$2"'\|:=\| \|$\)'
}

gtk2="$(sl x11-libs/gtk+ 2)"
gtk3="$(sl x11-libs/gtk+ 3)"
qt4="$(sl "dev-qt/qt[a-zA-Z-]*" 4)"
qt5="$(sl "dev-qt/qt[a-zA-Z-]*" 5)"

generate gles 'gles2 gles gles1' 'opengl' 'gles gles1 opengl egl vaapi' &
{
generate common 'opengl egl' 'gles gles1 gles2' 'gles gles1 gles2 egl'
x1='kernel ssl openssl gnutls nss mhash cryptopp nettle' # enabled
x2='libressl yassl mbedtls embedded' # drop
generate +common "$x1" "$x1" "$x2"
} &
generate qt5 'qt5' 'qt4' 'gtk3 gtk2 gtk sdl' "$qt5" "$qt4" kde &
generate qt4 'qt4' 'qt5' 'gtk3 gtk2 gtk sdl' "$qt4" "$qt5" kde &
generate gtk3 'gtk3' 'gtk2' 'qt5 qt4 gtk sdl' "$gtk3" "$gtk2" +gtk &
generate gtk2 'gtk2' 'gtk3' 'qt5 qt4 gtk sdl' "$gtk2" "$gtk3" +gtk &
generate sdl 'sdl sdl2' '__NOsdl__' 'qt5 qt4 gtk gtk2 gtk3' &
wait
