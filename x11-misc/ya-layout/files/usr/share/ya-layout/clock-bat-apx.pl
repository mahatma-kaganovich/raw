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
	my ($x,$v)=split(/=/,$_,2);
	$SEL{$x}=$v;
}

$md=-1;
while(1){
	for(glob('/sys/class/power_supply/*/uevent')){
		exists($supp{$_})&&next;
		my ($F,$full,$x,$i,$v,%v,$sel,$n);
		open($F,'<',$_) || next;
		while(defined($x=readline($F))){
			chomp($x);
			($x,$v)=split(/=/,$x,2);
			$v{$x}=$v;
		}
		close($F);

		if(!(defined($full=$v{POWER_SUPPLY_ENERGY_FULL})||
		    exists($v{POWER_SUPPLY_CAPACITY}))){
			$supp{$_}=undef;
			next;
		}

		while (($x,$v)=each %SEL){
			$sel||=exists($v{$x}) && $v{$x} eq $v;
		}
		$sel||next;
		$supp{$_}=undef;
		$_=~s/\/uevent$//;

		if(defined($full) && open($F,'<',"$_/energy_now")){
		}elsif(open($F,'<',"$_/capacity")){
			$full=100;
		}else{
			next;
		}

		$_=~s/.*\///;
		$x=$_;
		#$x=$v{POWER_SUPPLY_NAME};
		for('POWER_SUPPLY_MANUFACTURER','POWER_SUPPLY_MODEL_NAME'){
			$x.='/'.$v{$_} if(exists($v{$_}));
		}
		$i=scalar(@F);
		$F[$i]=$F;
		$NOW[$i]=
		$FULL[$i]=$full;
		$NAME[$i]=$x;
		$md=-1;
	}
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime;
	if($md!=$mday){
#		use POSIX; $d=strftime('%A %x',$sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
		$d=localtime; $d=~s/\d\d:\d\d:\d\d *//;
		print STDERR "\x1b[2J",join("\n ",$d,@NAME);
		$md=$mday;
	}
	my @res;
	for(0..$#F){
		my $now=readline($F[$_]);
		seek($F[$_],0,0);
		chomp($now);
		my $d=$NOW[$_]-$now;
		my $r;
		my $r1=$rate[$_];
		if($sec>30){
			defined($r1) && last;
		}elsif($d<=0){
		}elsif(defined($r1)){
			$r=($r1*($N-1)+$d)/$N;
		}elsif($wait>10){
			$r=$d*60/$wait;
		}
		$rate[$_]=$r;
		$NOW[$_]=$now;
		my $p=int($now*100/$FULL[$_]);
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
