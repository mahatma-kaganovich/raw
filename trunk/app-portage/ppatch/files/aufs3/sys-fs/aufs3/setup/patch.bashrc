patch(){
	local i="$*"
	(use !kernel-patch && use !fuse && [ -z "${i##*-d $KV_DIR*}" ]) || /usr/bin/patch "${@}"
}
