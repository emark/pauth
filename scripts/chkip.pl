#!/usr/bin/env perl
#Check IP - script for checking ip host
#
use strict;
use warnings;
use utf8;

use Net::Ping;
use DBIx::Custom;
use FindBin qw($Bin);
use YAML::XS 'LoadFile';

use Data::Dumper;

my $config = LoadFile($Bin.'/../config.yaml');

my $dbh = DBIx::Custom->connect(
   dsn => "dbi:mysql:database=$config->{database}",
   user => $config->{user},
   password => $config->{pass},
   option => {mysql_enable_utf8 => 1}
);

my $p = Net::Ping->new();

&check_ip;

sub check_ip(){
	my $routers = $dbh->select(
		table => 'routers',
		column => ['id','ip'],
	)->fetch_hash_all;
	
	my @hu_status = ('offline','online');

	print "Starting to ping hosts...\n";

	foreach my $router (@{$routers}){
		$router->{'status'} = $p->ping($router->{'ip'}) ? 1 : 0;
		$p->close();
		print "Host:\t$router->{'ip'}\tStatus:\t$hu_status[$router->{'status'}]\n";

		$dbh->update(
			$router,
			mtime => 'updated',
			table => 'routers',
			where => {id => $router->{'id'}},
		);

	};
};

1;
