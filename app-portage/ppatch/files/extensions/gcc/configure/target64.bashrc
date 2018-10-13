
# old, now default
#[[ "${CTARGET:-$CHOST}" == i?86* ]] && export enable_targets=all

# force tiny code for rare 32bit-only hosts
[[ "${CTARGET:-$CHOST}" == i?86* ]] &&
([[ "${CFLAGS##*-march=}" == native* ]] || [[ "${CPPFLAGS##*-march=}" == native* ]]) &&
use !multilib &&
! grep -qw lm /proc/cpuinfo &&
sed -i -e 's:enable_targets = xall:enable_targets = x_all:' "$S/gcc/config.gcc"
