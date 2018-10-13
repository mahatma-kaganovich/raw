#!/bin/bash

## openmp: experimental for system-wide
omp=false
preferred_fp=sse
## doubts: called "unstable performance" vs "double registers"
## found: (Paolo Bonzir) Yes.  It might (*might*) be better in GCC 4.4 thanks to the new register allocator, but it's unlikely that the manual page will be changed before the release.
## upd: bashmark poor results and extremly poor in KVM
#preferred_fp=both
## empty: do not link (2x-3x faster)
code=
#code='int main(){}'

export LANG=C

ct='--help=target -v -Q'
lang=c
filter=continue
# gcc default defaults
base=

gcc=gcc
[ -z "$code" ] && gcc+=' -c'

_c(){
	$gcc $base "${@}" $ct 2>&1
}

_c1(){
	echo "$code" |$gcc -x $lang - -pipe $base "${@}" -o /dev/null 2>&1
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
	local i i0 i1
	if i0=`echo "$c0"|grep "$1"` && i=`echo "$c"|grep "$1"`; then
		for i in $i; do
			[ -z "${i##/*}" ] && continue
			for i1 in $i0; do
				[ "$i" = "$i1" ] && continue 2
			done
			echo -n " $2$i"
		done
	fi
	true
}

_cmp1(){
	c0=`_c $1` && c=`_c $2` && j="$(_cmp '/cc1 -v \|/cc1 -quiet -v ' '')$(_cmp '/as ' '-Wa,')" && [ -z "$j" ]
}

_flags(){
	grep -s "^$1[ 	]*:" /proc/cpuinfo|sort -u|sed -e "s/^$1	*: //" -e 's:,: :g'
}

_smp(){
	local i
	i=`grep "^$1[ 	]*: " /proc/cpuinfo` && i="${i##*: }" && echo $[i+$2]
}

_smp1(){
	local i x n=0 p= s= nn
	nn=$(cat /proc/cpuinfo|sed -e 's:[ 	][ 	]*: :g'|while read i; do
		x="${i##* : }"
		case "$i" in
		'')p='';s='';;
		"$1 : "*)p="$x";;
		"$2 : "*)s="$x";;
		esac
		[ -n "$p" -a -n "$s" ] && echo "$p.$s"
	done|sort -u|while read i; do
		i="${i##*.}"
		n=$[n+i]
		echo $n
	done|tail -n 1)
	[ -n "$nn" ] && echo $nn
}

_setflags(){
	local i
	for i in "${@}"; do
		export "${i// /_}"="`_flags "$i"`"
	done
}

pragma_ok(){
code="
#if$1
#error $*
#endif

$code" _c1 $2 >/dev/null
}

flag_skip(){
	local f="$1" m M x=
	shift
	case "$f" in
	-mno-*)m="${f#-mno-}";;
	-m*)m="${f#-m}";x=n;;
	*)return 1;
	esac
	M="${m^^}"
	M="${M//-/_}"
	M="${M//./_}"
	pragma_ok "ndef __${M}__" -m$m 1 && pragma_ok "def __${M}__" -mno-$m 2 && pragma_ok "${x}def __${M}__" "$*" 3
#	pragma_ok "${x}def __${M}__" "$*" 1 && pragma_ok "ndef __${M}__" "$* -m$m" 2
}

max_unrolled(){
	ffast+=" --param=max-unrolled-insns=$(($1-4)) -funroll-loops"
	# prefetching can cause code expansion. disable for low values to prefer code streaming
	ffast+=" --param=prefetch-min-insn-to-mem-ratio=$(($1+1))" # make effect of data streaming reasonable solid, related to code streaming
	ffast+=" --param=min-insn-to-prefetch-ratio=$(($1+1)) -fprefetch-loop-arrays" # gcc 6: insn_to_prefetch_ratio = (unroll_factor * ninsns) / prefetch_count;
}

conf_cpu(){
local f0= f1= f2= f3= f4= f5= fsmall= ffast= i j i1 j1 c c0 c1 lm=false fp=387 gccv m="`uname -m`" i fsec= ind=
_setflags flags cpucaps 'cpu family' model fpu vendor_id
cmn=$($gcc --help=common -v -Q 2>&1)
if i=$(echo "$cmn"|grep --max-count=1 "^Target: "); then
	# for multilib transitions: use gcc target
	i="${i#Target: }"
	case "$m:$i" in
	x86_64:i?86-*)
		m="${i%%-*}"
		echo "ARCH=\"x86\""
		echo "CHOST=\"$i\""
		echo "CBUILD=\"$i\""
	;;
	esac
fi
# "thunk" may be better in some cases, but incompatible with -mcmodel=large, so be simple universal
ind+=' -mindirect-branch=thunk-inline -mindirect-branch-register'
case "$vendor_id:$cpu_family:$model" in
GenuineIntel:6:78|GenuineIntel:6:94|GenuineIntel:6:85|GenuineIntel:6:142|GenuineIntel:6:158)
	# fixme: skylake/kabylake, nobody else?
	ind+=' -mfunction-return=thunk-inline'
;;
esac
f0=`_f -m{tune,cpu,arch}=native`
f3='-momit-leaf-frame-pointer -mtls-dialect=gnu2 -fsection-anchors'
f5='-fvisibility-inlines-hidden'
# gcc 4.9 - -fno-lifetime-dse, gcc 6.3 - around some of projects(?) - keep 6.3 only safe
# try to forget after years of upstream fixing
#f5+=' -flifetime-dse=1'
# gcc 6. oneshot clarification. must not affect legacy build
f5+=' -fpermissive -w'
# try to remove. performance
#f5+=' -fno-strict-aliasing'
# break build of few things like ghostscript-gpl & mozillas, wantfix/wantest
#fsec+=' -mmitigate-rop'
# new in gcc8 - 2test
#fsec+=' -fstack-clash-protection'
ffast+=' -malign-data=cacheline -minline-stringops-dynamically'
fsmall+=' -malign-data=abi'
if i=`_smp1 'physical id' 'cpu cores' || _smp processor 1 || _smp 'ncpus active' 0`; then
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
	echo "load_average=$[((i-2)*10+9)/10].9"
	echo "MAKEOPTS=\"-j\$ncpu1 -l\$load_average -s\""
	echo "EMERGE_DEFAULT_OPTS=\"\$EMERGE_DEFAULT_OPTS --load-average=\$load_average\""
else
	$omp && f3+=' -fopenmp-simd'
fi
# overriding package (ceph) protector
# 2do: patch over ssp patch to make default
#(echo " $cmn"|grep -q 'disable-default-ssp') && f3+=' -fstack-protector-explicit'
case "`cat /proc/cpuinfo|sed -e 's:$: :'`" in
*spectre_v2*)fsec+=" $ind";;&
*GenuineTMx86*)f3="${f3/cacheline/abi} -fno-align-functions -fno-align-jumps -fno-align-loops -fno-align-labels -mno-align-stringops";;&
*CentaurHauls*)preferred_fp=auto;;& # bashmark: C7 better 387, nothing about Nano
*AuthenticAMD*" sse "*|*AuthenticAMD*Athlon*) max_unrolled 99 ;;&
# Core2 lsd: 18 instructions
# Nehalem: lsd: 28 u-op
# Sandy Bridge: lsd: 28 u-op, decoded instruction cache: 1500
# Haswell: 2xSB + 2xLSD if HT disabled
#*GenuineIntel* avx512f *)max_unrolled 28;; # knl
#*GenuineIntel* adx *)max_unrolled 28;; # broadwell
*GenuineIntel*" avx2 "*)max_unrolled 28;; # haswell 2do: double on !HT
*GenuineIntel*" avx "*)max_unrolled 28;; # sandy bride
#*GenuineIntel*" movbe "*);; # silvermont/bonnel
*GenuineIntel*" sse4_2 "*)max_unrolled 28;; # nehalem
*GenuineIntel*" ssse3 "*)max_unrolled 18;; # core2
esac
filter=break
case "$m" in
x86_*|i?86)
	# -fschedule-insns is working (increasing registers range)
	# i?86 looks mostly working, exclude kernel
	f3+=$(_f -fira-loop-pressure -fira-hoist-pressure -flive-range-shrinkage -fsched-pressure -fschedule-insns -fsched-spec-load --param=sched-pressure-algorithm=2)
	# gnostic - don't know how to get universal default of defaults for GCC
	base="-mtune=generic -march=${m//_/-}"
	ffast+=' -maccumulate-outgoing-args'
;;
*)
	f3+=' -maccumulate-outgoing-args' # sh?
;;
esac
filter=continue
for i in $flags; do
	i1="$i"
	case "$i" in
	sse)[ "$fpu" = yes ] && fp=both || fp=sse;;&
	sse2)[ "$fpu" = yes ] && fp=$preferred_fp || fp=sse;;&
	pni)f1+=' sse3';;
	lm)lm=true;;
	sse|3dnowext)f1+=" $i mmxext";;
	fma)f2+=" $i fma3";;
	ace_en)f1+=" padlock";;
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
ffast=`_f $ffast`
fsmall=`_f $fsmall`
unroll=`_f $unroll`
f5=`lang=c++ _f $f5`
fsec=`_f $fsec`
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

i1=
c0=
for i in $f4; do
	for j in $f0; do
		[ "$i" = "$j" ] && i1+=" $i" && continue 2
	done
	if flag_skip "$i" "$i1"; then
		[ -z "$c0" ] && c0=`_c $i1`
		c=`_c $i1 $i`
		[ -z "$(_cmp '/as ' '-Wa,')" ] && continue
		c0="$c"
	fi
	i1+=" $i"
done
f4="$i1"

i1=
for i in $f4; do
	_cmp1 "$i1" "$i1 $i" && continue
	i1+=" $i"
	_cmp1 "$i1" "$f4" && continue
done
_cmp1 "$i1" "$f4" && f4="$i1"


local ff= fm=
for i in $f3; do
	case "$i" in
	-m*)fm+=" $i";;
	*)ff+="$i ";;
	esac
done

echo "CFLAGS_NATIVE=\"$f0\"
CFLAGS_CPU=\"$f4\"
CFLAGS_M=\"$fm\"
CFLAGS_FAST=\"$ffast\"
CFLAGS_SMALL=\"$fsmall\"
CFLAGS_SECURE=\"$fsec\"
_FLAGS=\"$ff\${_FLAGS}\"

CXXFLAGS=\"\${CXXFLAGS}$f5\""
}

conf_cpu
