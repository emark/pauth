#!/usr/bin/perl

#Web-authorisation script
#Source https://github.com/emark/pauth
#Author E-marketing LLC, http://www.emrk.ru, mailbox@emrk.ru

use strict;
use warnings;
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

my $lang = $ENV{REQUEST_URI} || '/internet/ru/'; #Set translate localisation
$lang =~s/\/internet(\/\w+\/)/$1/;
$lang = '/ru/' if !-e "tmpl/$lang/locale.txt";

my $file_locale = "tmpl/$lang/locale.txt";
my @locale = '';
open (LOCALE, "<", $file_locale) || die "Can't open locale translation: $file_locale. Error: $!";
@locale = <LOCALE>;
close LOCALE;

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

#Clear template if service not running
$template = $config->{'service'} ? $template : 'index';

my $tmpl = HTML::Template->new(filename => 'tmpl'.$lang.$template.'.tmpl');

my $func = $route{$template};
&$func();

print "Content-Type: text/html\n\n", $tmpl->output;


sub phone_check(){
	$params->{phone}=~s/\-//g;
	my $phone = $params->{'phone'};
	return 1 if($phone=~m/^\d{10}$/); #Check for 10 digits in phone number

};

sub index(){
	$msg = $config->{'service'} ? $locale[0] : $locale[1]; #'Введите номер телефона для получения смс'|'Извините, сервис временно недоступен.'
	
	if($params->{'phone'}){
		$msg = $locale[2]; #'Ошибка. Укажите номер мобильного телефона.'

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
		
		#Check client registration in archive database
		my $mac = Net::ARP::arp_lookup($config->{'dev'},$client_ip) || 'unknown';

		my $host = $dbi->select(
			table => 'hosts',
			columns => 'true',
			where => {phone => $phone, mac => $mac}

		)->value;

		if($host){
			$msg = $locale[3]; #'Повторная регистрация. Нажмите кнопку "Далее"'
			$tmpl->param(code => $code);

		}else{
			#Send registration code via SMS
			#Add queue
			$dbi->insert(
				{
					token => $token,
				},
				table => 'notify_q',
			);

			$msg = $locale[4]; #'Сообщение с кодом регистрации отправлено. Срок действия кода 300 секунд.'
			$tmpl->param(code => $code) if !$config->{'sms_service'}; #Disconnect sms_gate & show code

		};

	}else{
		$code = 0;
		$msg = $locale[5]."(CLIENT_ID:&nbsp;$client)"; #'Ваше устройство уже зарегистрировано или ожидается код регистрации.'
		
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

				$msg = $locale[6]; #'Регистрация прошла успешно. Отмена регистрации в 00:01 местного времени.'
				$tmpl->param(token => $client->{'token'});

			}else{
				$msg = $locale[7]; #'Устройство зарегистрировано. Для доступа в интернет нажмите "Подключить".'
				$tmpl->param(token => $client->{'token'});

			};
		
		}else{
			$msg = $locale[8]."(CLIENT_ID:&nbsp;$client->{'id'})"; #'Ошибка в определении сетевого адреса устройства.'

		};
	}else{
		$msg = $locale[9]; #'Код регистрации введен неверно. Повторите ввод.' 
		$tmpl->param(phone => $params->{'phone'});
	}

	$tmpl->param(msg => $msg);
};

#Checking allow connection
sub connect(){
	my $token = $params->{'token'};
	my $url = "?token=$token";
	my $refresh = 7;
	$msg = $locale[10]; #'Настройка интернет-соединения ... '
	
	my $rules = $dbi->select(
		table => 'rules_q',
		columns => 'result',
		where => {token => $token},
	)->fetch_hash;

	if (defined $rules->{'result'}){
		if ($rules->{'result'} == 0){
			$msg = $msg.$locale[11]; #'ожидайте'

		}elsif ($rules->{'result'} == 7){
			$url = $config->{'target_url'};
			$msg = $msg.$locale[12]; #'успешно'
			$refresh = 0;

		}else{
			$url = '/';
			$refresh = '';
			$msg = $locale[13]; #'Ошибка создания правил доступа устройства. Обратитесь к системному администратору.';

		};

	}else{
		$url = '/';
		$msg = $locale[14]; #'Ошибка определения ключа настроек подключения. Пройдите регистрацию повторно.';
		$refresh = 3;

	};

	$tmpl->param(
		msg => $msg,
		url => $url,
		refresh => $refresh,
	);
};
