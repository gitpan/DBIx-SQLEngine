#!/usr/bin/perl

use Test;
BEGIN { plan tests => 21 }

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

$sqldb->fetch_select( table => [ 'foo' ] );
ok( $sqldb->last_query, 'select * from foo' );

$sqldb->fetch_select( table => [ 'foo', 'bar' ] );
ok( $sqldb->last_query, 'select * from foo, bar' );

$sqldb->fetch_select( table => [ 'foo', 'bar' ], criteria => { bar => 'Baz' } );
ok( $sqldb->last_query, 'select * from foo, bar where bar = ?/Baz' );

$sqldb->fetch_select( table => [ 'foo', 'bar', 'baz' ] );
ok( $sqldb->last_query, 'select * from foo, bar, baz' );

$sqldb->fetch_select( table => [ [ 'foo', 'bar' ], [ 'baz', 'blee' ] ] );
ok( $sqldb->last_query, 'select * from ( foo, bar ), ( baz, blee )' );

$sqldb->fetch_select( table => [ 'foo', inner_join=>['foo = bar'], 'bar' ] );
ok( $sqldb->last_query, 'select * from foo inner join bar on foo = bar' );

$sqldb->fetch_select( table => [ 'foo', inner_join=>{'foo'=>\'bar'}, 'bar' ] );
ok( $sqldb->last_query, 'select * from foo inner join bar on foo = bar' );

$sqldb->fetch_select( table => [ 'foo',left_outer_join=>{'foo'=>\'bar'},'bar']);
ok( $sqldb->last_query, 'select * from foo left outer join bar on foo = bar' );

########################################################################

$sqldb->fetch_select( union => [
  [ table => 'foo', criteria => { bar=>'Baz' } ],
  [ table => 'bar', criteria => { buz=>'Blee' } ],
] );
ok( $sqldb->last_query, 'select * from foo where bar = ? union select * from bar where buz = ?/Baz/Blee');

$sqldb->fetch_select( union => [
  { table => 'foo', criteria => { bar=>'Baz' } },
  { table => 'bar', criteria => { buz=>'Blee' } },
] );
ok( $sqldb->last_query, 'select * from foo where bar = ? union select * from bar where buz = ?/Baz/Blee');

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
