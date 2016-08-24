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

my $client_ip = $ENV{REMOTE_ADDR}; #Client remote address

my $msg = ''; #Help message for templates
my $template = 'index'; #Default template name
my %route = (
			'index' => \&index,
			'register' => \&register,
			'verify' => \&verify,
			'connect' => \&connect,
			);

if($params->{'phone'} && $params->{'code'}){
	$template = 'verify';

}elsif($params->{'phone'}){
	$template = 'register' if &phone_check();

}elsif($params->{'token'}){
	$template = 'connect';
};

my $tmpl = HTML::Template->new(filename => 'tmpl/'.$template.'.tmpl');

my $func = $route{$template};
&$func();

print "Content-Type: text/html\n\n", $tmpl->output;


sub phone_check(){
	my $phone = $params->{'phone'};
	return 1 if($phone=~m/^\d{10}$/); #Check for 10 digits in phone number

};

sub index(){
	$msg = $config->{'service'} ? 'Введите номер телефона для получения смс&ndash;сообщения с кодом регистрации устройства.' : 'Извините, сервис временно недоступен. Выполняется обновление программного обеспечения.';
	
	if($params->{'phone'}){
		$msg = 'Ошибка. Укажите номер мобильного телефона. Не более 10 цифр.';

	};
	$tmpl->param(
		msg => $msg,
		phone => $params->{'phone'},
		service => $config->{'service'},
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
			{phone => $phone, ip => $client_ip},
		],
	)->value;

	if(!$client){ #Create new registration
		$dbi->insert(
			{
				phone => $phone,
				ip => $client_ip,
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

		$msg = "Сообщение с кодом регистрации отправлено. Срок действия кода 300 секунд.";
		$tmpl->param(code => $code) if !$config->{'sms_service'}; #Disconnect sms_gate & show code

	}else{
		$code = 0;
		$msg = "Ваше устройство уже зарегистрировано или ожидается код регистрации. (CLIENT_ID:&nbsp;$client)";
		
	};
	
	$tmpl->param(
		msg => $msg,
		phone => $phone,
	);

};

sub verify(){
	my $client = $dbi->select(
		table => 'clients',
		columns => ['id,','ip','mac','token'],
		where => {
			phone => $params->{'phone'}, 
			ip => $client_ip,
			code => $params->{'code'},
			},
	)->fetch_hash;

	if($client){
		my $mac = Net::ARP::arp_lookup($config->{'dev'},$client->{'ip'}) || 'unknown';
		if ($mac ne 'unknown'){
			if ($mac ne $client->{'mac'}){
				$dbi->update(
					{mac => $mac},
					table => 'clients',
					where => {id => $client->{'id'}},	
				);
	
				#Create queue for rules
				$dbi->insert(
					{token => $client->{'token'}},
					table => 'rules_q',
				);

				$msg = "Регистрация прошла успешно. Отмена регистрации в 00:01 местного времени. Для доступа в интернет нажмите \"Подключить\".";
				$tmpl->param(token => $client->{'token'});

			}else{
				$msg = "Устройство зарегистрировано. Для доступа в интернет нажмите \"Подключить\".";
				$tmpl->param(token => $client->{'token'});

			};
		
		}else{
			$msg = "Ошибка в определении сетевого адреса устройства. (CLIENT_ID:&nbsp;$client->{'id'})";

		};
	}else{
		$msg = "Код регистрации введен неверно. Повторите ввод."; 
		$tmpl->param(phone => $params->{'phone'});
	}

	$tmpl->param(msg => $msg);
};

#Checking allow connection
sub connect(){
	my $token = $params->{'token'};
	my $url = "?token=$token";
	my $refresh = 7;
	$msg = "Настройка интернет-соединения ... ";
	
	my $rules = $dbi->select(
		table => 'rules_q',
		columns => 'result',
		where => {token => $token},
	)->fetch_hash;

	if (defined $rules->{'result'}){
		if ($rules->{'result'} == 0){
			$msg = $msg."ожидайте";

		}elsif ($rules->{'result'} == 7){
			$url = $config->{'target_url'};
			$msg = $msg."успешно";
			$refresh = 0;

		}else{
			$url = '/';
			$refresh = '';
			$msg = 'Ошибка создания правил доступа устройства. Обратитесь к системному администратору.';

		};

	}else{
		$url = '/';
		$msg = 'Ошибка определения ключа настроек подключения. Пройдите регистрацию повторно.';
		$refresh = 3;

	};

	$tmpl->param(
		msg => $msg,
		url => $url,
		refresh => $refresh,
	);
};
