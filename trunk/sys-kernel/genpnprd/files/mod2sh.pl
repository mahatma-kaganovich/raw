#!/usr/bin/perl
# modules.alias & modules.dep -> modules.alias.sh & modules.pnp
# for syspnp modules pnp loader
# (c) Denis Kaganovich
# under Anarchy license

my %alias;
my %dep;

# to load second/last
# will be delimited by "1" (to easy "break/continue" integration)
my $reorder='\/ide\/|usb-storage|\/oss\/';

# 0-old (alias-per-case), 1-"or", 2-slow/multi-match
my $JOIN=2;
my $SUBST=$JOIN;
my $MULTI=$JOIN==2;
my $VERBOSE=0;

sub read_aliases{
	my ($s,$id,$m);
	open FA,$_[0];
	while(defined($s=<FA>)){
		chomp($s);
		$s=~s/^alias\s(\S*)\s(\S*)$/$id=$1;$m=$2;""/e;
		defined($id)||next;
		push @{$alias{$_}},$m for (lines($id));
	}
	close FA;
	# remove dead aliases
	$m=1;
	while($m){
		$m=0;
		for(keys %alias){
			my @a=@{$alias{$_}};
			delete($alias{$_});
			for $id (@a){
				exists($alias{$id})||exists($dep{$id})||next;
				push @{$alias{$_}},$id;
			}
			$m||=!exists($alias{$_});
		}
	}
}

sub read_deps{
	my $s;
	open FD,$_[0];
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

sub lines_{
	my $i=$_[0];
	$i=~s/-/_/g;
	$i
}

sub lines{
	my $i=$_[0];
	my $c='[^\[\]]*';
	$i=~s/^($c\[)/lines_($1)/ge;
	$i=~s/(\]$c\[)/lines_($1)/ge;
	$i=~s/(\]$c)$/lines_($1)/ge;
	$i=~s/^($c)$/lines_($1)/ge;
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
	my $a=$_;
	$a=~s/\*/.*/g;
#	$a=~s/\?/./g;
	$a=~s/\[.*?\]|\?/(?:\\\[.*?\\\]|.)/g;
	my @l=$a ne $_?grep(/^$a$/,@k_alias):($_);
	print "$_=$#l\n" if($#l<0);
	if($#l>0){
		my %ll;
		for (@l){
			$ll{join(' ',@{$alias{$_}})}=1;
		}
		if($VERBOSE){
		    my @l1=keys %ll;
		    if($#l1>0){
			print "$_ -> ";
			for(@l1){
				print "$_ (";
				for(split(/ /,$_)){
					print join(",",@{$dep{$_}});
				}
				print ") ";
			}
			print "\n";
		    }
		    @l=@l1;
		}else{
		    @l=keys %ll;
		}
	}
	$#l+1;
}

sub mk_sh{
	my %res=();
	my %pnp=();
	open(FS,$_[0]) || die $!;
	open(FP,$_[1]) || die $!;
	open(FO,$_[2]) || die $!;
	print FS 'modalias(){
local i=""
';


	@k_alias=keys %alias;
	my $n=0;
	print "\n" if($VERBOSE);
	for (@k_alias) {
		if($VERBOSE){
			$n++;
			print "$n/$#k_alias \r";
		}
		my $re=0;
		my @d=();
		my @a=@{$alias{$_}};
		for (@{$alias{$_}}){
			if(grep(/$reorder/,@{$dep{$_}})){
				push @d,'1',@{$dep{$_}};
				$re=1;
			}else{
				unshift @d,@{$dep{$_}};
			}
		}
		if(isPNP($_)){
			for(@d){
				$pnp{$_}=1 for (lines(mod($_)));
			}
		}
		my $k=sprintf("%04i",$JOIN==2?order3($_):order2($_));
		my $m=join(' ',@d);
		if($JOIN){
			$k.=" $m";
			$k=~s/\/([^\/.]+)/'\/'.($_ eq $1?'$1':$1)/ge if($SUBST && !exists($res{$k}));
			if($re){
				push @{$res{$k}},$_;
			}else{
				unshift @{$res{$k}},$_;
			}
		}else{
			if($re){
				$res{$k}.="$_)i=\"$m\";;\n";
			}else{
				$res{$k}="$_)i=\"$m\";;\n$res{$k}";
			}
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
	if ($MULTI && $JOIN){
		my @r=();
		$r[substr($_,0,4)].=join('|',@{$res{$_}}).')i="$i '.substr($_,5)."\";;\n" for (sort keys %res);
		while($#r>=0){
			my $s=pop @r;
			next if(!defined($s));
			print FS $tail.'case "$1" in
'.$s;
			$tail="esac\n";
		}
		print FS 'case "$1" in
'			if(!$tail);
	}else{
		print FS 'case "$1" in
';
		if ($JOIN) {
			print FS join('|',@{$res{$_}}).')i="'.substr($_,5)."\";;\n" for (sort keys %res);
		} else {
			print FS "$res{$_}" for (sort keys %res);
		}
	}
	print FS 'esac
ALIAS="$i"
[[ -n "$i" ]]
return $?
}
';
	for (keys %pnp) {
		print FP "$_\n";
		my $i=$_;
		$i=~s/_/-/g;
		print FP "$i\n" if(not exists($pnp{$i}));
	}
	close(FO);
	close(FP);
	close(FS);
#	for (sort keys %nopnp,''){
#		system("modprobe ".mod($_)) if(index($_,'video')<0);
#	}
}

sub isPNP{
	index($_[0],':')>=0;
}

$|=1;
if($#ARGV<0){
	print "Usage: $0 {[path]/lib/modules/<version>}\n"
}
for my $MOD (@ARGV){
	%alias=();
	%dep=();
	print "mod2sh: $MOD ";
	read_deps("<$MOD/modules.dep");
	read_aliases("<$MOD/modules.alias");
	for(keys %dep){
	        if(exists($alias{$_})){
		    for my $a (@{$alias{$_}}){
			goto noalias if($_ eq $a);
		    }
		}
		push @{$alias{$_}},$_;
		noalias:
	}
	mk_sh(">$MOD/modules.alias.sh",">$MOD/modules.pnp",">$MOD/modules.other");
	print "OK\n";
}
