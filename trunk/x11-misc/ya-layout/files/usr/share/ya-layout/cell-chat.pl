#!/usr/bin/perl
# simple auto chat for cdma|gsm
# (c) Denis Kaganovich, under Anarchy or GPLv2 license

my ($TIMEOUT,$PHONE,$APN)=@ARGV;
$|=1;

sub pr{
	my ($s,$r)=@_;
	print $s."\r\n";
	$r||return;
	$s='';
	while(defined(my $c=getc(STDIN))){
		print STDERR $c;
		$s.=$c;
		while(my ($x,$y)=each %$r){
			return $y if($s=~/$x/m);
		}
	}
	die;
}

sub ok{
	pr($_[0],{'^OK'=>1,'^ERROR'=>0});
}

sub dial{
	pr('atd'.$_[0],{'^CONNECT'=>1,'^ERROR'=>0,'^NO '=>0,'^BUSY'=>0}) && exit;
}


alarm($TIMEOUT);
ok('athz',1)||ok('+++athz')||die;
my $s;
if($APN ne ''){
	for my $c (',1,1',',1,0',',0,1','',',0,0'){
		break if($gsm=ok("AT+CGDCONT=1,\"IP\",\"'$APN'\",\"\"$c"));
	}
}
dial($PHONE) || exit 1 if($PHONE ne '');

#if(!$gsm){
#	if(ok('AT$QCQNC?')){
#		$cdma=1;
#	}else{
#		$gsm=1
#	}
#}

if(!$cdma && !$gsm){
	if(ok('AT+CGDCONT?')){
		$gsm=1
	}else{
		$cdma=1;
	}
}

dial('*99#') if($gsm || !$cdma);
dial('#777') if($cdma || !$gsm);

exit 1;
