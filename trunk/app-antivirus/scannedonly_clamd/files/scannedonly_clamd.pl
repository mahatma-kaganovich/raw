#!/usr/bin/perl
$help="Redirect samba/vfs_scannedonly->clamd 0.9 (c) Denis Kaganovich, Anarchy license
Usage: $0 {path} {--<option> {<param>}}
Options:--help
";
# persistent clamd connection must be faster, but have some bugs...
#
# usual scannedonlyd_clamav daemon use internal clamav via library,
# but better to share clamd with others
# scannedonlyd_clamd.py - this is simpler for me, use more scan modes, etc
# todo: parse samba.conf

use Socket qw(:all);
use Fcntl qw(:flock);
$|=1;

%P=(
	scannedonly=>'/var/lib/scannedonly/scan',
	clamd=>'/var/run/clamav/clamd.sock',
	db=>'/var/lib/clamav',
	# default - compromise between speed & security - if clamd have no access to
	# file - send file as stream
	mode=>['MULTISCAN','INSTREAM','OK'],
	uid=>'',
	gid=>'',
	processes=>2, # 0=unlimited
	rescan=>undef, # mark viruses only, not OK. to remove false positives use bash (find -name '.virus:*'|...)
	ondemand=>undef, # rescan if db changed
	buf=>8192,
	prefix=>'', # for global "vfs objects = scannedonly ceph", etc: mount-point
	''=>[]
);
%MODE=(
	SCAN=>sub{$stream=$result=0},
	MULTISCAN=>sub{$stream=$result=0},
	INSTREAM=>sub{$stream=1;$result=0},
	OK=>sub{$result=1},
	ERROR=>sub{$result=1},
	FOUND=>sub{$result=1},
);
my ($F,$f,$d,$n,$r,$s,$SO1,$i,$j);
$i='';
for(@ARGV){
	if($_=~s/^--//){
		if(!exists($P{$i=$_})){
			print $help;
			while(($i,$j)=each %P){
				$j=join(' ',@{$j}) if(ref($j) eq 'ARRAY');
				$i && print "	--$i $j\n"
			}
			exit 1;
		}
		$P{$i}=(ref($P{$i}) eq 'ARRAY')?[]:'';
	}else{
		if(ref($P{$i}) eq 'ARRAY'){push @{$P{$i}},$_}
		else{$P{$i}=$_}
	}
}
$>=getpwnam($P{uid}) if($P{uid});
$)=getgrnam($P{gid}) if($P{gid});
if(defined($P{ondemand})){
	$d=-M ($r="$P{db}/scannedonly.rescanned");
	for(glob("$P{db}/*.cld")){undef($d) if($d > -M $_);}
	defined($d) && exit 1;
	open($F,'>',$r) || die $!;
	close($F);
	$P{rescan}='';
}
if(defined($P{rescan})){
    for $mode (@{$P{mode}}){
	print "$mode\n";
	&{$MODE{$mode}};
	# clamd skip symlinks. prepare
	%l=%ll=();
	for(@{$P{''}}){
		$_=fixdir($_);
		$l{$_}=$ll{$_}=$ll{fixdir(readlink($_))}=undef;
	}
	wild($_) for(sort keys %l);
	$stream || rescan(sort keys %l);
    }
    exit;
}

sub fixdir{
	my $d=$_[0];
	$d=~s/([^\/])\/*$/$1/;
	$d;
}

sub rescan{
	@{$P{''}}=();
	for(@_){
		$f=$_;
		$f.='/.' if(-l $f && -d $f);
		openclam($f)||die $!;
		while(<SO>){
			$_=~s/^stream:|^INSTREAM/$f:/ if($stream);
			print $_;
			if((($d,$n,$r)=$_=~/^(.*?\/)?([^\/]*?): .*?(\S*)\n$/) && $r ne 'OK' && !($n=~/^.virus:/)){
				unlink("$d.scanned:$n");
				if($r eq 'FOUND'){
					rename("$d$n","$d.virus:$n");
					open($F,'>>',"$d"."VIRUS_found_in_$n.txt") && close($F);
				}else{
					push @{$P{''}},"$d$n";
				}
			}
		}
		close(SO);
	}
}

sub rescan1{
	if(stat($_[0]) &&  -f _ &&  -s _ && open($L,'<',$_[0])){
		#flock($L,LOCK_EX|LOCK_NB) &&
		rescan($_[0]);
		close($L);
		return 1;
	}
	0;
}

# unroll symlinks in %l & restore VIRUS_* & scan INSTREAM
sub wild{
	my ($F,$i);
	if(!opendir($F,$_[0])){
		rescan1($_[0]);
		return;
	}
	my @l=readdir($F);
	closedir($F);
	for(@l){
		$_=~/^\.\.?$/ && next;
		if(($f)=$_=~/^\.virus:(.*)$/){
			my $t="$_[0]/VIRUS_found_in_$f.txt";
			unlink("$_[0]/.scanned:$f");
			$f="$_[0]/$_";
			$i="$_[0]/$f";
			if(-e $t){
				next if(-e $i);
				print "Restore: $f\n";
				rename($f,$i) || next;
				unlink($t);
				$stream && goto SCAN;
			}else{
				print "Remove: $f\n";
				unlink($f);
			}
			next;
		}
		$i="$_[0]/$_";
	SCAN:
		next if($stream && rescan1($i));
		next if(exists($ll{$i}) || !defined($l=readlink($i)) || exists($ll{$l=fixdir($l)}) || !($l=/^(?:\/|(?:.*\/)?\.?\.(?:\/.*)?)$/));
		$l{$i}=$ll{$i}==undef;
		if(-d $i){
			$ll{$l}=undef;
			wild($i)
		}
	}
}

sub opensocket{
	my ($n,$aa,$so);
	my $t=PF_INET;
	my ($a,$p)=split(/:/,$_[0],2);
	my $sock=defined($_[2])?$_[2]:SOCK_STREAM;
	my $proto=defined($_[3])?$_[3]:IPPROTO_TCP;
	if($a ne ''){
		if($p ne ''){
			(defined($aa=inet_aton($a))||defined($aa=gethostbyname($a)))&&($n=sockaddr_in($p,$aa));
		}else{
			$t=PF_UNIX;
			$n=sockaddr_un($a);
			unlink($a) if($_[1]==2 && -S $a);
			$proto=0;
		}
	}else{
		$n=sockaddr_in($p,INADDR_ANY);
	}
	return if(!defined($n));
	socket($so,$t,$sock,$proto)||return;
#	setsockopt($so,SOL_SOCKET,SO_LINGER,pack('LL',1,3600));
	# grabbed from original. required?
	my $s=pack('L',524288);
	setsockopt($so,SOL_SOCKET,SO_RCVBUF,$s);
	setsockopt($so,SOL_SOCKET,SO_SNDBUF,$s);
	if($_[1]&&setsockopt($so,SOL_SOCKET,SO_REUSEADDR,pack("l",1))&&bind($so,$n)){
		listen($so,SOMAXCONN);
		return $so;
	}
	return $so if($_[1]<2 && connect($so,$n));
	close($so);
	return;
}

{
package result;
sub TIEHANDLE{return bless{r=>$_[1]}};
sub READLINE{delete($_[0]->{r})}
sub CLOSE{};
}

sub openclam{
	if($result){
		tie(*SO,'result',($stream?'stream':$_[0]).": $mode\n");
		return 1;
	}
	*SO=opensocket($P{clamd}) || return;
	if($stream){
		syswrite(SO,"n$mode\n") || return;
		while(my $l=read($L,$s,$P{buf})){
			syswrite(SO,pack("N",$l))||return 1;
			syswrite(SO,$s);
		}
		syswrite(SO,pack("N",0))||return;
	}else{
		syswrite(SO,"n$mode $_[0]\n") || return;
	}
	return 1;
}

*SO1=opensocket($P{scannedonly},2,SOCK_DGRAM,IPPROTO_UDP) || die $!;
$SIG{CHLD}='IGNORE';
for(2..$P{processes}){fork||last};
while($f=<SO1>){
	chomp($f);
	$f=$P{prefix}.$f;
	open($L,'<',$f) || next;
	# reduce vfs overhead (but keep some)
	if(flock($L,LOCK_EX|LOCK_NB) && (($d,$n)=$f=~/^(.*\/)(.*?)$/) && ! -e "$d.scanned:$n" && ! -e "$d.virus:$n" && ($P{processes} || !fork)){
	    for $mode (@{$P{mode}}){
		&{$MODE{$mode}};
		$next=0;
		if(openclam($f)){
			$s=$stream?'stream: ':"$f: ";
			while(<SO>){
#				print $_;
				next if(substr($_,0,length($s),'') ne $s);
				if($_ eq "OK\n"){
					open($F,'>>',"$d.scanned:$n") && close($F);
				}elsif($_=~s/FOUND\n$//){
					rename($f,"$d.virus:$n");
					open($F,'>>',$d."VIRUS_found_in_$n.txt") && close($F);
				}else{
					print STDERR $_;
					$next++;
				}
			}
		}
		close(SO);
		$next && next;;
		$P{processes} || exit;
		last;
	    }
	}
	close($L);
}
close(SO1);
