sed -i -e 's:TIME_UTC=1:#undef TIME_UTC\nTIME_UTC=1:' "$S/boost/thread/xtime.hpp"