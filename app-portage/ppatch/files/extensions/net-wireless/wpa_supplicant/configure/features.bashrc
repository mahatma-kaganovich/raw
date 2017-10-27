i='AUTOSCAN_EXPONENTIAL AUTOSCAN_PERIODIC FST HT_OVERRIDES VHT_OVERRIDES IEEE80211N IEEE80211AC'
# epoll possible broken with dbus, but not confirmed
[[ "$IUSE" == *epoll* ]] || i+=' ELOOP_EPOLL'
for i in $i; do
	export CFLAGS="$CFLAGS -DCONFIG_$i=y"
	sed -i -e "s:^#CONFIG_$i=:CONFIG_$i=:" "$S/"*config
done
