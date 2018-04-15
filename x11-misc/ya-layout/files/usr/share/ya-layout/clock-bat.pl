#!/usr/bin/perl
# tint2 execp for energy efficient clock & battery

$|=1;

for(glob('/sys/class/power_supply/*/capacity')){
	open(my $F,'<',$_) || next;
	push @B,$F;
	$_=~s/.*\/(.*?)\/capacity/$1/gs;
	$b.="\n$_";
}

$md=-1;
while(1){
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
	print sprintf("%02i:%02i\n",$hour,$min),(map{
		seek($_,0,0);
		my $c=readline($_);
		chomp($c);
		$c?"$c% ":();
	}@B),"\n";
	if($md!=$mday){
		print STDERR "\x1b[2J".localtime.$b;
		$md=$mday;
	}
	sleep(60-$sec);
}
