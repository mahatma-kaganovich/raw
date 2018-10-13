
# now I get segfaults on app-benchmarks/bashmark on E5-2650 v4
# so, keep it experemental while

# kvm app-benchmarks/bashmark segfault
# ! (grep "^flags" /proc/cpuinfo|grep -qw hypervisor) &&
( [[ "${CFLAGS##*-march=}" == native* ]] || [[ "${CFLAGS_BASE##*-march=}" == native* ]] || [[ "${CPPFLAGS##*-march=}" == native* ]]) && (grep "^flags" /proc/cpuinfo|grep -qw hle) && {
	echo "Detected and native enabling lock elision"
	export enable_lock_elision=yes
}
