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
	grep -s "^$1	" /proc/cpuinfo|sort -u|sed -e "s/^$1	: //" -e 's:,: :g'
}

conf_cpu(){
local flags cpucaps f0= f1= f2= f3= i j i1 c
flags=$(_flags flags)
cpucaps=$(_flags cpucaps)
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
j=
if c0=`_c` && c=`_c $f0`; then
	j="$(_cmp '/cc1 -quiet -v ' '')$(_cmp '/as ' '-Wa,')"
	i1=" $j "
	for i in $flags $cpucaps; do
		(echo "$c"|grep -q "^ *-m$i ") && [ -n "${i1##* -m$i *}" ] && j+=" -m$i" && i1+=" -m$i"
	done
fi
echo "CFLAGS_CPU=\"$j\""
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
