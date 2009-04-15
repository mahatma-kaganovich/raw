#!/usr/bin/perl
# modules.alias & modules.dep -> modules.alias.sh & modules.pnp
# for syspnp modules pnp loader
# (c) Denis Kaganovich
# under Anarchy license

my %alias=();
my %dep=();

sub read_aliases{
	my $s;
	open FA,$_[0];
	while(defined($s=<FA>)){
		chomp($s);
		my $id,$m;
		$s=~s/^alias\s(\S*)\s(\S*)$/$id=$1;$m=$2;""/e;
		defined($id)||next;
		push @{$alias{$id}},$m;
		$s=$id;
		$s=~s/-/_/g;
		$alias{$s}=$alias{$id};
		$s=~s/_/-/g;
		$alias{$s}=$alias{$id};
	}
	close FA;
}

sub read_deps{
	my $s;
	open FD,$_[0];
	while(defined($s=<FD>)){
		chomp($s);
		$id=$s;
		$id=~s/.*\/(.*?)\..*?:.*/$1/;
		$s=~s/://;
		for my $i (split(/ /,$s)){
			for(@{$dep{$id}}){
				if($_ eq $i){
					$i='';
					last;
				}
			}
			unshift @{$dep{$id}},$i if($i ne '');
		}
		$s=$id;
		$s=~s/-/_/g;
		$dep{$s}=$dep{$id};
		$s=~s/_/-/g;
		$dep{$s}=$dep{$id};
	}
	close FD;
}

sub mk_sh{
	my %res=();
	my %pnp=();
	open FS,$_[0];
	open FP,$_[1];
	print FS 'alias2(){
local i="$1"
case "$i" in
';
	for (keys %alias) {
		my @d=();
		push @d,@{$dep{$_}} for (@{$alias{$_}});
		if(isPNP($_)){
			for(@d){
				my $i=$_;
				$i=~s/^.*\/(.*?)\..*?$/$1/;
				$pnp{$i}=1;
				$i=~s/-/_/g;
				$pnp{$i}=1;
				$i=~s/_/-/g;
				$pnp{$i}=1;
			}
		}
		my $k=sprintf("%04i",
		    (index($_,'*')>=0 || index($_,'?')>=0)?9999-length($_):0);
		$res{$k}.="$_)i=\"".join(' ',@d)."\";;\n";
	}
	print FS "$res{$_}" for (sort keys %res);
	print FS '*)ALIAS=""
return 1
;;
esac
ALIAS="$i"
return 0
}
';
	print FP join("\n",keys %pnp);
	close(FP);
	close(FS);
}

sub isPNP{
	index($_[0],':')>=0;
}

$|=1;
if($#ARGV<0){
	print "Usage: $0 {[path]/lib/modules/<version>}\n"
}
for my $MOD (@ARGV){
	print "mod2sh: $MOD ";
	read_aliases("<$MOD/modules.alias");
	read_deps("<$MOD/modules.dep");
	for(keys %dep){
		push @{$alias{$_}},$_ if(!exists($alias{$_}))
	}
	mk_sh(">$MOD/modules.alias.sh",">$MOD/modules.pnp");
	print "OK\n";
}
