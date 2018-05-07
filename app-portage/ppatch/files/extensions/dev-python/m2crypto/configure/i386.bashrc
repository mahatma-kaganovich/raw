
# vs. hybrid 64/32 bit
[[ "${CTARGET:-$CHOST}" == i?86* ]] && sed -i -e "s:platform.machine().lower():'i386':" "$S"/setup.py
