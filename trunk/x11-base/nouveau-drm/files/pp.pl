#!/usr/bin/perl

while(defined(my $s=readline(STDIN))){
	if(index($s,'--- a/dev/null')==0){
		my $s1=readline(STDIN);
		$s=$s1;
		$s1=~s/^\+\+\+ b/--- a/;
		print $s1;
	}
	print $s;
}