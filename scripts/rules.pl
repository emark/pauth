#!/usr/bin/perl -w
#Managing rules of firewall and ARP

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

my @rcpt = $dbi->select(
	table => 'rules_q',
	column => ['cid'],
	where => 'result is null',
)->flat;

my $rules_for = $dbi->select(
	table => 'clients',
	column => ['id','ip','mac'],
	where => {id => \@rcpt},
)->fetch_hash_all;

foreach my $client (@{$rules_for}){
	my @args = ();
	my $result = 0;

	@args = ("$config->{arp} -i $config->{dev} -s $client->{ip} $client->{mac}");
	system(@args) == 0 || die "system @args filed: $?\n";
	$result = 1;

	@args = ("$config->{iptables} it nat -I PREROUTING -s $client->{ip} -j ACCEPT");
	system(@args) == 0 || die "system @args field: $?\n";
	$result = $result+2;

	@args = ("$config->{iptables} -I FORWARD 1 -s $client->{ip} -j ACCEPT");
	system(@args) == 0 || die "system @args field: $?\n";
	$result = $result+4;

	$dbi->update(
		{result => $result},
		table => 'rules_q',
		where => {cid => $client->{id}},
	);
};

1;

