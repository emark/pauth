#!/usr/bin/perl -w
#Notification via sms gate

use strict;
use DBIx::Custom;
use Mojo::UserAgent;
use YAML::XS 'LoadFile';
use FindBin qw($Bin);
use integer;

my $config = LoadFile($Bin.'/../config.yaml');

my $dbi = DBIx::Custom->connect(
   dsn => "dbi:mysql:database=$config->{database}",
   user => $config->{user},
   password => $config->{pass},
   option => {mysql_enable_utf8 => 1}
);

my $ua = Mojo::UserAgent->new;

&get_queue;

sub get_queue(){
	my $result = ''; #Sms-gate response

	#Get token for prepare sms codes
	my @tokens = $dbi->select(
		table => 'notify_q',
		column => ['token'],
		where => 'result is null',
	)->flat;

	#Get recipients for sendind sms
	my $rcpts = $dbi->select(
		table => 'clients',
		column => ['phone','code','token'],
		where => {token => \@tokens},
	)->fetch_hash_all;
	
	#Send sms via sms-gate, write result to database
	foreach my $rcpt (@{$rcpts}){
		$result = &send_sms($rcpt->{phone},$rcpt->{code});
	
		$dbi->update(
			{result => $result},
			table => 'notify_q',
			where => {token => $rcpt->{token}},
		);
	};

};

sub send_sms(){
	my ($phone,$code) = @_;
	my $text = "$code%20%D0%BA%D0%BE%D0%B4%20%D1%80%D0%B5%D0%B3%D0%B8%D1%81%D1%82%D1%80%D0%B0%D1%86%D0%B8%D0%B8%20%D1%83%D1%81%D1%82%D1%80%D0%BE%D0%B9%D1%81%D1%82%D0%B2%D0%B0";
	my $result = '';
	my $tx = $ua->post("http://$config->{'sms_gate'}?method=push_msg&email=$config->{'sms_login'}&password=$config->{'sms_pass'}&phone=+7$phone&text=$text&sender_name=$config->{'sms_sender'}&test=$config->{sms_test}");

	if (my $res = $tx->success){
		$result = $res->body;

	}else{
		my $err = $tx->error;
		$result = "Errors: $err->{code}";

	};

	return $result;
};

1;
