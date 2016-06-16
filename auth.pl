#!/usr/bin/perl -w
#Web-authorisation script

use strict;
use integer;
use CGI;
use DBIx::Custom;
use Net::ARP;
use HTML::Template;
use YAML::XS 'LoadFile';

my $config = LoadFile('config.yaml');

my $dbi = DBIx::Custom->connect(
   dsn => "dbi:mysql:database=$config->{'database'}",
   user => $config->{'user'},
   password => $config->{'pass'},
   option => {mysql_enable_utf8 => 1}
);

my $q = CGI->new();
my $params = $q->Vars;

my $remote_ip = $ENV{REMOTE_ADDR}; #Client remote address

my $msg = ''; #Help message for templates
my $template = 'index'; #Default template name
my %route = (
			'index' => \&index,
			'register' => \&register,
			'verify' => \&verify,
			);

if($params->{'phone'} && $params->{'code'}){
	$template = 'verify';

}elsif($params->{'phone'}){
	$template = 'register' if &phone_check();

};

my $tpl = HTML::Template->new(filename => 'tpl/'.$template.'.tpl');

my $func = $route{$template};
&$func();

print "Content-Type: text/html\n\n", $tpl->output;


sub phone_check(){
	my $phone = $params->{'phone'};
	return 1 if($phone=~m/^\d{10}$/); #Check for 10 digits in phone number

};

sub index(){
	$msg = 'Введите номер телефона для получения смс&ndash;сообщения с кодом доступа в интернет.';
	
	if($params->{'phone'}){
		$msg = 'Ошибка. Укажите номер мобильного телефона. Не более 10 цифр.';

	};
	$tpl->param(
		msg => $msg,
		phone => $params->{'phone'},
	);

};

sub register(){
	my $code = 0; # Generate sms code 4 digits
	while ($code < 1000){
		$code = int(rand(9999));
	};	
	
	my $token = ''; #Token uses for identification clients id
	my @dict = (0..9,'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z','a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z');

	for (my $i=0; $i<30; $i++){
    	$token = $token.$dict[rand(61)];
    };

	my $phone = $params->{'phone'};
	my $client = $dbi->select(
		table => 'clients',
		column => ['id'],
		where => [
			['or',':phone{=}',':ip{=}'],
			{phone => $phone, ip => $remote_ip},
		],
	)->value;

	if(!$client){ #Create new registration
		$dbi->insert(
			{
				phone => $phone,
				ip => $remote_ip,
				code => $code,
				token => $token,
			},
			ctime => 'cdate',
			table => 'clients',
		);
		
		#Send registration code via SMS
		#Add queue
		$dbi->insert(
			{
				token => $token,
			},
			table => 'notify_q',
		);

		$msg = "Сообщение с кодом регистрации отправлено.";

	}else{
		$code = 0;
		$msg = "Ваше устройство уже зарегистрировано или ожидается код регистрации. (CLIENT_ID:&nbsp;$client)";
		
	};
	
	$tpl->param(
		msg => $msg,
		phone => $phone,
		code => $code;
	);

};

sub verify(){
	my $client = $dbi->select(
		table => 'clients',
		columns => ['id,','ip','mac','code'],
		where => {phone => $params->{'phone'}, ip => $remote_ip},
	)->fetch_hash;

	if($client && ($params->{'code'} eq $client->{'code'})){
		my $mac = Net::ARP::arp_lookup($config->{'dev'},$client->{'ip'}) || 'unknown';
		if ($mac ne 'unknown' && $mac ne $client->{'mac'}){
			$dbi->update(
				{mac => $mac},
				table => 'clients',
				where => {id => $client->{'id'}},	
			);
	
			#Create queue for rules
			$dbi->insert(
				{cid => $client->{'id'}},
				table => 'rules_q',
			);

			$msg = "Регистрация прошла успешно. В течение 3 минут будет организован доступ в интернет. Регистрация устройства будет отменена в 00:01 местного времени.";
		
		}else{
			$msg = "Ошибка в определении сетевого адреса устройства. (CLIENT_ID:&nbsp;$client->{'id'})";

		};
	}else{
		$msg = "Код регистрации введен неверно. Повторите ввод."; 
		$tpl->param(phone => $params->{'phone'});
	}

	$tpl->param(msg => $msg);
};
