#!/bin/bash

export LANG=C

D="$(pwd)/_auto"

V=2_7
V1='3_4 3_5'
V2='\([^2]_.\|2_[^7]\)'

p="python$V
$(cd /usr/portage && for i in *-*/*; do
	[ -d "$i" ] || continue
	grep -sqF python_single_target_python metadata/md5-cache/$i-* || continue
	grep -sqF python_single_target_python$V metadata/md5-cache/$i-* && continue
	echo -n "$i " >&2
	for v in $V1; do
		grep -sqF python_single_target_python$v metadata/md5-cache/$i-* && echo python$v && echo python_single_target_python$v >&2 && continue 2
	done
	echo "# $(grep -ho "python_single_target_python$V2" metadata/md5-cache/$i-*)"
done 2>"$D/package.use"|sort -u)"

echo "PYTHON_TARGETS=\"$(echo $p\)"
PYTHON_SINGLE_TARGET=\"python$V\"" >"$D/make.defaults"
