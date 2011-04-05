#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Bootylite' );
}

diag( "Testing Bootylite $Bootylite::VERSION, Perl $], $^X" );
