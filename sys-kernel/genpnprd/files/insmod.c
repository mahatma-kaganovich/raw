#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <fcntl.h>
extern long init_module(void *, unsigned long, const char *);
int main(int argc, char *argv[]){
	if (argc<2) return 1;
	int f = open(argv[1], 0, 0), i, l = argc+1;
	if (f<0) return 1;
	off_t len = lseek(f, 0, 2);
	lseek(f, 0, 0);
	for (i=2; i<argc; i++) l+=strlen(argv[i]);
	char *buf = malloc(len+l), *opt = buf+len;
	for (i=2; i<argc; i++){strcat(opt,argv[i]);strcat(opt," ");}
	opt[l] = '\0';
	return read(f,buf,len)==len?init_module(buf,len,opt):1;
}
