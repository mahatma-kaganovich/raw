int main(int argc, char *argv[]){
	int i;
	for (i=1; i<argc; i++) delete_module(argv[i], 0);
}
