[[ "${CFLAGS##*-march=}" == native* ]] && (grep "^flags" /proc/cpuinfo|grep -qw hle) && {
	echo "Detected and native enabling lock elision"
	export enable_lock_elision=yes
}
