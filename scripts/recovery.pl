#!/usr/bin/perl -w
#Recovery rules of firewall and ARP (after shutdown or system failure) 

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

my $tks = $dbi->select(
	table => 'clients',
	column => ['token'],
	where => 'mac not like "0"',
)->fetch_hash_all;

$dbi->insert(
	$tks,
	table => 'rules_q',
);

1;
