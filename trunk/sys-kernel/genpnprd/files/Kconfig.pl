#!/usr/bin/perl

$|=1;
$ENV{KERNEL_MODULES}||='+.';
# prefer: "-." - defconfig, "." - defconfig for "y|m", "+." - Kconfig/oldconfig
$ENV{KERNEL_DEFAULTS}||='.';
$ENV{KERNEL_CONFIG}||='
	=======
	KALLSYMS_EXTRA_PASS DMA_ENGINE USB_STORAGE_[\w\d]+
	PREEMPT_NONE
	MTRR_SANITIZER IA32_EMULATION LBD
	GFS2_FS_LOCKING_DLM NTFS_RW
	X86_32_NON_STANDARD INTR_REMAP
	MICROCODE_INTEL MICROCODE_AMD
	ASYNC_TX_DMA NET_DMA DMAR INTR_REMAP BLK_DEV_INTEGRITY
	AMD_IOMMU
	SPARSEMEM_MANUAL MEMTEST [\d\w_]*FS_XATTR
	MEMORY_HOTPLUG MEMORY_HOTREMOVE
	EXT2_FS_XIP OLPC NFSD_V4 CIFS_POSIX +[\d\w_]*_FSCACHE
	VMI KVM_CLOCK KVM_GUEST XEN LGUEST_GUEST
	USB_LIBUSUAL -BLK_DEV_UB USB_EHCI_ROOT_HUB_TT USB_EHCI_TT_NEWSCHED USB_SISUSBVGA_CON
	KEYBOARD_ATKBD
	CRC_T10DIF
	-VGACON_SOFT_SCROLLBACK FB_BOOT_VESA_SUPPORT FRAMEBUFFER_CONSOLE_ROTATION
	IKCONFIG_PROC IKCONFIG EXPERIMENTAL
	NET_RADIO PNP_ACPI PARPORT_PC_FIFO PARPORT_1284 NFTL_RW
	PMC551_BUGFIX CISS_SCSI_TAPE CDROM_PKTCDVD_WCACHE
	SCSI_SCAN_ASYNC IOSCHED_DEADLINE DEFAULT_DEADLINE SND_SEQUENCER_OSS
	SND_FM801_TEA575X_BOOL SND_AC97_POWER_SAVE SCSI_PROC_FS SCSI_FLASHPOINT
	NET_VENDOR_[\w\d_]* NET_POCKET
	SYN_COOKIES [\w\d_]*_NAPI
	[\w\d_]*_EDID FB_[\w\d_]*_I2C FB_MATROX_[\w\d_]* FB_ATY_[\w\d_]*
	FB_[\w\d_]*_ACCEL -FB_HGA_ACCEL FB_SIS_300 FB_SIS_315 FB_GEODE
	FB_MB862XX_PCI_GDC
	-CC_OPTIMIZE_FOR_SIZE
	-SMB_FS -DEFAULT_CFQ -DEFAULT_AS -DEFAULT_NOOP
	GPIO EZX_PCAP MFD_SM501_GPIO SSB_PCMCIAHOST
	ISCSI_IBFT_FIND EXT4DEV_COMPAT LDM_PARTITION
	SCSI_FC_TGT_ATTRS SCSI_SAS_ATA SCSI_SRP_TGT_ATTRS
	MEGARAID_NEWGEN SCSI_EATA_TAGGED_QUEUE SCSI_EATA_LINKED_COMMANDS
	SCSI_GENERIC_NCR53C400 IBMMCA_SCSI_ORDER_STANDARD
	SCSI_U14_34F_TAGGED_QUEUE SCSI_U14_34F_LINKED_COMMANDS
	SCSI_MULTI_LUN
	GACT_PROB IP_FIB_TRIE
	TCP_CONG_CUBIC TCP_CONG_BIC TCP_CONG_YEAH
	BT_RFCOMM_TTY BT_HCIUART_H4 BT_HCIUART_BCSP BT_HCIUART_LL
	IRDA_ULTRA IRDA_FAST_RR DONGLE
	-SECURITY_FILE_CAPABILITIES
	    HOSTAP_FIRMWARE DCC4_PSISYNC
	    FDDI HIPPI VT_HW_CONSOLE_BINDING SERIAL_NONSTANDARD
	    SERIAL_8250_EXTENDED
	TIPC_ADVANCED NET_IPGRE_BROADCAST
	IP_VS_PROTO_[\d\w_]*
	ISA MCA MCA_LEGACY EISA NET_ISA PCI PCI_LEGACY
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
	HID_PICOLCD_[\w\d_]* MULTICORE_RAID456 USB_FUNCTIONFS_[\w\d_]*
	USB_SERIAL_MOS7715_PARPORT BT_L2CAP_EXT_FEATURES VGA_SWITCHEROO
	USB_OHCI_HCD_SSB ACPI_APEI L2TP_V3
	===bugs: -TR
	=======
	';

sub Kcload{
	my ($c,$v);
	my $d=$_[0];
	open(my $F,"<$d") || die $!;
	die "Invalid dereference\n" if(index($d,$ENV{S}.'/')!=0);
	substr($d,0,length($ENV{S})+1)='';
	while(defined(my $s=<$F>)){
		chomp($s);
		$s=~s/^\s*((?:menu)?config)\s+(\S+)/$c=$1;$v="$d:$2";next/se;
		$s=~s/^\s*choice\s*$/$c=choice;$v=undef;next/se;
		$s=~s/^\s*(?:def_)?tristate(?:\s+\S*|$)/$tristate{$v}=1;next/se;
		$s=~s/^\s*(?:def_)?bool(?:\s+\S*|$)/if($c eq 'menuconfig'){$menu{$v}=1}else{$bool{$v}=1};next/se;
		$s=~s/^\s*select\s*(\S*)/push @{$select{$1}},$v;next/se;
		$s=~s/(?:If\s+unsure,\s+s|If\s+in\s+doubt,\s+s|S)ay\s+Y\./$yes{$v}=1;next/se;
		$s=~s/(?:If\s+unsure,\s+s|If\s+in\s+doubt,\s+s|S)ay\s+N\./$no{$v}=1;next/se;
	}
	close($F);
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
	my $x;
	for(keys %unset){
		$s=~s/\n(CONFIG_$_=[^\n]*|# CONFIG_$_ is not set)\n/\n/;
	}
	for(keys %config){
		$x=$config{$_};
#		next if(defined($oldconfig{$_}) && $oldconfig{$_} eq $x);
		$x=defined($x)?"CONFIG_$_=$x":"# CONFIG_$_ is not set";
		my $y;
		$s=~s/\n(CONFIG_$_=[^\n]*|# CONFIG_$_ is not set)\n/$y=1;"\n$x\n"/se;
		$s.="$x\n" if(!$y);
	}
	open(my $F,">$_[0]") || die $!;
	print $F $s;
	close($F);
}

sub spl{
	my %cc=('+'=>1,'-'=>1,'~'=>1);
	my $d=$_[0];
	my $c=substr($d,0,1);
	substr($d,0,1)='' if(exists($cc{$c}));
	($c,$d)
}

sub modules{
	return if($_ eq '');
	print "Applying modules: $_\n";
	my ($c,$d)=spl($_);
	my @l=grep(/^$d/,keys %tristate);
	for(@l){
		$_=~s/.*://;
		if($c eq '+'){
			cfg($_,'m');
		}elsif($c eq '-'){
			cfg($_,$defconfig{$_});
		}else{
			cfg($_,$defconfig{$_}?$defconfig{$_}:'m')
		}
	}
}

sub defaults{
	return if($_ eq '');
	print "Applying defaults: $_\n";
	my ($c,$d)=spl($_);
	my @l=grep(/^$d/,keys %menu);
	for(@l){
		$_=~s/.*://;
		if($c eq '-'){
			$unset{$_}=1;
			delete($config{$_});
		}else{
			cfg($_,'y');
		}
	}
	my @l=grep(/^$d/,keys %bool);
	for(@l){
		my $y=$yes{$_};
		$_=~s/.*://;
		if(($c eq '-' && exists($defconfig{$_})) || ($c ne '+' && $defconfig{$_})){
			cfg($_,$defconfig{$_});
		}else{
			$unset{$_}=1;
			delete($config{$_});
			cfg($_,'y') if($y && ($c eq '+' || !defined($defconfig{$_})));
		}
	}
}

sub cfg{
	$set{$_}=1;
	if(defined($_[1])){
		$config{$_[0]}=$_[1];
		return
	}
	return if($off{$_[0]});
	$config{$_[0]}=undef;
	$off{$_[0]}=1;
	for(@{$select{$_[0]}}){
		my $i=$_;
		$i=~s/.*://;
		if(defined($config{$i})){
			print "KERNEL_CONFIG: -$_[0] -> -$i\n";
			cfg($i);
		}
	}
}

sub conf{
	return if($_ eq '');
	my ($c,$d)=spl($_);
	my $y='y';
	$d=~s/(.*?)=(.*)/$y=$2;$1/se;
	my @l=grep(/^$d$/,keys %vars);
	@l=($d) if($#l eq -1);
	for(@l){
		$_=~s/.*://;
		if($c eq '+'){
			cfg($_,'m');
		}elsif($c eq '-'){
			%off={};
			cfg($_);
		}elsif($c eq '~'){
			cfg($_,$oldconfig{$_});
		}else{
			cfg($_,$y);
		}
	}
}

sub Kconfig{
	our (%tristate,%bool,%select,%menu,%yes,%no,%config,%oldconfig,%defconfig,%off,%unset,%vars,%set)=();
	Kclist($ENV{S});
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
	cfg(substr($_,14),$ENV{$_}) for(grep(/^KERNEL_CONFIG_/,keys %ENV));
	set_config("$ENV{S}/.config");
}

if($ARGV[0] eq '-config'){
	print ": \${$_:='$ENV{$_}'}\n" for(grep(/^KERNEL_/,keys %ENV));
}else{
	$ENV{S}||=$ARGV[0]||'.';
	Kconfig();
}

