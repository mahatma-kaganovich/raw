[ "$EBUILD_PHASE" = prepare ] && [[ "$CFLAGS$CFLAGS_BASE" == *-fschedule-insns* ]] && {
	sed -i '1i #pragma GCC optimize ("no-schedule-insns")' "$WORKDIR"/*/texk/ttfdump/libttf/cmap.c
	sed -i '1i #if defined(__i386__)\n#pragma GCC optimize ("no-schedule-insns")\n#endif' "$S"/{drivers/net/ethernet/qlogic/netxen/netxen_nic_hw.c,drivers/net/ethernet/qlogic/qlcnic/qlcnic_hw.c,drivers/gpu/drm/nouveau/nvkm/subdev/mmu/gf100.c}
	true
} 2>/dev/null
