#!/usr/bin/perl
use Encode qw(:all);
use Purple;

# examples (environment):
#	TWISTED_ENCODING='.*/cp1251' - test all server encodings with client=cp1251 (see debug window)
#	TWISTED_ENCODING='/cp1251' - force client=cp1251

# windows encodings only
my %langs=(
"en" => "CP1252",
"invariant" => "CP1252",
"invalid" => "CP1252",
"system" => "CP1252",
"af-ZA" => "CP1252",
"sq-AL" => "CP1252",
"gsw-FR" => "CP1252",
"am-ET" => "UNICODE",
"ar-SA" => "CP1256",
"ar-IQ" => "CP1256",
"ar-EG" => "CP1256",
"ar-LY" => "CP1256",
"ar-DZ" => "CP1256",
"ar-MA" => "CP1256",
"ar-TN" => "CP1256",
"ar-OM" => "CP1256",
"ar-YE" => "CP1256",
"ar-SY" => "CP1256",
"ar-JO" => "CP1256",
"ar-LB" => "CP1256",
"ar-KW" => "CP1256",
"ar-AE" => "CP1256",
"ar-BH" => "CP1256",
"ar-QA" => "CP1256",
"hy-AM" => "UNICODE",
"as-IN" => "UNICODE",
"az-AZ-Latn" => "CP1254",
"az-AZ-Cyrl" => "CP1251",
"ba-RU" => "UNICODE",
"eu-ES" => "CP1252",
"be-BY" => "CP1251",
"bn-IN" => "UNICODE",
"bs-BA-Cyrl" => "CP1251",
"bs-BA-Latn" => "CP1250",
"br-FR" => "CP1251",
"bg-BG" => "CP1251",
"my-MM" => "UNICODE",
"ca-ES" => "CP1252",
"zh-CHS" => "CP936",
"zh-TW" => "CP950",
"zh-CN" => "CP936",
"zh-HK" => "CP950",
"zh-SG" => "CP936",
"zh-MO" => "CP950",
"zh-CHT" => "CP950",
"co-FR" => "CP1252",
"hr-HR" => "CP1250",
"hr-BA" => "CP1250",
"cs-CZ" => "CP1250",
"da-DK" => "CP1252",
"gbz-AF" => "CP1256",
"dv-MV" => "UNICODE",
"nl-NL" => "CP1252",
"nl-BE" => "CP1252",
"en-US" => "CP1252",
"en-GB" => "CP1252",
"en-AU" => "CP1252",
"en-CA" => "CP1252",
"en-NZ" => "CP1252",
"en-IE" => "CP1252",
"en-ZA" => "CP1252",
"en-JA" => "CP1252",
"en-CB" => "CP1252",
"en-BZ" => "CP1252",
"en-TT" => "CP1252",
"en-ZW" => "CP1252",
"en-PH" => "CP1252",
"en-IN" => "CP1252",
"en-MY" => "CP1252",
"en-SG" => "CP1252",
"et-EE" => "CP1257",
"fo-FO" => "CP1252",
"fil-PH" => "CP1252",
"fi-FI" => "CP1252",
"fr-FR" => "CP1252",
"fr-BE" => "CP1252",
"fr-CA" => "CP1252",
"fr-CH" => "CP1252",
"fr-LU" => "CP1252",
"fr-MC" => "CP1252",
"fy-NL" => "CP1252",
"gl-ES" => "CP1252",
"ka-GE" => "UNICODE",
"de-DE" => "CP1252",
"de-CH" => "CP1252",
"de-AT" => "CP1252",
"de-LU" => "CP1252",
"de-LI" => "CP1252",
"el-GR" => "CP1253",
"kl-GL" => "CP1252",
"gu-IN" => "UNICODE",
"ha-NG-Latn" => "CP1252",
"he-IL" => "CP1255",
"hi-IN" => "UNICODE",
"hu-HU" => "CP1250",
"is-IS" => "CP1252",
"id-ID" => "CP1252",
"iu-CA-Cans" => "UNICODE",
"iu-CA-Latn" => "CP1252",
"ga-IE" => "CP1252",
"xh-ZA" => "CP1252",
"zu-ZA" => "CP1252",
"it-IT" => "CP1252",
"it-CH" => "CP1252",
"ja-JP" => "CP932",
"kn-IN" => "UNICODE",
"kk-KZ" => "CP1251",
"kh-KH" => "UNICODE",
"qut-GT" => "CP1252",
"rw-RW" => "CP1252",
"kok-IN" => "UNICODE",
"ko-KR" => "CP949",
"ky-KG" => "CP1251",
"lo-LA" => "UNICODE",
"lv-LV" => "CP1257",
"lt-LT" => "CP1257",
"wee-DE" => "CP1252",
"lb-LU" => "CP1252",
"mk-MK" => "CP1251",
"ms-MY" => "CP1252",
"ms-BN" => "CP1252",
"ml-IN" => "UNICODE",
"mt-MT" => "CP1252",
"mi-NZ" => "CP1252",
"arn-CL" => "CP1252",
"mr-IN" => "UNICODE",
"moh-CA" => "CP1252",
"mn-MN" => "CP1251",
"mn-CN" => "UNICODE",
"ne-NP" => "UNICODE",
"nb-NO" => "CP1252",
"nn-NO" => "CP1252",
"oc-FR" => "CP1252",
"or-IN" => "UNICODE",
"ps-AF" => "UNICODE",
"fa-IR" => "CP1256",
"pl-PL" => "CP1250",
"pt-BR" => "CP1252",
"pt-PT" => "CP1252",
"pa-IN" => "UNICODE",
"quz-BO" => "CP1252",
"quz-EC" => "CP1252",
"quz-PE" => "CP1252",
"ro-RO" => "CP1250",
"rm-CH" => "CP1252",
"ru-RU" => "CP1251",
"smn-FI" => "CP1252",
"smj-NO" => "CP1252",
"smj-SE" => "CP1252",
"se-NO" => "CP1252",
"se-SE" => "CP1252",
"se-FI" => "CP1252",
"sms-FI" => "CP1252",
"sma-NO" => "CP1252",
"sma-SE" => "CP1252",
"sa-IN" => "UNICODE",
"sr-SP-Cyrl" => "CP1251",
"sr-BA-Cyrl" => "CP1251",
"sr-SP-Latn" => "CP1250",
"sr-BA-Latn" => "CP1250",
"ns-ZA" => "CP1252",
"tn-ZA" => "CP1252",
"si-LK" => "UNICODE",
"sk-SK" => "CP1250",
"sl-SI" => "CP1250",
"es-ES-ts" => "CP1252",
"es-MX" => "CP1252",
"es-ES" => "CP1252",
"es-GT" => "CP1252",
"es-CR" => "CP1252",
"es-PA" => "CP1252",
"es-DO" => "CP1252",
"es-VE" => "CP1252",
"es-CO" => "CP1252",
"es-PE" => "CP1252",
"es-AR" => "CP1252",
"es-EC" => "CP1252",
"es-CL" => "CP1252",
"es-UY" => "CP1252",
"es-PY" => "CP1252",
"es-BO" => "CP1252",
"es-SV" => "CP1252",
"es-HN" => "CP1252",
"es-NI" => "CP1252",
"es-PR" => "CP1252",
"es-US" => "CP1252",
"sutu" => "UNICODE",
"sw-KE" => "CP1252",
"sv-SE" => "CP1252",
"sv-FI" => "CP1252",
"syr-SY" => "UNICODE",
"tg-TJ-Cyrl" => "CP1251",
"ber-DZ" => "CP1252",
"ta-IN" => "UNICODE",
"tt-RU" => "CP1251",
"te-IN" => "UNICODE",
"th-TH" => "CP874",
"bo-CN" => "UNICODE",
"bo-BT" => "UNICODE",
"tr-TR" => "CP1254",
"tk-TM" => "CP1251",
"ug-CN" => "CP1256",
"uk-UA" => "CP1251",
"wen-DE" => "CP1252",
"ur-PK" => "CP1256",
"tr-IN" => "CP1256",
"uz-UZ-Latn" => "CP1254",
"uz-UZ-Cyrl" => "CP1251",
"vi-VN" => "CP1252",
"cy-GB" => "CP1252",
"wo-SN" => "CP1252",
"sah-RU" => "CP1251",
"ii-CN" => "UNICODE",
"yo-NG" => "UNICODE"
);

my @e=split(/\//,$ENV{'TWISTED_ENCODING'});

my $lang=$ENV{'LANG'};
$lang=~s/[\.\@].*//g;
$lang=~s/_/-/g;

my @client_enc=all_enc($e[1]?
	grep(/^$e[1]$/i,Encode->encodings(":all")):
	resolve_alias($langs{$lang}||'cp1252')||resolve_alias('cp1252')
);

my @server_enc=all_enc($e[0]?
	grep(/^$e[0]$/i,Encode->encodings(":all")):
	values %langs
);

my %learn;

%PLUGIN_INFO = (
    perl_api_version => 2,
    name => "Double Encoding (twisted encoding)",
    version => "0.3",
    summary => "Repair double encoded messages (usually ICQ->Jabber).",
    description => "Decoding double encoding: client[".join(',',@client_enc)."]->server[auto]->you[utf8] (usually ICQ -> foreign Jabber). Your language detected from LANG environment.",
    author => "Denis Kaganovich <mahatma\@eu.by>",
    url => "http://raw.googlecode.com/svn/trunk/x11-plugins/pidgin-twisted-encoding/files/",
    load => "plugin_load",
    unload => "plugin_unload"
);
sub plugin_init {
    return %PLUGIN_INFO;
}
sub plugin_load {
    Purple::Signal::connect(Purple::Conversations::get_handle(),'wrote-im-msg',$_[0],\&im_received,'wrote-im-msg');
}
sub plugin_unload {
}

sub im_received {
	my $id=$_[0]->get_username()." -> ".$_[1];
	my $ss=$_[2];
	my $l=length($ss);
	my %dup=($ss=>1);
	my ($s,$c,$st);
	utf8::encode($s=$ss);
	return if($_[2] eq $s);
	for $st (0..1){
		for ($st?@client_enc:@{$learn{$id}[1]}){
			next if(length(encode($_,$s=$ss,HTMLCREF))==$l);
			for $c ($st?@server_enc:@{$learn{$id}[0]}){
				next if(length($s=encode($c,$s=$ss,HTMLCREF))!=$l);
				next if(length($s=decode($_,$s,HTMLCREF))!=$l);
				$dup{$s}=[[$c],[$_]];
				Purple::Debug::info("twist-enc plugin", "encodings: $c/$_ $id message: $s\n");
			}
		}
		delete($dup{$ss});
		my @r=keys(%dup);
		$_[3]->write($_[1],$_,$_[4],time) for(@r);
		if($#r==0){
			$learn{$id}=$dup{$r[0]} if($st);
			last;
		}
	}
0
}

sub all_enc{
	# prevent debug message
	my %enc=('Internal'=>1);
	for (@_){
		$_=resolve_alias($_);
		$enc{$_} || eval('encode($_,my $x="test");$enc{$_}=1');
	}
	for('','UNICODE','Internal','utf-8',@client_enc){
	    delete($enc{$_});
	    delete($enc{resolve_alias($_)});
	}
	keys %enc;
}

