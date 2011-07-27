#include <stdlib.h>
#include <unistd.h>
#include <string.h>
extern long init_module(void *, unsigned long, const char *);
int main(int argc, char *argv[]){
	int f = open(argv[1], 0, 0), i, l = argc;
	off_t len = lseek(f, 0L, SEEK_END);
	char *buf = malloc(len), *opt;
	lseek(f, 0L, SEEK_SET);
	for (i=2; i<argc; i++) l+=strlen(argv[i]);
	opt=malloc(l);
	*opt=0;
	for (i=2; i<argc; i++){strcat(opt,argv[i]);strcat(opt," ");}
	return (buf && opt && read(f,buf,len)==len)?init_module(buf,len,opt):0;
}
