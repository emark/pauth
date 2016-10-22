#!/usr/bin/perl
#Check service statuses: sms-gate, internet

use strict;
use warnings;
use Mojo::UserAgent;
use YAML::XS 'LoadFile';
use FindBin qw($Bin);

my $cfgfile = $Bin.'/../config.yaml';
my $config = LoadFile($cfgfile);

my $ua = Mojo::UserAgent->new;

#Set status-code of connection to default server
$config->{service} = $ua->get($config->{internet})->res->code || '';

if($config->{service}){
	#Set status-code of sms-gate server
	$config->{sms_service} = $ua->get($config->{sms_gate}."?user=$config->{sms_login}&pass=$config->{sms_pass}&smsid=$config->{sms_id}")->res->code || '';
	
	#Clear garbage statuses if not equal '200 OK'
	$config->{sms_service} = '' if($config->{sms_service} && $config->{sms_service} != 200);

};

open (CFG, ">", $cfgfile) || die "Can't open config file: $cfgfile. Error: $!";
	foreach my $key (keys %{$config}){
		print CFG "$key: $config->{$key}\n";
	};
close CFG;

1;
