x='	local KV;KV=`uname -r` \&\& [ -L "/lib/modules/$KV/kernel" ] \&\& ! grep -qF " /usr/src/linux-$KV " /proc/mounts \&\& mount -t squashfs -v -o ro,loop,noatime /usr/src/linux-"$KV"{.squashfs,} || true'
grep -F "local KV;" "$S/init.d/udev" || sed -i -e "/^start_pre()/{$!{N;s:{:{\n$x:}}" "$S/init.d/udev"
grep -F "local KV;" "$S/init.d/udev" || die "Unable to patch '/etc/init.d/udev', please
fix or remove /usr/ppatch/sys-fs/udev-init-scripts/prepare/mnt-kernel.bashrc"
