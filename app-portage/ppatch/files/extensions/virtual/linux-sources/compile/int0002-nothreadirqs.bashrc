#
# not enough theory to submit, but sometimes threadirqs irq/power storm
sed -i -e 's:IRQF_SHARED,:IRQF_SHARED|IRQF_NO_THREAD,:' "$S"/drivers/platform/x86/intel_int0002_vgpio.c
