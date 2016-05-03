#!/usr/bin/perl -w
#Clear and archiving database

use strict;
use DBIx::Custom;
use YAML::XS 'LoadFile';
use FindBin qw($Bin);

my $config = LoadFile($Bin.'/../config.yaml');

my $dbi = DBIx::Custom->connect(
   dsn => "dbi:mysql:database=$config->{database}",
   user => $config->{user},
   password => $config->{pass},
   option => {mysql_enable_utf8 => 1}
);

my $hosts = $dbi->select(
	table => 'clients',
	column => ['cdate','phone','ip','mac'],
	where => 'mac is not null',
)->fetch_hash_all;

foreach my $host(@{$hosts}){
	$dbi->insert(
		{
			cdate => $host->{cdate}, 
			phone => $host->{phone},
			ip => $host->{ip},
			mac => $host->{mac},
		},
		table => 'hosts',
	);
};

$dbi->delete_all(
	table => 'clients',
);

$dbi->delete_all(
	table => 'notify_q',
);

$dbi->delete_all(
	table => 'rules_q',
);

1; 
