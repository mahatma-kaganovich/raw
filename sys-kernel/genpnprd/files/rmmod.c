extern long delete_module(const char *name, int flags);
int main(int argc, char *argv[]){
	int i;
	for (i=1; i<argc; i++) delete_module(argv[i], 0);
}
