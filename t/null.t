#!/usr/bin/perl

use Test;
BEGIN { plan tests => 20 }

use DBIx::SQLEngine;
  # DBIx::SQLEngine->DBILogging(1);
ok( 1 );

########################################################################

my $sqldb = DBIx::SQLEngine->new( 'dbi:NullP:' );
ok( $sqldb and ref($sqldb) =~ m/^DBIx::SQLEngine/ );

########################################################################

$sqldb->fetch_select( table => 'foo' );
ok( $sqldb->{_last_sth_statement}, 'select * from foo' );

$sqldb->do_insert( table => 'foo', values => { bar => 'Baz' } );
ok( $sqldb->{_last_sth_statement}, 'insert into foo (bar) values (?)' );
ok( $sqldb->{_last_sth_params}[0], 'Baz' );

$sqldb->do_update( table => 'foo', values => { bar => 'Baz' } );
ok( $sqldb->{_last_sth_statement}, 'update foo set bar = ?' );
ok( $sqldb->{_last_sth_params}[0], 'Baz' );

$sqldb->do_delete( table => 'foo' );
ok( $sqldb->{_last_sth_statement}, 'delete from foo' );

########################################################################

$sqldb->define_named_query( 'select_foo', 'select * from foo' );
$sqldb->fetch_select( named_query => 'select_foo' );
ok( $sqldb->{_last_sth_statement}, 'select * from foo' );

$sqldb->define_named_query( 'insert_foo', [ 'insert into foo (bar) values (?)', \$1 ] );
$sqldb->do_insert( named_query => [ 'insert_foo', 'Baz' ] );
ok( $sqldb->{_last_sth_statement}, 'insert into foo (bar) values (?)' );
ok( $sqldb->{_last_sth_params}[0], 'Baz' );

$sqldb->define_named_query( 'update_foo', { action => 'update', table => 'foo', values => { bar => \$1 } } );
$sqldb->do_update( named_query => [ 'update_foo', 'Baz' ] );
ok( $sqldb->{_last_sth_statement}, 'update foo set bar = ?' );
ok( $sqldb->{_last_sth_params}[0], 'Baz' );

$sqldb->define_named_query( 'delete_foo', sub { 'delete from foo' } );
$sqldb->do_delete( named_query => 'delete_foo' );
ok( $sqldb->{_last_sth_statement}, 'delete from foo' );

########################################################################

my $queries = <<'/';
select_bar: select * from bar
insert_bar: [ 'insert into bar (foo) values (?)', \$1 ]
update_bar: { action => 'update', table => 'bar', values => { foo => \$1 } }
delete_bar: "delete " . "from" . " bar"
/

my %queries = map { split /\:\s*/, $_, 2 } split "\n", $queries;
$sqldb->define_named_queries_from_text( %queries );

$sqldb->fetch_select( named_query => 'select_bar' );
ok( $sqldb->{_last_sth_statement}, 'select * from bar' );

$sqldb->do_insert( named_query => [ 'insert_bar', 'Baz' ] );
ok( $sqldb->{_last_sth_statement}, 'insert into bar (foo) values (?)' );
ok( $sqldb->{_last_sth_params}[0], 'Baz' );

$sqldb->do_update( named_query => [ 'update_bar', 'Baz' ] );
ok( $sqldb->{_last_sth_statement}, 'update bar set foo = ?' );
ok( $sqldb->{_last_sth_params}[0], 'Baz' );

$sqldb->do_delete( named_query => 'delete_bar' );
ok( $sqldb->{_last_sth_statement}, 'delete from bar' );

########################################################################

1;
