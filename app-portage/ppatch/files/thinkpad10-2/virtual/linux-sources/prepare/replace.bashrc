
_replace(){
	[ -e "$S/$2"1 ] && return
	mv "$S/$2"{,1} &&
	cp "$PPATCH/virtual/linux-sources/prepare/$1" "$S/$2"
}

_replace acpi-tpt10-battery.c drivers/acpi/battery.c
