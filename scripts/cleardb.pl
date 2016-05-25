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

my $task = $ARGV[0] || '';
my $past_date = &sql_date_format;

#Clear database from empty mac address
$dbi->delete(
	table => 'clients',
	where => "cdate<\"$past_date\" and mac=0",
);

&archiving if($task eq 'archiving');

sub archiving(){
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

};

sub sql_date_format(){
	my $t1 = time;
	my $t2 = $t1-180;
	my @lt = localtime($t2);

	#Formatting date-time for sql query
	$lt[5] = $lt[5]+1900;

	$lt[4] = $lt[4]+1;
	$lt[4] = "0".$lt[4] if ($lt[4] < 10);

	$lt[3] = "0".$lt[3] if ($lt[3] < 10);

	$lt[2] = "0".$lt[2] if ($lt[2] < 10);
	$lt[1] = "0".$lt[1] if ($lt[1] < 10);
	$lt[0] = "0".$lt[0] if ($lt[0] < 10);

	$lt[6] = "$lt[5]-$lt[4]-$lt[3] $lt[2]:$lt[1]:$lt[0]";

	return $lt[6];

};

1; 
