#!/bin/bash
# make per-toolkit _auto/*

# cannot relax/unforce per version (ignored), so keep precise versioning off
precise=false

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
	local x="${1//  / }"
	x="${x% }"
	x=" ${x# }"
	if $precise; then
		[ "$3" = false ]
		local s="### precise"
		[ -e "$2" ] || echo "$s
" >"$2"
		[ "$3" = false ] || [ -z "$p" ] || grep -sqxF "$p$x" "$2" || sed -i -e "s:^$s\$:$p$x\n$s:" "$2"
		[ "$3" = true ] || grep -sqxF "=$i$x" "$2" || echo "=$i$x" >>"$2"
	else
		grep -sqxF "$p$x" "$2" || echo "$p$x" >>"$2"
	fi
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

inv(){
	local i=" $1 "
	i="${i//  / }"
	i="${i// / -}"
	i="${i%-}"
	echo "${i// --/ }"
}

re1(){
	grep '^REQUIRED_USE=' "$i"|grep -o "$re"|while read q; do
		q="${q#E=}"
		q_="$q"
		q0="${q% \( *}"
		q="${q#* \( }"
		q="${q% \)}"
		[ -z "${q##*[*?\[\]]*}" -o -z "${q//[ !]/}" ] && echo "Wrong REQUIRED_USE in $i - '$q'" >&2 && continue
		q=" $q "
		f=true
		iuse=`grep "^IUSE=" "$i"`
		iuse=" ${iuse#IUSE=} "
		iuse1="${iuse// [+~-]/ }"
		q="${q// !/ -}"
		q="${q// - / }"
		q="${q%!}"

		q0="${q0%\?}"
		q0="${q0//!/-}"
		x=" $1 "
		if $if1; then
			[ "${q0#-}" = "$v" ] && ! chk6 "$4" "$5" "$v" "$1" "$2" $prob $prob && continue
		elif $if2; then
			j="$q"
			q=" $q0 "
			q0=
			[[ "$q" == ' -'* ]] || j=$(inv "$j")
			for j in $j; do
				if [ "$j" = "$v" ]; then
					chk6 "$4" "$5" "$v" "$1" "$2" $prob $prob && q0+=" $j" || continue
				elif [ -n "${x##* $j *}" ]; then
					continue
				fi
				q0+=" $j"
			done
			[ -z "${q0// /}" ] && continue
			[[ "$q" == ' -'* ]] || q=$(inv "$q")
			q0="${q0# }"
			q0="${q0% }"
		elif [ "$q0" != '^^' ]; then
			f=false
		fi
		q0=" $q0 "
		q0="${q0//  / }"
		q=" $q "
		q="${q//  / }"

		# unify both results
		if $if1; then
			x=" $1 "
			q=$(inv "$q")
		elif $if2; then
			x=" $1 "
			q=$(inv "$q")
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

		while [[ "$q" == *'  '* ]]; do q="${q//  / }"; done

		[ -z "${q0//[ -]/}" ] && continue
		if [[ "$q0" == ' -'* ]]; then
			q0=$(inv "$q0")
			[[ "$q0" == ' -'* ]] && echo "Skip: don't know how to resolve: $i '$q_'" >&2 && continue
			q=$(inv "$q")
		fi

		r1=
		for j in $q; do
			[ -n "${x##* ${j#-} *}" -a -n "${l1##* -${j#-} *}" ] && r1+=" $j" && q="${q// $j / }"
		done
		r="$(inv "$q0")$q"
		u=
		pr=
		($f || $precise) && {
			u="$q0"
			$f && u="$q0" || u=$(inv "$q0")
			u+=$(inv "$q")
			for j in $u; do
				[ "${j#-}" = "$6" -o -z "${iuse##* +${j#-} *}" ] && u="${u// $j / }"
			done
#			$f || u+=" ##precise"
		}

		for p in $(pkg "$i"); do
			[[ "$r" == *' -'* ]] && ap "$r${r1:+#$r1}" "$d/package.use.mask"
			[ -n "$u" ] && ap "$u" "$d/package.use$force" $f
		done
	done
}

re2(){
	iuse=`grep "$re2" "$i"` || {
		[ -z "$6" -o "$v" = "$6" ] && return
		iuse=`grep "^IUSE.*[ =]-*$v"'\($\| \)' "$i"` || return
		chk6 "$4" "$5" "$v" "$1" "$2" 1 1 || return
		iuse=" ${iuse#IUSE=} "
		iuse1="${iuse// [+~-]/ }"
		for p in $(pkg "$i"); do
			ap "$v" "$d/package.use"
		done
		return
	}
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
		ap "${r% }" "$d/package.use"
	done
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
re2='^IUSE=.*+\('"$or_"'\)'
or_='!*\('"$or_"'\)'
#ww='[^()?\*\[\]]*'
ww='[^()?\*\[]*'
#ww='[^()]*'

re1='\(\^\^\|??\) '"($ww $or1 $ww)"
re31="$or1? ($ww $or_ $ww)"
re32="$or_? ($ww $or1 $ww)"
rs1='\(E=\| \)\('
rs2='\)'

if1=false
if2=false

grep -l ' \('"$or"'\) ' $list|while read i; do
	[ -n "$3" ] && {
		re="$rs1$re1$rs2"
		re1 "${@}"
		if1=true
		re="$rs1$re31$rs2"
		re1 "${@}"
		if1=false
		if2=true
		re="$rs1$re32$rs2"
		re1 "${@}"
		if2=false
	}
	re2 "${@}"
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
force='' generate common 'opengl egl' 'gles gles1 gles2' 'gles gles1 gles2 egl'
x1='kernel ssl openssl gnutls nss mhash cryptopp nettle gcrypt' # enabled
x2='libressl yassl mbedtls embedded' # drop
force='' generate +common "$x1" "$x1" "$x2"
} &
generate qt5 'qt5' 'qt4' 'gtk3 gtk2 gtk sdl' "$qt5" "$qt4" kde &
generate qt4 'qt4' 'qt5' 'gtk3 gtk2 gtk sdl' "$qt4" "$qt5" kde &
generate gtk3 'gtk3' 'gtk2' 'qt5 qt4 gtk sdl' "$gtk3" "$gtk2" +gtk &
generate gtk2 'gtk2' 'gtk3' 'qt5 qt4 gtk sdl' "$gtk2" "$gtk3" +gtk &
generate sdl 'sdl sdl2' '__NOsdl__' 'qt5 qt4 gtk gtk2 gtk3' &
wait
