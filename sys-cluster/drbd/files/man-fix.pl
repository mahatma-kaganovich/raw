#!/usr/bin/perl
my $s;
$s.=$_ while(<STDIN>);
$s=~s/<\/option>([\s\t\n]*<listitem>)/<\/option><\/term>$1/g;
print $s;
