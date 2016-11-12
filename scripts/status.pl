#!/usr/bin/perl
#Check service statuses: sms-gate, internet

use strict;
use warnings;
use Mojo::UserAgent;
use YAML::XS 'LoadFile';
use FindBin qw($Bin);
use Data::Dumper;

my $cfgfile = $Bin.'/../config.yaml';
my $config = LoadFile($cfgfile);
my $status = {};
my $ua = Mojo::UserAgent->new;
my $flag = 0; #flag of change configuration

#Set status-code of connection to default server
$status->{service} = $ua->get($config->{internet})->res->code || '';

if($status->{service}){
	#Set status-code of sms-gate server
	$status->{sms_service} = $ua->get($config->{sms_gate}."?user=$config->{sms_login}&pass=$config->{sms_pass}&smsid=$config->{sms_id}")->res->code || '';
	
	#Clear garbage statuses if not equal '200 OK'
	$status->{sms_service} = '' if($status->{sms_service} && $status->{sms_service} != 200);

	#Set status-code of target url
	my $tx = $ua->get($config->{target_url_default})->res->code || '';
	
	#Clear garbage statuses if not equal '200 OK'
	$tx = '' if($tx && $tx != 200);
	
	#Set alternative target url if default is not respond
	$status->{target_url} = $tx ? $config->{target_url_default} : $config->{internet};

};

foreach my $key (keys %{$status}){
	if($status->{$key} ne $config->{$key}){
		$config->{$key} = $status->{$key};	
		$flag = 1;

	};
};

if($flag){
	open (CFG, ">", $cfgfile) || die "Can't open config file: $cfgfile. Error: $!";
		foreach my $key (keys %{$config}){
			print CFG "$key: $config->{$key}\n";
		};
	close CFG;

}

1;
