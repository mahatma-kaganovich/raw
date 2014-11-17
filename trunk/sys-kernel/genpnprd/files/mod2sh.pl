#!/usr/bin/perl
# modules.alias & modules.dep -> modules.alias.sh & modules.pnp
# for syspnp modules pnp loader
# (c) Denis Kaganovich
# under Anarchy license

my %alias;
my %dep;
my %ord3;
my %OPT=(
	'subst'=>1,
	'barrier'=>3, # separate concurrent from precursors (precursors have too many siblings)
	'order'=>3,
	'sed'=>1,
);

my @order=(\&order3,\&order1,\&order2,\&order3);

# to load second/last
my @reorder=(
 '/ide/|usb-storage|/oss/|/video/|/snd-pcsp|/pata_acpi|/ata_generic',
);

my $noreorder='/drm/';

sub read_aliases{
	my ($s,$id,$m);
	open FA,$_[0] || return;
	while(defined($s=<FA>)){
		chomp($s);
		$s=~s/^alias\s(.*)\s(\S*)$/$id=$1;$m=$2;""/e;
		defined($id)||next;
		push @{$alias{$_}},$m for (lines($id));
	}
	close FA;
}

sub read_deps{
	my $s;
	open FD,$_[0] || return;
	while(defined($s=<FD>)){
		chomp($s);
		my $id=$s;
		$id=~s/.*\/(.*?)\..*?:.*/$1/;
		$s=~s/://;
		for $id (lines($id)){
		for my $i (split(/ /,$s)){
			for(@{$dep{$id}}){
				if($_ eq $i){
					$i='';
					last;
				}
			}
			unshift @{$dep{$id}},$i if($i ne '');
		}
		}
	}
	close FD;
}

sub read_modinfo{
	my ($id,$m,$i,$s,%v);
	open FM,"modinfo `find $_[0] -name '*.ko' -print|sort`|" || return;
	while(defined($s=<FM>)||exists($v{filename})){
		chomp($s);
		my ($x,$y);
		$s=~s/^(\S*):[ 	]*(.*?)$/$x=$1;$y=$2;/e;
		if(exists($v{filename}) && $x ne "filename"){
			push @{$v{$x}},$y;
			next if(defined($s));
		}
		$id=$m=pop @{$v{filename}};
		substr($m,0,length($_[0])+1)='';
		$id=~s/.*\/(.*?)\..*?$/$1/;
		$s=~s/://;
		$id=lines_($id);
		for $i (lines($id)){
			for(@{$v{depends}}){
				for(lines($_)){
					push @{$dep{$i}},split(/,/,$_);
				}
			}
			($m ne '') && push @{$dep{$i}},$m;
		}
		for(@{$v{alias}}){
			for(lines($_)){
				push @{$alias{$_}},$id;
			}
		}
		%v=();
		push @{$v{$x}},$y if(defined($x));
	}
	close FM;
}

sub check_info{
	# remove dead & duplicate aliases
	my $m=1;
	while($m){
		$m=0;
		for(keys %alias){
			my @a=sort @{$alias{$_}};
			delete($alias{$_});
			for my $i (@a){
				for(@{$alias{$_}}){
					if($_ eq $i){
						undef $i;
						last;
					}
				}
				push @{$alias{$_}},$i if(defined($i) && (exists($alias{$i})||exists($dep{$i})));
			}
			$m||=!exists($alias{$_});
		}
	}
	# update aliases, remove duplicate deps
	while(1){
		my $n;
		for(keys %dep){
			if(exists($alias{$_})){
				for my $a (@{$alias{$_}}){
					goto noalias if($_ eq $a);
				}
			}
			push @{$alias{$_}},$_;
			$n++;
			noalias:
			my ($n1,@a);
			for my $i (@{$dep{$_}}){
				my @a1=($i);
				if($i ne $_ && exists($dep{$i})){
					@a1=@{$dep{$i}};
					$n1++;
				}
				for $i (@a1){
					for(@a){
						if($i eq $_){
							undef $i;
							last;
						}
					}
					push @a,$i if(defined($i));
				}
			}
			if($n1){
				@{$dep{$_}}=@a;
				$n+=$n1;
			}
		}
		last if(!$n);
	}
}

sub lines_{
	my $i=$_[0];
	$i=~s/-/_/g;
	$i
}

sub lines{
	my $i=$_[0];
	$i=~s/((?:^|\])[^\[\]]*(?:\[|$))/lines_($1)/ge;
	($i)
}

sub mod{
	my $i=$_[0];
	$i=~s/^.*\/(.*?)\..*?$/$1/;
	$i
}

sub order1{
	my $a=$_[0];
	(index($a,'*')>=0 || index($a,'?')>=0)?9999-length($a):0;
}

sub order2{
	my $a=$_[0];
	$a=~s/[*?]//g;
	$a=~s/\[[^\[\]]+\]/?/g;
	return 0 if($a eq $_[0]);
	$a=~s/([^?])/$1$1/g;
	9999-length($a);
}

#todo: try to resolve "[...]" matches to best result
sub order3{
	my $a=$_[0];
	if(exists($re{$a})){
		$a=$re{$a};
	}else{
		return $dup++ if($a=~/^x86cpu:vendor:|^cpu:type:.*\,ven\*fam\*mod\*:/);
		$a=~s/([^a-zA-Z0-9\[\]*?] )/\\$1/g;
		my $s=$a;
		$a=~s/\*/.*/g;
		$a=~s/\[.*?\]|\?/(?:\\\[.*?\\\]|.)/g;
		$re{$_[0]}=$a;
		return $ord3{$a}=1 if($a eq $s);
	}
	return $ord3{$a} if(exists($ord3{$a}));
	my @l=grep(/^$a$/,@k_alias);
	if($#l){
		die "ERROR $s=$#l" if($#l<0);
		my %ll;
		$ll{join(' ',@{$alias{$_}})}=1 for (@l);
		my @r=keys %ll;
		return $ord3{$a}=0 if ($#r>$OPT{'barrier'});
		$ord3{$a}=$#r+1;
		my $n=0;
		for(@r){
			if($_ ne $_[0]){
				my $n1=order3($_);
				$n=$n1 if($n1>$n);
			}
		}
		return $ord3{$a}=$n+1;
	}
	$ord3{$a}=1;
}

sub lines1_{
	my $i=$_[0];
	$i=~s/[_-]/[_-]/g if(!$OPT{'sed'});
	$i=~s/ /[ -]/g;
	$i
}

sub fix_{
	my $i=$_[0];
	$i=~s/((?:^|\])[^\[\]]*(?:\[|$))/lines1_($1)/ge;
	$i=~s/ /\\ /g;
	$i
}

sub mk_sh{
	my %res=();
	my %pnp=();
	my %pnp0=();
	open(FS,$_[0]) || die $!;
	open(FP,$_[1]) || die $!;
	open(FO,$_[2]) || die $!;
	open(FP0,$_[3]) || die $!;
	print FS 'modalias(){
local i=""
';


	@k_alias=keys %alias;
	my $n=0;
	for (@k_alias) {
		my $re=0;
		my @d=();
		for (@{$alias{$_}}){
			for my $r (0..$#reorder){
				if(grep(/$reorder[$r]/,@{$dep{$_}}) && !grep(/$noreorder/,@{$dep{$_}})){
					push(@d,$re=$r+1,@{$dep{$_}});
					goto NN;
				}
			}
			unshift @d,@{$dep{$_}};
			NN:
		}
		if(isPNP($_)){
			for(@d){
				$pnp{$_}=1 for (lines(mod($_)));
			}
			for(@{$alias{$_}}){
				$pnp0{$_}=1 for (lines(mod($_)));
			}
		}
		my $k=join(' ',
		#	$re eq 2?'0000':
			sprintf("%04i",&{$order[$OPT{'order'}]}($_)),@d);
		$k=~s/\/([^\/.]+)/'\/'.($_ eq $1?'$1':$1)/ge if($OPT{'subst'} && !exists($res{$k}));
		if($re){
			push @{$res{$k}},$_;
		}else{
			unshift @{$res{$k}},$_;
		}
	}

	# unique
	my %nopnp;
	for (@k_alias) {
#		next if(index($_,'_')>=0);
		if($pnp{$_} || (not exists($dep{$_}))){
			$nopnp{$_}=2;
			$nopnp{$_}=2 for(@{$dep{$_}});
#			print "$_: ",join(",",@{$dep{$_}}),"\n";
		}else{
#			$nopnp{mod($_)}++ for(@{$dep{$_}});
			$nopnp{$_}++ for (@{$dep{$_}});
		}
	}
	for (keys %nopnp){ delete $nopnp{$_} if($nopnp{$_} != 1);}
	print FO join("\n",sort keys %nopnp,'');

	my $tail;
	my @r=();
	for (sort keys %res){
		$r[substr($_,0,4)].=fix_(join('|',@{$res{$_}})).')i="$i '.substr($_,5)."\";;\n"
	}
	for(0..$#r){
		my $s=$r[$_];
		next if(!defined($s));
		if($_<2){
			$s=~s/ 2 / /g;
		}else{
			$s=~s/ 2 /\$r /g;
		}
		print FS $tail.'case "$1" in
'.$s;
		$tail="esac\n";
		$tail.="local r=\"\${i:+ 1}\"\n" if($_==1);
	}
	print FS 'case "$1" in
'		if(!$tail);
	print FS 'esac
ALIAS="$i"
[ -n "$i" ]
return $?
}
';
	for (keys %pnp) {
		print FP "$_\n";
		my $i=$_;
		$i=~s/_/-/g;
		print FP "$i\n" if(not exists($pnp{$i}));
	}
	for (keys %pnp0) {
		print FP0 "$_\n";
		my $i=$_;
		$i=~s/_/-/g;
		print FP0 "$i\n" if(not exists($pnp0{$i}));
	}
	close(FO);
	close(FP);
	close(FS);
	close(FP0);
#	for (sort keys %nopnp,''){
#		system("modprobe ".mod($_)) if(index($_,'video')<0);
#	}
}

sub isPNP{
	(index($_[0],':')>=0) && !($_[0]=~/^devname/);
}

$|=1;
if($#ARGV<0){
	print "Usage: $0 {--option=value} {[path]/lib/modules/<version>}\nDefaults:\n";
	print "	--$_=$OPT{$_}\n" for(keys %OPT);
}
for my $MOD (@ARGV){
	if(my($x,$y)=$MOD=~/^--(.*?)(?:=(.*))?$/){
		$OPT{$x}=$y;
		next;
	}
	%alias=();
	%dep=();
	print "mod2sh: $MOD ";
	if(-e "$MOD/modules.dep" && -e "$MOD/modules.alias"){
		read_deps("<$MOD/modules.dep");
		read_aliases("<$MOD/modules.alias");
	}else{
		read_modinfo("$MOD");
	}
	&check_info;
	mk_sh(">$MOD/modules.alias.sh",">$MOD/modules.pnp",">$MOD/modules.other",">$MOD/modules.pnp0");
	print "OK\n";
}
