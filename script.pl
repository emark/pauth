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

my $remote_ip = $ENV{REMOTE_ADDR}; #Client remote address

my $msg = '';
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

};#else{
#	&index;

#};

my $tpl = HTML::Template->new(filename => 'tpl/'.$template.'.tpl');

my $func = $route{$template};
&$func();

print "Content-Type: text/html\n\n", $tpl->output;

sub phone_check(){
	my $phone = $params->{phone};
	return 1 if($phone=~m/^\d{10}$/); #Check for 10 digits in phone nu,ber

};

sub index(){
	$msg = 'Введите номер телефона для отправки SMS сообщения о регистрации доступа в интернет.';
	
	if($params->{phone}){
		$msg = 'Ошибка. Укажите номер мобильного телефона. Не более 10 цифр.';

	};
	$tpl->param(msg => $msg);

};

sub register(){
	my $code = 0; # Generate sms code
	while ($code < 100000){
		$code = int(rand(999999));
	};	
	my $phone = $params->{phone};
	my $client = $dbi->select(
		table => 'clients',
		column => ['id'],
		where => {phone => $phone, ip => $remote_ip},
	)->value;

	if(!$client){ #Create new registration
		$dbi->insert(
			{
				phone => $phone,
				ip => $remote_ip,
				code => $code,
			},
			ctime => 'cdate',
			table => 'clients',
		);
		#Send registration code via SMS

		$msg = "Сообщение с кодом регистрации отправлено на номер +7$phone";

	}else{
		$msg = 'Ваше устройство уже зарегистрировано или ожидается код подтверждения.';
		$phone = '';
	};
	
	$tpl->param(
		msg => $msg,
		code => $code,
		phone => $phone,
	);

};

sub verify(){
	my $verify = $dbi->select(
		table => 'clients',
		columns => ['id,','code','ip','mac'],
		where => {phone => $params->{phone}},
	)->fetch_hash;

	if(($verify->{code} eq $params->{code})){
		my $mac = Net::ARP::arp_lookup($config->{dev},$verify->{ip});
		if ($mac ne 'unknown' && $mac ne $verify->{mac}){
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
