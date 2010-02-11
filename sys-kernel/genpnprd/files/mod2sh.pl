#!/usr/bin/perl
# modules.alias & modules.dep -> modules.alias.sh & modules.pnp
# for syspnp modules pnp loader
# (c) Denis Kaganovich
# under Anarchy license

my %alias;
my %dep;

# 0-old (alias-per-case), 1-"or"
my $JOIN=1;

sub read_aliases{
	my $s;
	open FA,$_[0];
	while(defined($s=<FA>)){
		chomp($s);
		my $id,$m;
		$s=~s/^alias\s(\S*)\s(\S*)$/$id=$1;$m=$2;""/e;
		defined($id)||next;
		push @{$alias{$_}},$m for (lines($id));
	}
	close FA;
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
	my $a=$_[0];
	$a=~s/([^a-zA-Z0-9\*\?])/$1/g;
	$a=~s/\*/.*/g;
	$a=~s/\?/./g;
	my @l=grep(/^$a$/,keys %alias);
	print "$a=$#l " if($#l<0);
	$#l+1;
}

sub mk_sh{
	my %res=();
	my %pnp=();
	open(FS,$_[0]) || die $!;
	open(FP,$_[1]) || die $!;
	open(FO,$_[2]) || die $!;
	print FS 'alias2(){
local i="$1"
case "$i" in
';


	for (keys %alias) {
		my @d=();
		push @d,@{$dep{$_}} for (@{$alias{$_}});
		if(isPNP($_)){
			for(@d){
				$pnp{$_}=1 for (lines(mod($_)));
			}
		}
		my $k=sprintf("%04i",order2($_));
		if($JOIN){
			$k.=' '.join(' ',@d);
			$k=~s/\/(\w+)\./'\/'.($_ eq $1?'$i':$1).'.'/ge;
			push @{$res{$k}},$_;
		}else{
			$res{$k}.="$_)i=\"".join(' ',@d)."\";;\n";
		}
	}

	# unique
	my %nopnp;
	for (keys %alias) {
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

	if ($JOIN) {
		print FS join('|',@{$res{$_}}).')i="'.substr($_,5)."\";;\n" for (sort keys %res);
	} else {
		print FS "$res{$_}" for (sort keys %res);
	}
	print FS '*)ALIAS=""
return 1
;;
esac
ALIAS="$i"
return 0
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
	read_aliases("<$MOD/modules.alias");
	read_deps("<$MOD/modules.dep");
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
