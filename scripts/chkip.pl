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
use Term::ANSIColor;
use Term::ANSIColor 4.00 qw(coloralias);

use Data::Dumper;

my $config = LoadFile($Bin.'/../config.yaml');

my $dbh = DBIx::Custom->connect(
   dsn => "dbi:mysql:database=$config->{database}",
   user => $config->{user},
   password => $config->{pass},
   option => {mysql_enable_utf8 => 1}
);

&check_ip;

sub check_ip(){
	my $routers = $dbh->select(
		table => 'routers',
		column => ['id','ip','status'],
	)->fetch_hash_all;
	
	my @hu_status = ('offline','online');
	my @stats = (0,0); #Statistic data (All/Online)
	coloralias('online','green');
	coloralias('offline','red');

	print "Starting to ping hosts...\n";
	my $p = Net::Ping->new("icmp");

	foreach my $router (@{$routers}){
		$stats[0] = $stats[0]+1;

		my $checking_status = $router->{'status'}; #Status for checking with current status
		$router->{'status'} = $p->ping($router->{'ip'},2) ? 1 : 0;
		
		$stats[1] = $stats[1]+$router->{'status'};	
		print "$stats[0].\t$router->{'ip'}\tStatus:\t";
		print colored("$hu_status[$router->{'status'}]",$hu_status[$router->{'status'}]),"\n";

		if($router->{'status'} != $checking_status || $router->{'status'} == 1){
			$dbh->update(
				$router,
				mtime => 'updated',
				table => 'routers',
				where => {id => $router->{'id'}},
			);
		};
	};
	$p->close();
	print "\nOnline: $stats[1]/$stats[0]\n";
};

1;
