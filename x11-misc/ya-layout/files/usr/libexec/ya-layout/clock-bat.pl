#!/usr/bin/perl
# (c) Denis Kaganovich, under Anarchy license
# tint2 execp for energy efficient clock & battery
# minimal

$|=1;

for(glob('/sys/class/power_supply/*/capacity')){
	open(my $F,'<',$_) || next;
	push @B,$F;
	$_=~s/.*\/(.*?)\/capacity/$1/gs;
	$b.="$_/b";
}

$md=-1;
while(1){
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime;
	if($md!=$mday){
#		use POSIX; $d=strftime('%A %e %B %Y',localtime);
		$d=localtime; $d=~s/\d\d:\d\d:\d\d *//;
		print STDERR "\x1b[2J$d\n$b";
		$md=$mday;
	}
	print sprintf("%02i:%02i\n ",$hour,$min),(map{
		my $c=readline($_);
		seek($_,0,0);
		chomp($c);
		$c?"$c% ":();
	}@B),"\n";
	sleep(60-$sec);
}
