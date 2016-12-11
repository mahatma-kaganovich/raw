#!/bin/bash

cd /usr/portage || exit 1
export LANG=C

for i in *-*/*; do
	[ -d "$i" ] || continue
	grep -sq REQUIRED_USE metadata/md5-cache/$i-* || continue
#	echo $i >>log
	x=`emerge -p "$i" --nodeps 2>&1`
	[[ "$x" == *REQUIRED_USE* ]] || continue
	[[ "$x" == *python3_4* ]] && {
		PYTHON_SINGLE_TARGET='python3_4' emerge -p "$i" --nodeps 2>&1|grep -q REQUIRED_USE || continue
	}
	x="${x##*unsatisfied:
}"
	x="${x%%
*}"
	echo "$i $x"
done
