sed -i -e 's:param lto-partitions=:param=lto-partitions=:g' $(grep -alRF 'param lto-partitions=' "${WORKDIR}")