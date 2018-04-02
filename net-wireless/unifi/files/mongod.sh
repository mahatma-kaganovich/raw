#!/bin/bash

unset LD_PRELOAD
[ -e /opt/UniFi/data/db/WiredTiger ] && set -- --wiredTigerCacheSizeGB 1 "${@}"
p="$*"
(/usr/bin/mongod --help|grep nohttpinterface) || p="${p// --nohttpinterface}"
exec /usr/bin/mongod $p
