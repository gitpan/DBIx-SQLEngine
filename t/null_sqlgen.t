#!/usr/bin/perl

use Test;
BEGIN { plan tests => 11 }

use DBIx::SQLEngine;
  # DBIx::SQLEngine->DBILogging(1);
ok( 1 );

########################################################################

my $sqldb = DBIx::SQLEngine->new( 'dbi:NullP:' );
ok( $sqldb and ref($sqldb) =~ m/^DBIx::SQLEngine/ );

########################################################################

$sqldb->fetch_select( table => 'foo' );
ok( $sqldb->last_query, 'select * from foo' );

$sqldb->fetch_select( table => 'foo', criteria => { bar => 'Baz' } );
ok( $sqldb->last_query, 'select * from foo where bar = ?/Baz' );

$sqldb->fetch_select( table => 'foo', criteria => { bar=>'Baz', buz=>'Blee' } );
ok( $sqldb->last_query, 'select * from foo where ( bar = ? and buz = ? )/Baz/Blee');

########################################################################

$sqldb->do_insert( table => 'foo', values => { bar => 'Baz' } );
ok( $sqldb->last_query, 'insert into foo (bar) values (?)/Baz' );

$sqldb->do_insert( table => 'foo', columns => [ 'bar' ], values => [ 'Baz' ] );
ok( $sqldb->last_query, 'insert into foo (bar) values (?)/Baz' );

########################################################################

$sqldb->do_update( table => 'foo', values => { bar => 'Baz' } );
ok( $sqldb->last_query, 'update foo set bar = ?/Baz' );

$sqldb->do_update( table => 'foo', values => { bar => 'Baz' }, criteria => { buz=>'Blee' } );
ok( $sqldb->last_query, 'update foo set bar = ? where buz = ?/Baz/Blee' );

########################################################################

$sqldb->do_delete( table => 'foo' );
ok( $sqldb->last_query, 'delete from foo' );

$sqldb->do_delete( table => 'foo', criteria => { bar => 'Baz' } );
ok( $sqldb->last_query, 'delete from foo where bar = ?/Baz' );

########################################################################

1;
