#!/usr/bin/perl

use Test;
BEGIN { plan tests => 7 }

########################################################################

use DBIx::SQLEngine;
BEGIN { ok( 1 ) }

my $sqldb = DBIx::SQLEngine->new( 'dbi:ExampleP:',  );
ok( 2 );

ok( ref($sqldb) =~ /DBIx::SQLEngine::(.+)/ );
warn "  (Testing DBIx::SQLEngine::$1)\n";

# $sqldb->DBILogging(1); 

########################################################################

my @cols = $sqldb->detect_table( 't' );
ok( scalar( @cols ), 14 );
@cols = $sqldb->detect_table( 'area_51_secrets', 'quietly' );
ok( scalar( @cols ), 0 );

###

my $rows = $sqldb->fetch_select( table => 't' );
ok( ref $rows and scalar @$rows > 1 );
ok( grep { $_->{name} =~ /examplep/ } @$rows );

########################################################################

1;