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

$N=((shift @ARGV)||5)*60;
%SEL=(POWER_SUPPLY_PRESENT=>1,) if(!@ARGV);
for(@ARGV){
	my ($x,$v)=split(/=/,$_,2);
	$SEL{$x}=$v;
}


# failure may be slow [for bluetooth], refresh sometimes
sub tm{
	$T=time();
	$sec=$T%60;
	$min=int($T/60);
	return if($min==$min1); $min1=$min;
	$TD=localtime($T);
	$TD=~s/(\d\d:\d\d):\d\d */$TM=$1;''/e;

#	use POSIX;
#	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime($T);
#	$TM=strftime('%X',$sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
#	$TM=~s/:\d\d( .*)?$/$1/;
#	return if($mday==$mday1); $mday1=$mday;
#	$TD=strftime('%A %x',$sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
#	utf8::encode($TD);
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

while(1){
	tm();
	for(glob('/sys/class/power_supply/*/uevent')){
		exists($supp{$_})&&next;
		my ($full,$x,$v,%v,$sel,$n,$r,$st);
		open($F=my $F_,'<',$_) || next;
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
		if(($full/=100) && open($F=my $F_,'<',$n="$x/energy_now")){
		}elsif(open($F=my $F_,'<',$n="$x/capacity")){
			$full=1;
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
			FULL=>$full,
			NAME=>$x,
			T=>$T,
			S=>$st,
			RATE=>$r,
		};
		$md='';
	}
	if($md ne $TD){
		@ss=sort map{defined($supp{$_})?$_:()} keys %supp;
		print STDERR "\x1b[2J".join("\n ",$md=$TD,map{$supp{$_}->{NAME}}@ss);
	}
	my @res;
	for(@ss){
		my ($x,$s,$r);
		my $sp='-';
		$x=$supp{$_};
		if(!(defined($F=$x->{F}) && rl($now))){
			if(!(open($F=my $F_,'<',$x->{FN}) && rl($now))){
				#delete($supp{$_});next;
				$now=$x->{NOW};
				$s.='~';
			}
			defined($x->{F}=$F)||goto skip;
		}
		my $d=$x->{NOW}-$now;
		my $r1=$x->{rate};
		my $t=$T-$x->{T};
		if($t<=0){
			$r=$r1;
		}elsif($d<0 || !$now){
		}elsif(defined($r1)){
			if($d || (defined(my $f=$x->{S}) && open($F=my $F_,'<',$f) && rl($f,1) && dis($f))){
				my $n=$x->{t};
				$n=$N if($n<$N);
				$n+=$t if($n<=$t);
				$r=($r1*($n-$t)+$d)/$n;
				if(!$d){ # or $d<2
					#$r=$r1;
					$sp='~';
					goto skip;
				}
			}
		}elsif($d){
			$r=$d/$t;
			$sp='~';
		}
		$x->{T}=$T;
		$x->{NOW}=$now;
		$x->{rate}=$r;
		$x->{t}=$t;
skip:
		my $p=int($now/$x->{FULL});
		$s.="$p%";
		if($r){
			$r=int($now/60/$r);
			$s.=$sp.sprintf("%02i:%02i",$r/60,$r%60);
		}
		push @res,$s;
	};
	print $TM."\n".join(',',@res)."\n";
	sleep($wait=60-$sec);
#	select(undef,undef,undef,$wait=60-$sec);
}
