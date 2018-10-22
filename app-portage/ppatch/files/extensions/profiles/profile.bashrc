
# jobserver not used in 90% builds, just set number of cpus from make.conf
for i in {C,CXX,CPP,LD,F,FC,_}FLAGS; do
	[ -v $i ] && export $i="${!i//-flto=jobserver/-flto=${ncpu:-1}}"
done
unset i
