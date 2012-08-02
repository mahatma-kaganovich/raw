sed -i -e 's:GNULIB_GETS=1:GNULIB_GETS=0:' `grep -lRF GNULIB_GETS=1 "$S"`
