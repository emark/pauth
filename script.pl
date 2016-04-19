#!usr/bin/perl -w

use strict;
use CGI;
use DBIx::Custom;

my $q = CGI->new();

print $q->header(-charset => 'utf-8');

sub code(){
	print '<form action="" method="post">';
	print '<input type=text size=6><br/>';
	print '<input type=submit value="Далее">';
	print '</form>';

};

1;
