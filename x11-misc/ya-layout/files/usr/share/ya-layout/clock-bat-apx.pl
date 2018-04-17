#!/usr/bin/perl
# (c) Denis Kaganovich, under Anarchy license
#
# tint2 execp for energy efficient clock & battery
# advanced (& overheaded) version with time approximation
# based on energy_full & energy_now
#
# params: [<minutes/EWMA> {[<uevent device string>]}]
# default: 5 POWER_SUPPLY_PRESENT=1
#
# 2do: deadline powersave/performance auto-tune

$|=1;

$N=shift @ARGV;
$N||=5;
for(@ARGV?@ARGV:('POWER_SUPPLY_PRESENT=1')){
	$SEL{$_}=1;
}

for(glob('/sys/class/power_supply/*/uevent')){
	my $F;
	open($F,'<',$_) || next;
	my $x;
	while(defined($x=readline($F))){
		chomp($x);
		exists($SEL{$x}) && last;
	}
	close($F);
	defined($x) || next;
	$_=~s/[^\/]*$//;

	open(my $F,'<',"$_/energy_full") || next;
	my $full=readline($F);
	close($F);
	chomp($full);

	open(my $F,'<',"$_/energy_now") || next;
	push @F,$F;
	push @FULL,$full;

	$_=~s/.*\/(.*?)\//$1/gs;
	$b.="\n$_";
}
$b="No battery found or configured" if(!@F);
$md=-1;
@NOW=@FULL;
while(1){
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime;
	if($md!=$mday){
#		use POSIX; $d=strftime('%A %x',$sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
		$d=localtime; $d=~s/\d\d:\d\d:\d\d *//;
		print STDERR "\x1b[2J$d\n$b\n";
		$md=$mday;
	}
	$i=0;
	my @res;
	for(0..$#F){
		my $now=readline($F[$_]);
		seek($F[$_],0,0);
		chomp($now);
		my $p=int($now*100/$FULL[$_]);
		my $d=$NOW[$_]-$now;
		my $r;
		if($sec>30){
			defined($rate[$_]) && last;
		}elsif($d<=0){
			$rate[$_]=undef;
		}elsif(defined($rate[$_])){
			$r=$rate[$_]=($rate[$_]*($N-1)+$d)/$N;
		}elsif($wait>10){
			$r=$rate[$_]=$d*60/$wait;
		}
		$NOW[$_]=$now;
		if($r>0){
			$r=int($now/$r);
			push @res,sprintf("%i%%-%02i:%02i",$p,$r/60,$r%60);
			next
		}elsif(defined($r)){
			$rate[$_]=0;
		}
		push @res,"$p%";

	};
	print sprintf("%02i:%02i\n",$hour,$min).join(',',@res)."\n";
	sleep($wait=60-$sec);
}
