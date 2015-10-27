#!/bin/bash

# openmp: experimental for system-wide
omp=false

export LANG=C

_c(){
	gcc "${@}" --help=target -v 2>&1
}

_c1(){
	echo 'void main(){}'|gcc -x c - "${@}" -o /dev/null 2>&1
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
	if i0=`echo "$c0"|grep -F "$1"` &&  i=`echo "$c"|grep -F "$1"`; then
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
local flags cpucaps f0= f1= f2= f3= i j i1 c
flags=$(_flags flags)
cpucaps=$(_flags cpucaps)
f0=`_f -m{tune,cpu,arch}=native`
f3='-malign-data=cacheline -momit-leaf-frame-pointer -mtls-dialect=gnu2 -fsection-anchors -minline-stringops-dynamically -maccumulate-outgoing-args -fsched-pressure -fsched-spec-load'
if i=`_smp processor 1 || _smp 'ncpus active' 0`; then
	if [ "$i" = 1 ]; then
		f1+=' -smp'
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
for i in $flags; do
	i1="$i"
	case "$i" in
	lm)f3+=' -fschedule-insns --param=sched-pressure-algorithm=2';;
	sse|3dnowext)f1+=" $i mmxext";;&
	sse)[ "`_flags fpu`" = yes ] && f3+=' -mfpmath=both' || f3+=' -mfpmath=sse';;
	pni)f1+=' sse3';;
	*)
		if (grep "^$i1 " /usr/portage/profiles/use.desc ; grep "^[^ 	]*:$i " /usr/portage/profiles/use.local.desc)|grep -q 'CPU\|processor\|chip\|instruction'; then
			f1+=" $i"
		else
			f2+=" $i"
		fi
	;;
	esac
done
f3=`_f $f3`
f1="${f1# }"
f2="${f2# }"
[ -n "${f1// }" ] && echo "USE=\"\$USE $f1\""
i="$f1 $f2"
i="${i//  / }"
[ -n "${i// }" ] && echo "CPU_FLAGS_X86=\"\$CPU_FLAGS_X86 $i\""
j=
if c0=`_c` && c=`_c $f0`; then
	j="$(_cmp '/cc1 -quiet -v ' '')$(_cmp '/as ' '-Wa,')"
	i1=" $j "
	for i in $flags $cpucaps; do
		(echo "$c"|grep -q "^ *-m$i ") && [ -n "${i1##* -m$i *}" ] && j+=" -m$i" && i1+=" -m$i" && f0+=" -m$i"
	done
fi
echo "CFLAGS_NATIVE=\"$f0\""
echo "CFLAGS_CPU=\"${j//--param /--param=}\""
echo "CFLAGS_M=\"$f3\""
}

conf_cpu
