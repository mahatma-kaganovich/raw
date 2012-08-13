sed -i -e 's:ip link set "${IFACE}":ip link set dev "${IFACE}":g' "$S/net/iproute2.sh"
