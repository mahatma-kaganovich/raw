#!/bin/bash

# openmp: experimental for system-wide
omp=false
#preferred_fp=sse
## doubts: called "unstable performance" vs "double registers"
## found: (Paolo Bonzir) Yes.  It might (*might*) be better in GCC 4.4 thanks to the new register allocator, but it's unlikely that the manual page will be changed before the release.
preferred_fp=both

export LANG=C

ct='--help=target -v -Q'
lang=c
filter=continue

_c(){
	gcc "${@}" $ct 2>&1
}

_c1(){
	echo 'int main(){}'|gcc -x $lang - -pipe "${@}" -o /dev/null 2>&1
}

_f(){
	local i
	for i in "${@}"; do
		c=`_c1 $i` || $filter
		(echo "$c" | grep -q " warning: .* is deprecated\|warning: this target does not support" ) && $filter
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
local flags cpucaps f0= f1= f2= f3= f5= i j i1 j1 c c0 c1 lm=false fp=387
flags=$(_flags flags)
cpucaps=$(_flags cpucaps)
f0=`_f -m{tune,cpu,arch}=native`
f3='-malign-data=cacheline -momit-leaf-frame-pointer -mtls-dialect=gnu2 -fsection-anchors -minline-stringops-dynamically -maccumulate-outgoing-args'
# gcc 4.9 - -fno-lifetime-dse, gcc 6.3 - -flifetime-dse=1 - around some of projects(?) - keep 6.3 only safe
f5='-fvisibility-inlines-hidden -flifetime-dse=1'
# gcc 6. oneshot clarification. must not affect legacy build
f5+' -fpermissive -fno-strict-aliasing -w'
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
filter=break
case "`uname -m`" in
x86_*|i?86)f3+=$(_f -fira-loop-pressure -flive-range-shrinkage -fsched-pressure -fschedule-insns --param=sched-pressure-algorithm=2);;&
esac
filter=continue
for i in $flags; do
	i1="$i"
	case "$i" in
	sse)[ "`_flags fpu`" = yes ] && fp=$preferred_fp || fp=sse;;&
	pni)f1+=' sse3';;
	lm)lm=true;;
	sse|3dnowext)f1+=" $i mmxext";;
	fma)f2+=" $i fma3";;
	*)
		if (grep "^$i1 " /usr/portage/profiles/use.desc ; grep "^[^ 	]*:$i " /usr/portage/profiles/use.local.desc)|grep -q 'CPU\|processor\|chip\|instruction'; then
			f1+=" $i"
		else
			f2+=" $i"
		fi
	;;
	esac
done
f3+=" -mfpmath=$fp"
$lm && f1+=" 64-bit-bfd" || f1+=" -64-bit-bfd"
f3=`_f $f3`
f5=`lang=c++ _f $f5`
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
echo "CFLAGS_NATIVE=\"$f0\"
CFLAGS_CPU=\"$f4\"
CFLAGS_M=\"$f3\"

CXXFLAGS=\"\${CXXFLAGS}$f5\""
}

conf_cpu
