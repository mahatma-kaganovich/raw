use custom-cflags && use speculative && export CFLAGS+=' -DCONFIG_MMAP_ALLOW_UNINITIALIZED=y' ||
	ewarn "MMAP UNINITIALIZED required USE custom-cflags & speculative"
# todo: in patch form

