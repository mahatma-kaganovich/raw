ldd /usr/lib/gegl-0.4/raw-load.so /usr/lib/gegl-0.4/ff-save1.so|grep -Fq /libgomp. && export LD_PRELOAD=libgomp.so
# gnu2 ?
