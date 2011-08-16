#!/usr/bin/perl

$|=1;
$ENV{KERNEL_MODULES}||='+.';
# prefer: "-." - defconfig, "." - defconfig for "y|m", "+." - Kconfig/oldconfig
$ENV{KERNEL_DEFAULTS}||='.';
$ENV{KERNEL_CONFIG}||='
	######
	KALLSYMS_EXTRA_PASS DMA_ENGINE
	PREEMPT_NONE
	MTRR_SANITIZER IA32_EMULATION LBD
	GFS2_FS_LOCKING_DLM NTFS_RW
	X86_32_NON_STANDARD INTR_REMAP
	MICROCODE_INTEL MICROCODE_AMD
	ASYNC_TX_DMA DMAR INTR_REMAP BLK_DEV_INTEGRITY
	AMD_IOMMU
	SPARSEMEM_MANUAL MEMTEST .*FS_XATTR
	MEMORY_HOTPLUG MEMORY_HOTREMOVE
	EXT2_FS_XIP OLPC NFSD_V4 CIFS_POSIX CIFS_EXPERIMENTAL .*_FSCACHE
	VMI =KVM_CLOCK =KVM_GUEST =XEN =LGUEST_GUEST
	-BLK_DEV_UB
	KEYBOARD_ATKBD
	CRC_T10DIF
	-VGACON_SOFT_SCROLLBACK FB_BOOT_VESA_SUPPORT FRAMEBUFFER_CONSOLE_ROTATION
	.*_KMS
	IKCONFIG_PROC IKCONFIG EXPERIMENTAL
	NET_RADIO PNP_ACPI PARPORT_PC_FIFO PARPORT_1284 NFTL_RW
	PMC551_BUGFIX CISS_SCSI_TAPE CDROM_PKTCDVD_WCACHE
	SCSI_SCAN_ASYNC IOSCHED_DEADLINE DEFAULT_DEADLINE SND_SEQUENCER_OSS
	SND_FM801_TEA575X_BOOL SND_AC97_POWER_SAVE SCSI_PROC_FS SCSI_FLASHPOINT
	=.*_VENDOR_.* NET_POCKET
	SYN_COOKIES .*_NAPI
	.*_EDID FB_.*_I2C FB_MATROX_.* FB_ATY_.*
	FB_.*_ACCEL -FB_HGA_ACCEL FB_SIS_300 FB_SIS_315 FB_GEODE
	FB_MB862XX_PCI_GDC
	-CC_OPTIMIZE_FOR_SIZE
	-SMB_FS -DEFAULT_CFQ -DEFAULT_AS -DEFAULT_NOOP
	GPIO EZX_PCAP MFD_SM501_GPIO SSB_PCMCIAHOST
	ISCSI_IBFT_FIND EXT4DEV_COMPAT
	SCSI_FC_TGT_ATTRS SCSI_SAS_ATA SCSI_SRP_TGT_ATTRS
	MEGARAID_NEWGEN SCSI_EATA_TAGGED_QUEUE SCSI_EATA_LINKED_COMMANDS
	SCSI_GENERIC_NCR53C400 IBMMCA_SCSI_ORDER_STANDARD
	SCSI_U14_34F_TAGGED_QUEUE SCSI_U14_34F_LINKED_COMMANDS
	SCSI_MULTI_LUN
	GACT_PROB IP_FIB_TRIE
	TCP_CONG_CUBIC TCP_CONG_BIC TCP_CONG_YEAH
	IRDA_ULTRA IRDA_FAST_RR DONGLE
	-SECURITY_FILE_CAPABILITIES
	    HOSTAP_FIRMWARE DCC4_PSISYNC
	    FDDI HIPPI VT_HW_CONSOLE_BINDING SERIAL_NONSTANDARD
	    SERIAL_8250_EXTENDED
	TIPC_ADVANCED NET_IPGRE_BROADCAST
	IP_VS_PROTO_.*
	ISA MCA MCA_LEGACY EISA NET_ISA PCI PCI_LEGACY RAPIDIO
	PCIEASPM CRYPTO_DEV_HIFN_795X_RNG PERF_COUNTERS
	X86_SPEEDSTEP_RELAXED_CAP_CHECK
	SLIP_COMPRESSED SLIP_SMART NET_FC -LOGO_LINUX_[\w\d]*
	-8139TOO_PIO
	-COMPAT_BRK -COMPAT_VDSO
	NET_CLS_IND
	-STAGING_EXCLUDE_BUILD DRM_RADEON_KMS DRM_NOUVEAU_BACKLIGHT
	SND_BT87X_OVERCLOCK  SND_HDA_RECONFIG SND_HDA_PATCH_LOADER SND_HDA_POWER_SAVE SND_HDA_INPUT_JACK
	PSS_MIXER SC6600 SC6600_JOY
	KSM PM_RUNTIME PCI_IOV HOTPLUG_PCI_CPCI
	DEVTMPFS COMPACTION +POHMELFS VIA_DIRECT_PROCFS HID_WACOM_POWER_SUPPLY
	HID_PICOLCD_.* MULTICORE_RAID456
	VGA_SWITCHEROO ACPI_APEI L2TP_V3
	THERMAL_HWMON
	NFS_V4_1 TRANSPARENT_HUGEPAGE TRANSPARENT_HUGEPAGE_MADVISE
	MEMORY_FAILURE =INTEL_IDLE
	XFRM_MIGRATE NET_KEY_MIGRATE
	IPV6_MULTIPLE_TABLES IPV6_SUBTREES IPV6_SIT_6RD
	IPV6_ROUTER_PREF NF_CONNTRACK_ZONES NF_CONNTRACK_EVENTS
	IP_VS_IPV6 DCB MAC80211_MESH MAC80211_RC_PID
	DEVTMPFS_MOUNT PARPORT_PC_SUPERIO BLK_DEV_XIP
	=(?:JOYSTICK|USB|ISDN|JFFS2|MOUSE|RTC|SQUASHFS|ROMFS|BT|DSCC4|ATM|HISAX|GPIO|A11Y|SPI|BCMA|RT2800USB)_.+
	=/drivers/(?:mfd|regulator)/.*
	~HISAX_NO_.*
	=.+_(PARTITION|FF|X_COMPATIBILITY)
	DM_UEVENT =.*_SDIO B43_PHY_N
	CIFS_UPCALL NETCONSOLE_DYNAMIC  NFS_USE_NEW_IDMAPPER
	###bugs: -TR -ECONET
	###udev: -IDE
	#######
	';
$ENV{KERNEL_CONFIG2}||='?DMA_ENGINE';


%cc=(
	'+'=>'m',
	'-'=>'n (recursive)',
	'~'=>'remove/oldconfig-default',
	'='=>'y if undefined bool',
	'&'=>'m->y recursive embed',
	'?'=>'n if none embedded module dependences (use after detects)',
	'#'=>'#',
);

%config=('y'=>'y','n'=>'n','m'=>'m');

sub Kcload{
	die "Unresolved Kconfig: $_[0]\n" if(index($_[0],'$')>=0);
	my ($c,$v,@if1);
	my $d=$_[0];
	open(my $F,"<$d") || return; # || die "$! ($d)";
	die "Invalid dereference\n" if(index($d,$ENV{S}.'/')!=0);
	substr($d,0,length($ENV{S})+1)='';
	while(defined(my $s=<$F>)){
		$s=~s/#.*//gs;
		$s=~s/\s*$//s;
		$s=~s/^\s*((?:menu)?config)\s+(\S+)/$c=$1;$v="$d:$2";push @{$if{$v}},join(' && ',@if1) if($#if1>=0);next/e;
		$s=~s/^\s*(comment|mainmenu|menu)\s/$c=$1;$v=undef;next/e;
		$s=~s/^\s*(choice|endchoice|endmenu)$/$c=$1;$v=undef;next/e;
		$s=~s/^if\s+(.*)$/$c='if';push @if1,"($1)";next/e;
		$s=~s/^endif$/$c='endif';pop @if1;next/e;
		$s=~s/^\s*(?:def_)?tristate(?:\s+\S*|$)/$tristate{$v}=1;next/e;
		$s=~s/^\s*(?:def_)?bool(?:\s+\S*|$)/if($c eq 'menuconfig'){$menu{$v}=1}else{$bool{$v}=1};next/e;
		$s=~s/^\s*select\s+(.*)$/push @{$select{$1}},$v;next/e;
		$s=~s/^\s*depends\s+on\s+(.*)$/push @{$depends{$v}},$1;next/e;
		$s=~s/(?:If\s+unsure,\s+s|If\s+in\s+doubt,\s+s|S)ay\s+Y\./$yes{$v}=1;next/e;
		$s=~s/(?:If\s+unsure,\s+s|If\s+in\s+doubt,\s+s|S)ay\s+N\./$no{$v}=1;next/e;
		next if(!$ENV{SRCARCH});
		$s=~s/^\s*option\s+env="(\w+)"/$env{$1}=1;next/e;
		$s=~s/\$(\w+)/$env{$1}?$ENV{$1}:"\$$1"/e;
		$s=~s/^\s*source\s+"(.*)"/Kcload("$ENV{S}\/$1");next/e;
		$s=~s/^\s*source\s+(.*)/Kcload("$ENV{S}\/$1");next/e;
	}
	close($F);
}

sub msg{
	if($msg){
		print "KERNEL_CONFIG: $_[0] ->$msg\n";
		$msg='';
	}

}

sub Kclist{
	opendir(my $D,$_[0]) || die $!;
	my @d=readdir($D);
	close($D);
	for(@d){
		if(-d "$_[0]/$_"){
			Kclist("$_[0]/$_") if(substr($_,0,1) ne '.');
		}elsif(index($_,'Kconfig')==0){
			Kcload("$_[0]/$_");
		}
	}
}

sub load_config{
	open(my $F,"<$_[0]") || return;
	while(defined(my $s=<$F>)){
		chomp($s);
		$s=~s/^CONFIG_([^=\s]*)=(.*)/$config{$1}=$2;$vars{$1}=1;next/se;
		$s=~s/^# CONFIG_([^=\s]*) is not set/$config{$1}=undef;$vars{$1}=1;next/se;
	}
	close($F);
}

sub set_config{
	my $s;
	if(open(my $F,"<$_[0]")){
		sysread($F,$s,-s $F);
		close($F);
	}
	if(! -e "$_[0].default"){
		open(my $F,">$_[0].default");
		print $F $s;
		close($F);
	}
	my $x=join('|',keys %unset);
	$s=~s/\n(?:# )?CONFIG_(?:$x)(?:=[^\n]*| is not set)//gs;
	while(my ($x,$y)=each %config){
#		next if(defined($oldconfig{$x}) && $oldconfig{$x} eq $y);
		$y=$y ne ''?"CONFIG_$x=$y":"# CONFIG_$x is not set";
		$s.="$y\n" if(!($s=~s/\nCONFIG_$x=[^\n]*\n|\n# CONFIG_$x is not set\n/\n$y\n/s));
	}
	open(my $F,">$_[0]") || die $!;
	print $F $s;
	close($F);
}

sub spl{
	my $d=$_[0];
	my $c=substr($d,0,1);
	substr($d,0,1)='' if(exists($cc{$c}));
	($c,$d)
}

sub modules{
	return if($_[0] eq '');
	print "Applying modules: $_[0]\n";
	my ($c,$d)=spl($_[0]);
	for(grep(/^$d/,keys %tristate)){
		~s/.*://;
		if($c eq '+'){
			cfg($_,'m');
		}elsif($c eq '-'){
			cfg($_,$defconfig{$_});
		}elsif($c ne '=' || !defined($config{$_})){
			cfg($_,$defconfig{$_}?$defconfig{$_}:'m')
		}
	}
	msg($_[0]);
}


sub defaults{
	return if($_[0] eq '');
	print "Applying defaults: $_[0]\n";
	my ($c,$d)=spl($_[0]);
	for(grep(/^$d/,keys %menu)){
		~s/.*://;
		if($c eq '-'){
			$unset{$_}=1;
			delete($config{$_});
		}else{
			cfg($_,'y');
		}
	}
	for(grep(/^$d/,keys %bool)){
		my $y=$yes{$_};
		~s/.*://;
		if(($c eq '-' && exists($defconfig{$_})) || ($c ne '+' && $defconfig{$_})){
			cfg($_,$defconfig{$_});
		}else{
			$unset{$_}=1;
			delete($config{$_});
			cfg($_,'y') if($y && ($c eq '+' || !defined($defconfig{$_})));
		}
	}
	msg($_[0]);
}

sub logic{
	my $s=$_[0];
	my $q='"((?:\"|[^"])*)"';
	$s=~s/(\w+)=+($q)/$config{$1} eq $2?'y':'n'/ge;
	$s=~s/(\w+)!=($q)/$config{$1} ne $2?'y':'n'/ge;
	$s=~s/(\w+)/$config{$1} ne ''?$config{$1}:'n'/ge;
	$s=~s/\s*//g;
	while(
		($s=~s/([ymn])=+([ymn])/$1 eq $2?'y':'n'/ge)||
		($s=~s/([ymn])!=([ymn])/$1 ne $2?'y':'n'/ge)||
		($s=~s/[ynm]\&\&n|n\&\&[ynm]|n\|\|n/n/g)||
		($s=~s/[ynm][&\|]{2}[ynm]/y/g)||
		($s=~s/![ym]/n/g)||
		($s=~s/!n/y/g)||
		($s=~s/\([ym]\)/y/g)||
		($s=~s/\(n\)/n/g)
	){}
	$s eq 'n'?'':$s;
}

sub sel{
	my $x=shift;
	my @a=();
	my $l;
	for(grep(/^$x(?:\s|$)/,ref($_[0]) eq 'HASH'?keys %{$_[0]}:@_)){
		push @a,$_ if(!(($l)=$_=~/\sif\s+(.*)$/)||logic($l));
	}
	return ref($_[0]) eq 'HASH'?map{
		$x=$_[0]->{$_};
		(ref($x) eq 'ARRAY')?@{$x}:$x;
	}(@a):@a;
}

sub cfg{
	$set{$_[0]}=1;
	if(defined($_[1])){
		$config{$_[0]}=$_[1];
		return 1;
	}
	return 1 if(exists($off{$_[0]}));
	$off{$_[0]}=1;
	for(sel($_[0],\%select)){
		my $i=$_;
		$i=~s/.*://;
		my $r=$config{$i};
		cfg($i,undef,$_[2]) || return 0;
		$msg.=" -$i" if($r && !defined($_[2]));
	}
	defined($_[2]) && return &{$_[2]}($_[0]);
	$config{$_[0]}='';
	1;
}

sub _and{
	return if($config{$_[0]} ne 'm');
	$msg.=" $_[0]" if($_[0] ne $_[2]);
	cfg(@_[0,1]);
	for(grep(/.*:$_[0]$/,keys %depends)){
		next if(!exists($tristate{$_}));
		for(@{$depends{$_}}){
			_and($_,@_[1,2]) for(split(/[ )(]/,$_));
		}
	}
}

sub onoff{
	my $v=$config{$_[0]};
#	for(grep(/(?:^|\W)$_[0](?:\W|$)/,@{$depends{$_[1]}},@{$if{$_[1]}})){
	for(@{$depends{$_[1]}},@{$if{$_[1]}}){
		$config{$_[0]}=$_[2];
		logic($_) || next;
		$config{$_[0]}='';
		logic($_) && next;
		$config{$_[0]}=$v;
		return 1;
	}
	$config{$_[0]}=$v;
	0;
}

sub _if{
#	return 1 if(!$config{$_[0]});
	my $r;
	my $y='y';
	if(grep(/.*:$_[0]$/,keys %tristate)){
		return 0 if($config{$_[0]} eq 'y');
		$y='m';
		$r++;
	}
	my $i;
	for(keys %tristate){
		onoff($_[0],$_,$y) || next;
		$i=$_;
		$i=~s/.*://;
		return 0 if($config{$i} eq 'y' || !cfg($i,undef,\&_if));
		$r++;
	}
	for(keys %bool){
		onoff($_[0],$_,$y) || next;
		$i=$_;
		$i=~s/.*://;
		return 0 if(!cfg($i,undef,\&_if));
		$r++;
	}
	$r;
}

sub conf{
    return if($_[0] eq '');
    for(split(/;/,$_[0])){
	my ($c,$d)=spl($_);
	my $y='y';
	$d=~s/(.*?)=(.*)/$y=$2;$1/se;
	my @l;
	if(exists($vars{$d})){
		@l=($d);
	}elsif(substr($d,0,1) eq '/'){
		my %ll;
		substr($d,0,1)='^';
		for(grep(/$d$/,keys %tristate,keys %bool,keys %menu)){
			my $i=$_;
			$i=~s/.*://;
			$ll{$i}=1 if(exists($vars{$i}))
		}
		@l=keys %ll;
	}else{
		@l=grep(/^$d$/,keys %vars);
		@l=($d) if($#l==-1 && !($d=~/[^A-Za-z0-9_]/) && $_[0] eq $_);
	}
	for(@l){
		if($c eq '+'){
			cfg($_,'m');
		}elsif($c eq '-'){
			%off=();
			cfg($_);
		}elsif($c eq '~'){
			cfg($_,$oldconfig{$_});
		}elsif($c eq '&'){
			_and($_,$y,$_);
		}elsif($c eq '?'){
			%off=();
			cfg($_,undef,\&_if) || next;
			$msg='';
			%off=();
			cfg($_);
		}elsif($c eq '#'){
			return;
		}elsif($c ne '=' || !defined($config{$_})){
			cfg($_,$y);
		}
	}
	last if($#l>=0);
    }
    msg($_[0]);
}

sub arch{
	open(my $F,"<$ENV{S}/Makefile") or die $!;
	sysread($F,my $s,-s $F);
	close($F);
	$s=~s/
\s*ifeq\s+\(\s*\$\(ARCH\)\s*,\s*(\S*?)\s*\)\s*
\s*SRCARCH\s*:=\s*(\S*)\s*
\s*endif/$_ARCH{$1}=$2;''/gse;
	$ENV{SRCARCH}=$_ARCH{$ENV{SRCARCH}}||$ENV{SRCARCH};
}

sub Kconfig{
	our (%tristate,%bool,%select,%menu,%yes,%no,%config,%oldconfig,%defconfig,%off,%unset,%vars,%set)=();
	if($ENV{SRCARCH} && arch() && -e "$ENV{S}/Kconfig" && -e "$ENV{S}/arch/$ENV{SRCARCH}/Kconfig"){
		print "SRCARCH=$ENV{SRCARCH}\n";
		Kcload("$ENV{S}/Kconfig");
	}else{
		print "!SRCARCH\n";
		delete($ENV{SRCARCH});
		Kclist($ENV{S});
	}
	my $c="$ENV{S}/.config";
	if(load_config("$c.default")){
		%defconfig=%config;
		load_config($c);
	}elsif(load_config($c)){
		%defconfig=%config;
	}else{
		die "Not found $c and|or $c.default";
	}
	%oldconfig=%config;
	defaults($_) for(split(/\s+/,$ENV{KERNEL_DEFAULTS}));
	modules($_) for(split(/\s+/,$ENV{KERNEL_MODULES}));
	print "Applying config: $ENV{KERNEL_CONFIG}\n";
	conf($_) for(split(/\s+/,$ENV{KERNEL_CONFIG}));
	for(grep(/^KERNEL_CONFIG_/,keys %ENV)){
		cfg(substr($_,14),$ENV{$_});
		msg("$_=$ENV{$_}");
	}
	set_config("$ENV{S}/.config");
}

sub config{
	print ": \${$_:='$ENV{$_}'}\n" for(sort grep(/^KERNEL_/,keys %ENV));
}

if($ARGV[0]=~/^-(?:help|-help|h|--h)$/){
	config;
	print "---Modifiers:\n";
	print "'$_' - $cc{$_}\n" for(sort keys %cc);
}elsif($ARGV[0] eq '-config'){
	config;
}else{
	$ENV{S}||=$ARGV[0]||'.';
	Kconfig();
}
