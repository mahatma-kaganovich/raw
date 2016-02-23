#!/bin/bash

# openmp: experimental for system-wide
omp=false

export LANG=C

ct='--help=target -v -Q'

_c(){
	gcc "${@}" $ct 2>&1
}

_c1(){
	echo 'void main(){}'|gcc -x c - -pipe "${@}" -o /dev/null 2>&1
}

_f(){
	local i
	for i in "${@}"; do
		c=`_c1 $i` || continue
		(echo "$c" | grep -q " warning: .* is deprecated\|warning: this target does not support" ) && continue
		echo -n " $i"
	done
}

_cmp(){
	local i i0 i1 ok
	if i0=`echo "$c0"|grep "$1"` && i=`echo "$c"|grep "$1"`; then
		for i in $i; do
			[ -z "${i##/*}" ] && continue
			ok=true
			for i1 in $i0; do
				[ "$i" = "$i1" ] && ok=false && break
			done
			$ok && echo -n " $2$i"
		done
	fi
}

_flags(){
	grep -s "^$1	*:" /proc/cpuinfo|sort -u|sed -e "s/^$1	*: //" -e 's:,: :g'
}

_smp(){
	local i
	i=`grep "^$1[ 	]*: " /proc/cpuinfo` && i="${i##*: }" && echo $[i+$2]
}

conf_cpu(){
local flags cpucaps f0= f1= f2= f3= i j i1 j1 c c0 c1 lm=false
flags=$(_flags flags)
cpucaps=$(_flags cpucaps)
f0=`_f -m{tune,cpu,arch}=native`
f3='-malign-data=cacheline -momit-leaf-frame-pointer -mtls-dialect=gnu2 -fsection-anchors -minline-stringops-dynamically -maccumulate-outgoing-args'
if i=`_smp processor 1 || _smp 'ncpus active' 0`; then
	if [ "$i" = 1 ]; then
		f1+=' -smp -numa'
		$omp && f3+=' -fopenmp-simd'
	else
		f1+=' smp'
		$omp && f3+=' -fopenmp'
	fi
	echo "ncpu=$i"
	i=$[i+1]
	echo "ncpu1=$i"
	echo "MAKEOPTS=\"-j$i -s\""
else
	$omp && f3+=' -fopenmp-simd'
fi
case "`cat /proc/cpuinfo`" in
*GenuineTMx86*)f3="${f3/cacheline/abi} -fno-align-functions -fno-align-jumps -fno-align-loops -fno-align-labels -mno-align-stringops";;&
esac
for i in $flags; do
	i1="$i"
	case "$i" in
	sse|3dnowext)f1+=" $i mmxext";;&
	sse)[ "`_flags fpu`" = yes ] && f3+=' -mfpmath=both' || f3+=' -mfpmath=sse';;
	pni)f1+=' sse3';;
	lm)lm=true;f3+=' -fira-loop-pressure';;
	*)
		if (grep "^$i1 " /usr/portage/profiles/use.desc ; grep "^[^ 	]*:$i " /usr/portage/profiles/use.local.desc)|grep -q 'CPU\|processor\|chip\|instruction'; then
			f1+=" $i"
		else
			f2+=" $i"
		fi
	;;
	esac
done
$lm && f1+=" 64-bit-bfd" || f1+=" -64-bit-bfd"
f3=`_f $f3`
f1="${f1# }"
f2="${f2# }"
[ -n "${f1// }" ] && echo "USE=\"\$USE $f1\""
i="$f1 $f2"
i="${i//  / }"
[ -n "${i// }" ] && echo "CPU_FLAGS_X86=\"\$CPU_FLAGS_X86 $i\""
j=
if c0=`_c` && c=`_c $f0`; then
	j="$(_cmp '/cc1 -v \|/cc1 -quiet -v ' '')$(_cmp '/as ' '-Wa,')"
	[[ "$ct" == *-Q* ]] && {
		# remove all -mno-... if no matter
		j1=`echo " $j"|sed -e 's: -mno-[^ 	]*::g'`
		c1=`_c $j1`
		i=`echo " $c"|grep '^[ 	]*-'`
		i1=`echo " $c1"|grep '^[ 	]*-'`
		[ "$i" = "$i1" ] && c="$c1" && j="$j1"
	}
	i1=" $j "
	for i in $flags $cpucaps; do
		(echo "$c"|grep -q "^ *-m$i ") && [ -n "${i1##* -m$i *}" ] && j+=" -m$i" && i1+=" -m$i" && f0+=" -m$i"
	done
fi
f4="${j//--param /--param=}"
if c0=`_c $f0` && c=`_c $f4`; then
	j="$(_cmp '/as ' '-Wa,')"
	[ -n "$j" ] &&
	for i in $f4; do
		c=`_c $f0 $i` || continue
		j1="$(_cmp '/as ' '-Wa,')"
		[ -z "$j1" ] && continue
		f0+=" $i"
		[ "$j" = "$j1" ] && break
		c0="$c"
	done
fi
echo "CFLAGS_NATIVE=\"$f0\""
echo "CFLAGS_CPU=\"$f4\""
echo "CFLAGS_M=\"$f3\""
}

conf_cpu
