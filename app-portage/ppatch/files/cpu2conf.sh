#!/bin/bash

_c(){
	LANG=C gcc "${@}" --help=target -v 2>&1
}

_f(){
	local i
	for i in "${@}"; do
		c=`_c $i` || continue
		(echo "$c" | grep -sq " warning: .* is deprecated") && continue
		echo -n " $i"
	done
}

conf_cpu(){
local flags f0= f1= f2= f3= i j i1 c
flags=`grep -s "^flags	" /proc/cpuinfo|sort -u`
flags="${flags#*:}"
f0=`_f -m{tune,cpu,arch}=native`
f3=`_f -malign-data=cacheline -momit-leaf-frame-pointer -mtls-dialect=gnu2`
echo "CFLAGS_NATIVE=\"$f0\""
for i in $flags; do
	i1="$i"
	case "$i" in
	sse|3dnowext)f1+=" $i mmxext";;
	pni)f1+=" sse3";;
	*)
		if (grep "^$i1 " /usr/portage/profiles/use.desc ; grep "^[^ 	]*:$i " /usr/portage/profiles/use.local.desc)|grep -q 'CPU\|processor\|chip\|instruction'; then
			f1+=" $i"
		else
			f2+=" $i"
		fi
	;;
	esac
done
f1="${f1# }"
f2="${f2# }"
[ -n "${f1// }" ] && echo "USE=\"\$USE $f1\""
i="$f1 $f2"
i="${i//  / }"
[ -n "${i// }" ] && echo "CPU_FLAGS_X86=\"\$CPU_FLAGS_X86 $i\""
i="/cc1 -quiet -v help-dummy "
j=
if c=`_c $f0`; then
	if j=`echo "$c"|grep -F "$i"`; then
		j="${j#*$i}"
		j="${j% -quiet *}"
		if i=`echo "$c"|grep -F "/as "`; then
			i="${i#* -mtune=}"
			i="${i%% *}"
			j="$j -Wa,-mtune=$i"
		fi
	fi
	i1=" $j "
	for i in $f3; do
		(echo "$c"|grep -q "^ *-m$1 ") && [ -n "${j## -m$i }" ] && j+=" -m$i"
	done
fi
echo "CFLAGS_CPU=\"${j+ $j}\""
echo "CFLAGS_M=\"$f3\""
if i=`grep "^processor[ 	]*: " /proc/cpuinfo`; then
	i="${i##*: }"
	i=$[i+1]
	echo "ncpu=$i"
	i=$[i+1]
	echo "ncpu1=$i"
	echo "MAKEOPTS=\"-j$i -s\""
fi
}

conf_cpu
