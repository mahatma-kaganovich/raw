#!/usr/bin/perl

$|=1;
$ENV{KERNEL_MODULES}||='+.';
# prefer: "-." - defconfig, "." - defconfig for "y|m", "+." - Kconfig/oldconfig
$ENV{KERNEL_DEFAULTS}||='.';
$ENV{KERNEL_CONFIG}||='
	######
	KALLSYMS_EXTRA_PASS DMA_ENGINE
	BSD_PROCESS_ACCT_V3
	MTRR_SANITIZER IA32_EMULATION LBD
	GFS2_FS_LOCKING_DLM NTFS_RW
	X86_32_NON_STANDARD INTR_REMAP
	ASYNC_TX_DMA DMAR INTR_REMAP BLK_DEV_INTEGRITY
	AMD_IOMMU
	FLATMEM_MANUAL;SPARSEMEM_MANUAL MEMTEST .*FS_XATTR
	MEMORY_HOTPLUG MEMORY_HOTREMOVE
	EXT2_FS_XIP OLPC CIFS_EXPERIMENTAL .+_FSCACHE
	VMI =KVM_CLOCK =KVM_GUEST =XEN =LGUEST_GUEST PVH XEN_PVH
	-BLK_DEV_UB
	KEYBOARD_ATKBD
	CRC_T10DIF
	-VGACON_SOFT_SCROLLBACK FB_BOOT_VESA_SUPPORT FRAMEBUFFER_CONSOLE_ROTATION
	.+_KMS
	IKCONFIG_PROC IKCONFIG EXPERIMENTAL
	NET_RADIO PNP_ACPI PARPORT_PC_FIFO PARPORT_1284 NFTL_RW
	PMC551_BUGFIX CISS_SCSI_TAPE CDROM_PKTCDVD_WCACHE
	SCSI_SCAN_ASYNC IOSCHED_DEADLINE DEFAULT_DEADLINE SND_SEQUENCER_OSS
	SND_FM801_TEA575X_BOOL SND_AC97_POWER_SAVE SCSI_PROC_FS SCSI_FLASHPOINT
	=.+_VENDOR_.+ NET_POCKET
	SYN_COOKIES .+_NAPI
	.+_EDID FB_.+_I2C FB_MATROX_.+ FB_ATY_.+
	FB_.+_ACCEL -FB_HGA_ACCEL FB_SIS_300 FB_SIS_315 FB_GEODE
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
	IP_VS_PROTO_.+
	ISA MCA MCA_LEGACY EISA NET_ISA PCI PCI_LEGACY =RAPIDIO
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
	DEVTMPFS COMPACTION VIA_DIRECT_PROCFS HID_WACOM_POWER_SUPPLY
	HID_PICOLCD_.+ MULTICORE_RAID456
	VGA_SWITCHEROO ACPI_APEI L2TP_V3
	THERMAL_HWMON
	NFS_V4_1 TRANSPARENT_HUGEPAGE
	#always=dangerous_locking TRANSPARENT_HUGEPAGE_MADVISE
	MEMORY_FAILURE =INTEL_IDLE
	XFRM_MIGRATE NET_KEY_MIGRATE
	IPV6_MULTIPLE_TABLES IPV6_SUBTREES IPV6_SIT_6RD
	IPV6_ROUTER_PREF NF_CONNTRACK_ZONES NF_CONNTRACK_EVENTS
	IP_VS_IPV6 DCB MAC80211_MESH MAC80211_RC_PID =MAC80211_RC_MINSTREL_.+
	DEVTMPFS_MOUNT PARPORT_PC_SUPERIO BLK_DEV_XIP
	-NFS_USE_LEGACY_DNS =NFSD_.+ ##-CIFS_.+2 -CIFS_STATS2
	=(?:JOYSTICK|USB|ISDN|JFFS2|MOUSE|RTC|SQUASHFS|ROMFS|BT|DSCC4|ATM|HISAX|GPIO|A11Y|SPI|BCMA|RT2800USB|HOTPLUG_PCI|CIFS|NFS|NFC|OF|POWER_RESET|THERMAL_GOV|PCIE|PWM|EDAC|TCG|SENSORS|TOUCHSCREEN|RMI4)_.+
	-USB_OTG_DISABLE_EXTERNAL_HUB
	#vs.alt_usbkbd_usbmouse USB_HID
	=MEDIA_.+_SUPPORT =MEDIA_CONTROLLER =VIDEO_.+_RC
	=ZRAM_.+_COMPRESS =TUN_VNET_CROSS_LE =VHOST_CROSS_ENDIAN_LEGACY =THERMAL_WRITABLE_TRIPS
	=DRM_GMA.+
	EFI_STUB EFI_MIXED =RANDOMIZE_BASE
	-USB_OTG_(?:WHITELIST|BLACKLIST_HUB)
	=/drivers/(?:mfd|regulator)/.+
	~HISAX_NO_.+
	=.+_(?:PARTITION|FF|X_COMPATIBILITY|PTP|IOMMU|THERMAL|API|THERMAL|DAX|CONFIGFS|OTP|HWMON)
	.+_DUAL_ROLE .+_BY_BOTH
	=NET_SWITCHDEV =NET_FOU_IP_TUNNELS =PCC
	=IRQ_REMAP
	DM_UEVENT =.+_SDIO B43_PHY_N
	CFG80211_WEXT
	CIFS_UPCALL NETCONSOLE_DYNAMIC  NFS_USE_NEW_IDMAPPER
	BPF_JIT FHANDLE HID_BATTERY_STRENGTH XFS_RT
	NUMA_BALANCING ACPI_HMAT
	BINFMT_SCRIPT BINFMT_MISC
	PARAVIRT -PARAVIRT_SPINLOCKS
	=SND_.+_INPUT(?:_.+)?
	=PCI_IOAPIC MICROCODE
	NR_CPUS==!1;-SLUB_CPU_PARTIAL NR_CPUS==!1;SQUASHFS_.+_SINGLE NR_CPUS==1;SQUASHFS_DECOMP_MULTI_PERCPU
	X86==y;-OF
	JFFS2_CMODE_PRIORITY SQUASHFS_.+_DIRECT
	=CPU_FREQ =BLK_DEV_THROTTLING =PM
	NETWORK_PHY_TIMESTAMPING
	MTRR_SANITIZER_ENABLE_DEFAULT=1 NET_L3_MASTER_DEV VIRTUALIZATION==y;-VHOST(?:_.+)?
	LOCKUP_DETECTOR RCU_CPU_STALL_TIMEOUT=60 DEBUG_BUGVERBOSE
	IOSF_MBI X86_INTEL_LPSS X86_AMD_PLATFORM_DEVICE =DRM_MEDFIELD =.+_(?:SOC|SCU)(?:_.+)?
	64BIT==!y;KALLSYMS_BASE_RELATIVE

	EFI==!y;&FB EFI==!y;FB_EFI FB_EFI==!y;DRM_SIMPLEDRM==!m;-DRM_SIMPLEDRM FB_EFI==!y;FB_SIMPLE
	DRM_FBDEV_EMULATION
	FRAMEBUFFER_CONSOLE +FRAMEBUFFER_CONSOLE

	=RXKAD BIG_KEYS
	ARM==y;ARM64==y;-QCOM_.+
	NLS==!y;NLS_CODEPAGE_437 NLS==!y;NLS_ISO8859_1 NLS==!y;NLS_UTF8
	BLK_WBT BLK_TEST_WBT_SQ =CPU_FREQ_GOV_[^_]+
	=BLK_SED_OPAL
	BRCMFMAC_PCIE BRCMFMAC_USB
	=INTEL_RDT_?A? =X86_CPU_RESCTRL INTEL_IOMMU_SVM =INTEL_TURBO_MAX_3 =CHARGER_MANAGER
	ACPI_PCI_SLOT ACPI_APEI_PCIEAER ACPI_APEI_GHES ACPI_APEI_MEMORY_FAILURE
	ISA_BUS
	XDP_SOCKETS
	-.+_NOCODEC_.+
	WIRELESS==!y;KEY_DH_OPERATIONS
	CRYPTO_DEV_CCP PCI_MESON PCI_ENDPOINT PCIE_DW_PLAT_EP
	-SAMPLES ENERGY_MODEL KEYS_REQUEST_CACHE
	UEVENT_HELPER
	TLS_DEVICE
	SERIAL_8250 SERIAL_8250_CONSOLE
	FRAMEBUFFER_CONSOLE_DEFERRED_TAKEOVER
	DRM_AMDGPU_CIK
	DVB_NET
	=SCTP_COOKIE_HMAC_.+
	=MEDIA_CEC_RC CEC_CORE==!y;=.+_CEC CEC_CORE==!m;=.+_CEC
	.+_PSTORE_DEFAULT_DISABLE
	INPUT_PCSPKR==!y;-SND_PCSP
	=SCTP_COOKIE_HMAC_.+
	#=y: EDAC SERIAL_DEV_BUS
	#Kconfig NUMA
	#ubuntu,suse TASKS_RCU
	#usb_mouse_fix HID
	###beleave_last_binutils: X86_X32
	###bugs: -TR -ECONET
	###udev: -IDE
	###cpio: -IKHEADERS
	###3.14.0_nosound SND_HDA_CODEC_.+ SND_HDA_GENERIC
	#bug_ubuntu_17.10 -SPI_INTEL_SPI_PLATFORM
	#compat_DRM_INTEL/RADEON_SI KCMP;CHECKPOINT_RESTORE
	-SYSTEM_TRUSTED_KEYRING #or:X509_CERTIFICATE_PARSER
	#######
	';
$ENV{KERNEL_CONFIG2}||='?RAPIDIO RAPIDIO_DMA_ENGINE==y;?DMA_ENGINE (?:.+_)?PTP_.*CLOCK.*==y;-NETWORK_PHY_TIMESTAMPING';


%cc=(
	'+'=>'m',
	'-'=>'n (recursive)',
	'~'=>'remove/oldconfig-default',
	'!'=>'remove/undef',
	'='=>'y if undefined bool',
	'&'=>'m->y recursive embed',
	'?'=>'n if none embedded module dependences (use after detects)',
	'%'=>'%from%to%...',
	'#'=>'#',
);

sub Kcload{
	die "Unresolved Kconfig: $_[0]\n" if(index($_[0],'$')>=0);
	my ($c,$v,$v1,%ch);
	my $d=$_[0];
	open(my $F,"<$d") || return; # || die "$! ($d)";
	die "Invalid dereference\n" if(index($d,$ENV{S}.'/')!=0);
	substr($d,0,length($ENV{S})+1)='';
	while(defined(my $s=<$F>)){
		while(substr($s,-2) eq "\\\n"){substr($s,-2)=<$F>};
		$s=~s/#.*//gs;
		$s=~s/\s*$//s;
		$s=~s/^\s*((?:menu)?config)\s+(\S+)/
			$order1{$2}=++$order1;
			$c=$1;$v1=$2;
			for(my $i;exists($depends{$v="$d$i:$2"});$i++){};
			$ch{$v}=$2;
			push @{$depends{$v}},@if;
		next/e;
		$s=~s/^\s*((?:comment|mainmenu|menu)\s|endmenu$)/$c=$1;$v1=$v=undef;next/e;
		$s=~s/^\s*choice$/
			$c=$1;$v1=$v=':_choice';
			delete($depends{$v});
			%ch=();
		next/e;
		$s=~s/^\s*endchoice$/
			$c=$1;$v1=$v=':_choice';
			for(keys %ch){
				my %dc=%ch;
				delete($dc{$_});
				push @{$depends{$_}},(map{'!'.$_}values %dc),@{$depends{$v}};
				my $x=$ch{$_};
				if(exists($choice{$x})){
					print "Multiple choices: $x\n" if(!exists($multichoice{$x}));
					$multichoice{$x}=undef;
				}
				$multichoice{$x}=undef if(!$bool{$_});
				push @{$choice{$x}},values %dc;
			}
			delete($depends{$v});
			%ch=();
		next/e;
		$s=~s/^if\s+(.*)$/$c='if';push @if,prelogic($1);next/e;
		$s=~s/^endif$/$c='endif';pop @if;next/e;
		if(my ($i)=$s=~/^\s*(?:def_tristate|def_bool|default)\s+(.+)/){
			if($prefer_kconfig || ! ($i=~/(?:^[\"a-z0-9]\S*|[\! ]EXPERT)$/)){
				$undef{$v1}=undef;
				#print "DEF: $v1 $i\n";
			}
#			$i=prelogic($i) if(!($i=~s/^(.*)\s+if\s+(.*)$/prelogic($1).' if '.prelogic($2)/e));
#			$default{$v}=$i;
		}
		$s=~s/^\s*(?:def_)?tristate(?:\s+\S*|$)/$tristate{$v}=1;$tristate_{$v1}=1;next/e;
		$s=~s/^\s*(?:def_)?bool(?:\s+\S*|$)/if($c eq 'menuconfig'){$menu{$v}=1}else{$bool{$v}=1};next/e;
		$s=~s/^\s*select\s+(.*)$/push @{$select{preif($1)}},$v;next/e;
		$s=~s/^\s*depends\s+on\s+(.*)$/push @{$depends{$v}},prelogic($1);next/e;
		$s=~s/(?:If\s+(?:[a-z\s]*\s)?(?:unsure|doubts?)(?:\s+about\s+this)?,\s+s|S)ay\s+\'?([YN])\'?(?:\s+here)?\./${$1 eq 'Y'?'yes':'no'}{$v}=1;next/e;
		next if(!$ENV{SRCARCH});
		$s=~s/^\s*option\s+env="(\w+)"/$env{$1}=1;next/e;
		$s=~s/\$\((\w+)\)/exists($ENV{$1}) || print "ENV: $1\n";exists($ENV{$1})?$ENV{$1}:"\$($1)"/eg;
		$s=~s/\$\((.*\W.*)\)/print "ENV?: $1\n";"\$($1)"/e;
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
		($s=~s/^CONFIG_([^=\s]*)=(.*)/$config{$1}=$2 if(!exists($undef{$1}));$order{$_}=++$order;$vars{$1}=1;next/se) ||
		($s=~s/^# CONFIG_([^=\s]*) is not set/$config{$1}=undef;$order{$_}=++$order;$vars{$1}=1;next/se);
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
	$s=~s/\n(?:# )?CONFIG_$_[= ].*//g for(keys %undef);
	# de-randomized:
	for(sort{$order{$a} && $order{$b} ? $order{$a}<=>$order{$b} : $order1{$a} && $order1{$b} ? $order1{$a}<=>$order1{$b} : $a cmp $b}keys %config){
		defined(my $y=$config{$_})||next;
		$_=~/^["'_]/ && next; #"
#		next if(defined($oldconfig{$_}) && $oldconfig{$_} eq $y);
		$y=$y ne ''?"CONFIG_$_=$y":"# CONFIG_$_ is not set";
		$s.="$y\n" if(!($s=~s/\nCONFIG_$_=[^\n]*\n|\n# CONFIG_$_ is not set\n/\n$y\n/s));
	}
	open(my $F,">$_[0]") || die $!;
	print $F $s;
	close($F);
}

sub spl{
	my $d=$_[0];
	my $c=substr($d,0,1);
	if(exists($cc{$c})){
		if($c eq '%'){
			if(!($d=~s/^\%(.*?)\%(.*?)\% /$from=$1;$to=$2;''/se)){
				$c='x';
			}
		}else{
			substr($d,0,1)=''
		}
	}
	($c,$d)
}

sub modules{
	return if($_[0] eq '');
	print "Applying modules: $_[0]\n";
	my ($c,$d)=spl($_[0]);
	for(grep(/^$d/,keys %tristate)){
		my $i=$_;
		$i=~s/.*://;
		if($c eq '+'){
			cfg($i,'m');
		}elsif($c eq '-'){
			cfg($i,$defconfig{$i});
		}elsif($c eq '%'){
			cfg($i,$to) if($config{$i} eq $from);
		}elsif($c ne '=' || !defined($config{$_})){
			cfg($i,$defconfig{$i}?$defconfig{$i}:'m')
		}
	}
	msg($_[0]);
}


sub defaults{
	return if($_[0] eq '');
	print "Applying defaults: $_[0]\n";
	my ($c,$d)=spl($_[0]);
	for(grep(/^$d/,keys %menu)){
		my $i=$_;
		$i=~s/.*://;
		if($c eq '-'){
			$unset{$i}=1;
			delete($config{$i});
		}else{
			cfg($i,'y');
		}
	}
	for(grep(/^$d/,keys %bool)){
		my $y=$yes{$_};
		my $i=$_;
		$i=~s/.*://;
		if(($c eq '-' && exists($defconfig{$i})) || ($c ne '+' && $defconfig{$i})){
			cfg($i,$defconfig{$i});
		}else{
			$unset{$i}=1;
			delete($config{$i});
			cfg($i,'y') if($y && ($c eq '+' || !defined($defconfig{$i})));
		}
	}
	for(keys %config){
		$config{$_}=undef if($config{$_} eq '');
	}
	msg($_[0]);
}

sub prelogic{
	my $s=$_[0];
	my $i;
	$s=~s/("(?:\\"|[^"])*"|'(?:\\'|[^'])*')/if(exists($config{$1})){$i=$config{$1}}else{$config{$config{$1}=$i='_'.++$NV}=$1}$i/ge;
	$s=~s/\s+//g;
	$s
}

sub preif{
	my $s=$_[0];
	$s=~s/\s+if\s+(.*)$/' if '.prelogic($1)/e;
	$s;
}

sub logic{
	my $s=$_[0];
	while(
		($s=~s/\((\w+)\)/$config{$1}?'y':'n'/ge)||
		($s=~s/!(\w+)/$config{$1}?'n':'y'/ge)||
		($s=~s/(\w+)!=(\w+)/$config{$1} ne $config{$2}?'y':'n'/ge)||
		($s=~s/(\w+)=+(\w+)/$config{$1} eq $config{$2}?'y':'n'/ge)||
		($s=~s/(\w+)\&\&(\w+)/$config{$1}&&$config{$2}?'y':'n'/ge)||
		($s=~s/(\w+)\|\|(\w+)/$config{$1}||$config{$2}?'y':'n'/ge)
	){}
	exists($config{$s})||(($s=~/\W/ || ($s ne $_[0])) && print "Warning: invalid expression: '$_[0]' ('$s')\n");
	$config{$s}
}

sub dep{
my (%l,%n,$i,$i1);
$i=1;
while($i ne $i1){
	$i1=$i;
	$i=join('|',@_,sort keys %n)||'.*';
	%l=();
	for my $c (grep(/^.*\/$i$/,keys %tristate,keys %bool,keys %menu)){
		my $x=$c;
		$x=~s/.*://;
		next if($l{$x});
		$l{$x}=1;
		for(grep(/(?:^|\W)$i(?:\W|\$)/,@{$depends{$c}})){
			logic($_) && next;
			$l{$x}=undef;
			last;
		}
	}
	for(keys(%l)){
		$n{$_}=cfg($_) if(!$l{$_});
	}
}
keys %n;
}

sub depcfg{
	$config{$_[0]} || return 1;
	my (%c,%x,$e);
	%c=%config;
	cfg(@_);
	for(keys %config){
		$x{$_}=undef if($c{$_} ne $config{$_});
	}
	dep(keys %x);
	for my $i ($_[0],keys %config){
		if($i eq $_[0]){
			$config{$i} || next;
		# no y->n tristate
		}elsif($c{$i} ne 'y' || $config{$i} || !exists($tristate_{$i})){ 
			next;
		}
		$e.=" $i=$c{$i}->$config{$i}";
	}
	if($e){
		$msg=" ! $e";
		%config=%c;
		return 0;
	}
	1;
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
if(!defined($_[1])){
	return 1 if(exists($off{$_[0]}));
	$off{$_[0]}=1;
	for(sel($_[0],\%select)){
		my $i=$_;
		$i=~s/.*://;
		my $r=$config{$i};
		cfg($i) || return 0;
		$msg.=" -$i" if($r);
	}
}elsif(exists($choice{$_[0]}) && $_[1] eq 'y'){
	for(@{$choice{$_[0]}}){
		cfg($_) if(exists($config{$_}) && $config{$_} eq 'y' && $_ ne $_[0]);
	}
}
dep($_[0]) if($config{$_[0]} ne ($config{$_[0]}="$_[1]"));
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
	# $select{$_[0]) may be checked only for auto-selectable choises (not for human)
}

sub onoff{
	my $v=$config{$_[0]};
#	for(grep(/(?:^|\W)$_[0](?:\W|$)/,@{$depends{$_[1]}})){
	for(@{$depends{$_[1]}}){
		$config{$_[0]}=$_[2];
		logic($_) || next;
		$config{$_[0]}='';
		logic($_) && next;
		$config{$_[0]}=$v;
		return 1;
	}
	$config{$_[0]}=$v;
	$order{$_[0]}=++$order;
	0;
}

sub conf{
    return if($_[0] eq '');
    for(split(/;/,$_[0])){
	my ($c,$d)=spl($_);
	return if($c eq '#');
	my $y='y';
	my ($eq,$ne);
	$ne=($eq=($d=~s/(.*?)=(.*)/$y=$2;$1/se) && ($y=~s/^=//)) && ($y=~s/^\!//);
	my @l;
	if(substr($d,0,1) eq '/'){
		my %ll;
		substr($d,0,1)='^';
		for(grep(/$d$/,keys %tristate,keys %bool,keys %menu)){
			my $i=$_;
			$i=~s/.*://;
			$ll{$i}=1 if(exists($vars{$i}))
		}
		@l=keys %ll;
	}elsif(exists($vars{$d})){
		@l=($d);
	}else{
		@l=grep(/^$d$/,keys %vars);
		@l=($d) if($#l==-1 && !($d=~/[^A-Za-z0-9_]/) && $_[0] eq $_);
	}
	for(@l){
		# ignore "whole choice" wildcards
		if(exists($choice{$_})){
			my %ch;
			$ch{$_}=1 for(@{$choice{$_}});
			delete($ch{$_}) for(@l);
			if(!%ch){
				print "KERNEL_CONFIG: $c$d choice $_ @{$choice{$_}}\n";
				$ch{$_}=1 for(@l);
				delete($ch{$_}) for($_,@{$choice{$_}});
				@l=keys %ch;
			}
		}
	}
	for(sort @l){
		if($c eq '+'){
			if(exists($tristate_{$_})){
				cfg($_,'m');
			}else{
				print "WARNING: +$_ - not tristate\n";
			}
		}elsif($c eq '-'){
			%off=();
			cfg($_);
		}elsif($c eq '&'){
			if(exists($tristate_{$_})){
				_and($_,$y,$_);
			}else{
				print "WARNING: \&$_ - not tristate\n";
			}
		}elsif($c eq '~'){
			exists($oldconfig{$_})?cfg($_,$oldconfig{$_}):delete($config{$_});
		}elsif($c eq '!'){
			delete($config{$_});
			$undef{$_}=undef;
		}elsif($c eq '%'){
			cfg($_,$to) if($config{$_} eq $from && ($to ne 'm' || exists($tristate_{$_})));
		}elsif($c eq '?'){
			%off=();
			depcfg($_);
		}elsif($c ne '=' || !defined($config{$_})){
			if(!$eq){
				cfg($_,$y);
			}elsif(($ne xor ($config{$_} eq $y || ($y eq 'n' && $config{$_} eq '')))){
				goto ex;
			};
		}
	}
	last if(@l && !$eq);
    }
ex:
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
	our (%tristate,%bool,%select,%menu,%yes,%no,%config,%oldconfig,%defconfig,%off,%unset,%vars,@if,$NV,%tristate_)=();
	%config=('y'=>'y','m'=>'m','n'=>'',''=>'',
		"'y'"=>'y',"'m'"=>'m',"'n'"=>'n',
		'"y"'=>'y','"m"'=>'m','"n"'=>'m',
	);
	if($ENV{SRCARCH} && arch() && -e "$ENV{S}/Kconfig" && -e "$ENV{S}/arch/$ENV{SRCARCH}/Kconfig"){
		print "SRCARCH=$ENV{SRCARCH}\n";
		Kcload("$ENV{S}/Kconfig");
	}else{
		print "!SRCARCH\n";
		delete($ENV{SRCARCH});
		Kclist($ENV{S});
	}
	for(keys %multichoice){
		delete($choice{$_}) for(@{$choice{$_}});
		# Use of freed value in iteration
		delete($choice{$_})
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
#	dep();
	%oldconfig=%config;
	defaults($_) for(split(/\s+/,$ENV{KERNEL_DEFAULTS}));
	modules($_) for(split(/\s+/,$ENV{KERNEL_MODULES}));
	print "Applying config: $ENV{KERNEL_CONFIG}\n";
	conf($_) for(split(/\s+/,$ENV{KERNEL_CONFIG}));
	for(sort grep(/^KERNEL_CONFIG_/,keys %ENV)){
		my $x=$ENV{$_};
		$x="\"$x\"" if($x=~/^[^\"0-9].*[^\"]$/s);
		cfg(substr($_,14),$x);
		msg("$_=$x");
	}
#	dep();
	set_config("$ENV{S}/.config");
}

sub config{
	print ": \${$_:='$ENV{$_}'}\n" for(sort grep(/^KERNEL_/,keys %ENV));
}

if($ARGV[0]=~/^-(?:help|-help|h|--h)$/){
	config;
	print "---Modifiers:\n";
	print "'$_' - $cc{$_}\n" for(sort keys %cc);
	exit
}elsif($ARGV[0] eq '-config'){
	config;
	exit;
}elsif($ARGV[0] eq '-prefer-kconfig'){
	$prefer_kconfig=1;
	shift(@ARGV);
}elsif($ARGV[0] eq '-relax'){
	*dep=sub{ ();};
	shift(@ARGV);
}
$ENV{S}||=$ARGV[0]||'.';
Kconfig();
print 'Kconfig.pl times='.join("/",times)."\n";
