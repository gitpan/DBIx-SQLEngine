#!/usr/bin/perl

use Test;
BEGIN { plan tests => 7 }

use DBIx::SQLEngine;
ok( 1 );

my $sqldb = DBIx::SQLEngine->new( 'dbi:ExampleP:',  );
ok( $sqldb );

ok( ref($sqldb) =~ m/^DBIx::SQLEngine/ );

# $sqldb->DBILogging(1);

my @cols = $sqldb->detect_table( 'SQLEngine' );
ok( scalar( @cols ), 14 );
@cols = $sqldb->detect_table( 'area_51_secrets', 'quietly' );
ok( scalar( @cols ), 0 );

my $rows = $sqldb->fetch_select( table => '.' );
ok( ref $rows and scalar @$rows > 1 );
ok( grep { $_->{name} =~ /SQLEngine/ } @$rows );
