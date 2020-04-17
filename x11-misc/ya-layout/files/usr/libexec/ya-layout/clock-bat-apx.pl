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

$md=-1;
while(1){
	my $T=time();
	for(glob('/sys/class/power_supply/*/uevent')){
		exists($supp{$_})&&next;
		my ($F,$full,$x,$v,%v,$sel,$n);
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
		if(defined($full) && open($F,'<',$n="$x/energy_now")){
		}elsif(open($F,'<',$n="$x/capacity")){
			$full=100;
		}else{
			next;
		}

		$x=~s/.*\///;
		#$x=$v{POWER_SUPPLY_NAME};
		for('POWER_SUPPLY_MANUFACTURER','POWER_SUPPLY_MODEL_NAME'){
			$x.='/'.$v{$_} if(exists($v{$_}));
		}
		$supp{$_}={
			F=>$F,
			FN=>$n,
			FULL=>$full/100,
			NAME=>$x,
			T=>$T,
		};
		$md=-1;
	}
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime($T);
	if($md!=$mday){
		@ss=sort map{defined($supp{$_})?$_:()} keys %supp;
#		use POSIX; $d=strftime('%A %x',$sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
		$d=localtime($T); $d=~s/\d\d:\d\d:\d\d *//;
		print STDERR "\x1b[2J",join("\n ",$d,map{$supp{$_}->{NAME}}@ss);
		$md=$mday;
	}
	my @res;
	for(@ss){
		my ($x,$now,$s,$F);
		$x=$supp{$_};
		$now=readline($F) if(defined($F=$x->{F}));
		if(!defined($now)){
			defined($F) && close($F);
			if(open($F,'<',$x->{FN})){
				$now=readline($F);
			}else{
				$F=undef;
				$now=$x->{NOW};
				$s.='~';
			}
			$x->{F}=$F;
		}
		my $d=$x->{NOW}-$now;
		my $r;
		my $r1=$x->{rate};
		my $t=$T-$x->{T};
		if($t<0 || $d<0){
			$x->{T}=$T;
			$x->{NOW}=$now;
			$x->{rate}=$r;
		}elsif($t>50){
			$r=$d/$t;
			$r=($r1*($N-1)+$r)/$N if(defined($r1));
			$x->{T}=$T;
			$x->{NOW}=$now;
			$x->{rate}=$r;
		}elsif(!$r1 && $t && $d){
			# fast unprecise
			$r=$d/$t;
			$s.='_';
		}else{
			$r=$r1;
		}
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
