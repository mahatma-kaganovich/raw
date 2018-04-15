#!/usr/bin/perl
# tint2 execp for energy efficient clock & battery

$|=1;

for(glob('/sys/class/power_supply/*/capacity')){
	my $F;
	open($F,'<',$_) || next;
	push @B,$F;
	$_=~s/.*\/(.*?)\/capacity/$1/gs;
	print STDERR "$_\n";
}
my $dc=@B?" ":"\n";

while(1){
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
	print sprintf("%02i/%02i#%i$dc%02i:%02i\n",$mon,$mday,$wday,$hour,$min),(map{
		seek($_,0,0);
		my $c=readline($_);
		chomp($c);
		$c?"$c% ":();
	}@B),"\n";
	sleep(60-$sec);
}
