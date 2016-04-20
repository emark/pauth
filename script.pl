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

my $tpl = HTML::Template->new(arrayref => 'tpl/index.tpl');

if($params->{phone} && $params->{code}){
	&verify;
}elsif($params->{phone}){
	&register;
}else{
	&index;
};

print "Content-Type: text/html\n\n", $tpl->output;

sub index(){
	$tpl->filename('tpl/index2.tpl');
};

sub register(){
	my $code = 0;
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

    print $q->p("Phone: +7$params->{phone}");
    print $q->p("Insert code in field below: <b>$code</b>");
    print '<form action="" method="post">';
	print "<input type=hidden name=\"phone\" value=\"$params->{phone}\">";
    print '<input type=text size=6 name="code"><br/>';
    print '<input type=submit value="Далее">';
    print '</form>';

};

sub verify(){
	my $verify = $dbi->select(
		table => 'clients',
		columns => ['id,','code','ip'],
		where => {phone => $params->{phone}},
	)->fetch_hash;

	if($verify->{code} eq $params->{code}){
		my $mac = Net::ARP::arp_lookup($config->{dev},$verify->{ip});
		if ($mac ne 'unknown'){
			$dbi->update(
				{mac => $mac},
				table => 'clients',
				where => {id => $verify->{id}},	
			);
			print $q->h1("That's ok! MAC: $mac");
		
		}else{
			print 'Error define mac-address';

		};
	}else{
		print $q->p("Wrong code $verify->{code}/$params->{code}, please register.");
	}

};
