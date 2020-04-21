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

$SIG{HUP}=sub{1};
$|=1;

$N=shift @ARGV;
$N||=5;
for(@ARGV?@ARGV:('POWER_SUPPLY_PRESENT=1')){
	my ($x,$v)=split(/=/,$_,2);
	$SEL{$x}=$v;
}

# failure may be slow [for bluetooth], refresh sometimes
sub tm{
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime($T=time());
}

sub dis{
	$_[0] eq 'Discharging';
}

sub rl{
	if(defined($_[0]=readline($F)) && ($_[1]?close($F):seek($F,0,0))){
		chomp($_[0]);
		return 1;
	}
	tm();
	close($F);
	$_[0]=$F=undef;
}

$md=-1;
while(1){
	tm();
	for(glob('/sys/class/power_supply/*/uevent')){
		exists($supp{$_})&&next;
		my ($full,$x,$v,%v,$sel,$n,$r,$st);
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

		$x=$_;
		$x=~s/\/uevent$//;
		if(($full+=0) && open($F,'<',$n="$x/energy_now")){
		}elsif(open($F,'<',$n="$x/capacity")){
			$full=100;
		}else{
			next;
		}
		if(defined($st=$v{POWER_SUPPLY_STATUS})){
			$r=0 if(dis($x));
			$st="$x/status";
		}

		$x=~s/.*\///;
		#$x=$v{POWER_SUPPLY_NAME};
		for('POWER_SUPPLY_MANUFACTURER','POWER_SUPPLY_MODEL_NAME'){
			$x.='/'.$v{$_} if(exists($v{$_}));
		}
		rl($now);
		$supp{$_}={
			F=>$F,
			FN=>$n,
			NOW=>$now,
			FULL=>$full/100,
			NAME=>$x,
			T=>$T,
			S=>$st,
			RATE=>$r,
		};
		$md=-1;
	}
	if($md!=$mday){
		@ss=sort map{defined($supp{$_})?$_:()} keys %supp;
#		use POSIX; $d=strftime('%A %x',$sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
		$d=localtime($T); $d=~s/\d\d:\d\d:\d\d *//;
		print STDERR "\x1b[2J",join("\n ",$d,map{$supp{$_}->{NAME}}@ss);
		$md=$mday;
	}
	my @res;
	for(@ss){
		my ($x,$s,$r);
		$x=$supp{$_};
		if(!(defined($F=$x->{F}) && rl($now))){
			if(!(open($F,'<',$x->{FN}) && rl($now))){
				$now=$x->{NOW};
				$s.='~';
				#delete($supp{$_});next;
			}
			$x->{F}=$F;
		}
		my $d=$x->{NOW}-$now;
		my $r1=$x->{rate};
		my $t=$T-$x->{T};
		if($t<0){
			$r=$r1;
		}elsif($d<0 || !$now){
		}elsif($t>50){
			if($d){
				$r=$d/$t;
			}elsif(defined($r1) && open($F,'<',$n) && rl($n,1) && !dis($n)){
				$r1=undef;
			}elsif(($now/($r1*3600))>168){
				# ignore >1 week (or buggy device)
				$r1=0;
			}
			$r=($r1*($N-1)+$r)/$N if(defined($r1));
		}elsif(!$r1 && $t && $d){
			$r=$d/$t;
			$s.='_';
			goto skip;
		}else{
			$r=$r1;
			goto skip;
		}
		$x->{T}=$T;
		$x->{NOW}=$now;
		$x->{rate}=$r;
skip:
		my $p=int($now/$x->{FULL});
		$s.="$p%";
		if($r>0){
			$r=int($now/($r*60));
			$s.=sprintf("-%02i:%02i",$r/60,$r%60);
		}
		push @res,$s;
	};
	print sprintf("%02i:%02i\n",$hour,$min).join(',',@res)."\n";
	sleep($wait=60-$sec);
#	select(undef,undef,undef,$wait=60-$sec);
}
