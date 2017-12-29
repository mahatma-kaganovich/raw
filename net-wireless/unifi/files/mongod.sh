#!/bin/bash

unset LD_PRELOAD
[ -e /opt/UniFi/data/db/WiredTiger ] && set -- --wiredTigerCacheSizeGB 1 "${@}"
exec /usr/bin/mongod "${@}"
