
# I have Haswell model 79 with updated microcode 0xb00001f, host is OK, but in guest app-benchmarks/bashmark segfaulting

[[ "${CFLAGS##*-march=}" == native* ]] && (grep "^flags" /proc/cpuinfo|grep -qw hle) && ! (grep "^flags" /proc/cpuinfo|grep -qw hypervisor) && {
	echo "Detected and native enabling lock elision"
	export enable_lock_elision=yes
}
