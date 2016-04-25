#!/usr/bin/perl -w

use strict;
use integer;
use CGI;
use DBIx::Custom;
use Net::ARP;
use HTML::Template;
use YAML::XS 'LoadFile';

my $config = LoadFile('config.yaml');

my $dbi = DBIx::Custom->connect(
   dsn => "dbi:mysql:database=$config->{database}",
   user => $config->{user},
   password => $config->{pass},
   option => {mysql_enable_utf8 => 1}
);

my $q = CGI->new();
my $params = $q->Vars;

my $template = 'index'; #Default template name
my %route = (
			'index' => \&index,
			'register' => \&register,
			'verify' => \&verify,
			);

if($params->{phone} && $params->{code}){
	$template = 'verify';

}elsif($params->{phone}){
	$template = 'register' if &phone_check();

}else{
	&index;

};

my $tpl = HTML::Template->new(filename => 'tpl/'.$template.'.tpl');

my $func = $route{$template};
&$func();

print "Content-Type: text/html\n\n", $tpl->output;

sub phone_check(){
	my $phone = $params->{phone};
	return 1 if($phone=~m/^\d{10}$/);
};

sub index(){

};

sub register(){
	my $code = 0; # Generate sms code
	while ($code < 100000){
		$code = int(rand(999999));
	};	

	$dbi->insert(
		{
			phone => $params->{phone},
			ip => $ENV{REMOTE_ADDR},
			code => $code,
		},
		ctime => 'cdate',
		table => 'clients',
	);
	
	$tpl->param(
		code => $code,
		phone => $params->{phone},
	);
};

sub verify(){
	my $msg = '';

	my $verify = $dbi->select(
		table => 'clients',
		columns => ['id,','code','ip','mac'],
		where => {phone => $params->{phone}},
	)->fetch_hash;

	if(($verify->{code} eq $params->{code})){
		my $mac = Net::ARP::arp_lookup($config->{dev},$verify->{ip});
		if ($mac ne 'unknown'){
			$dbi->update(
				{mac => $mac},
				table => 'clients',
				where => {id => $verify->{id}},	
			);
			$msg = "Регистрация прошла успешно. В течение 5 минут будет организован доступ в интернет.";
		
		}else{
			$msg = 'Ошибка в определении сетевого адреса устройства.';

		};
	}else{
		$msg = "Код регистрации введен неверно. Повторите ввод."; 
		$tpl->param(phone => $params->{phone});
	}

	$tpl->param(msg => $msg);
};
