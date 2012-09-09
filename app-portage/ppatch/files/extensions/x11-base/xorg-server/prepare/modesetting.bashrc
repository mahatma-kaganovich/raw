sed -i -e 's:\[4\] = { "vesa", "fbdev":\[5\] = { "modesetting", "vesa", "fbdev":' "$S/hw/xfree86/common/xf86Config.c"
