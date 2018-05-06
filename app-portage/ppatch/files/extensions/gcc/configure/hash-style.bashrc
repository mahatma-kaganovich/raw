case "${LDFLAGS##*--hash-style=}" in
gnu*)export with_linker_hash_style=gnu;;
sysv*)export with_linker_hash_style=sysv;;
esac
