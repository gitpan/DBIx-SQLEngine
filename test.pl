#!/usr/bin/perl

use Test;
BEGIN { plan tests => 23 }

########################################################################

BEGIN { 
  warn "Testing compilation...\n";
}

use DBIx::SQLEngine;
BEGIN { ok( 1 ) }

BEGIN { 
  
  eval "use DBIx::SQLEngine 0.001;";
  ok( ! $@ );
  
  eval "use DBIx::SQLEngine 2.0;";
  ok( $@ );

}

########################################################################

warn "A working DBI connection is required for the remaining tests.\n";
warn "Please enter or accept the following parameters (or pre-set in your ENV):\n";

sub get_line {
  print "  $_[0] (or accept default '$_[1]'): ";
  my $input = <STDIN>;
  chomp $input;
  ( length $input ) ? $input : $_[1]
}

my $dsn = get_line( 'DBI_DSN' => $ENV{DBI_DSN} || 'dbi:AnyData:' );
my $user = get_line( 'DBI_USER' => $ENV{DBI_USER} || '' );
my $pass = get_line( 'DBI_PASS' => $ENV{DBI_PASS} || '' );

my $ds;
ok( $ds = DBIx::SQLEngine->new( $dsn, $user, $pass ) );
ok( ref($ds) =~ /DBIx::SQLEngine::/ );
ok( $ds->detect_any );

# $ds->DBILogging(1);

########################################################################

$ds->do_drop_table('test1') if $ds->detect_table('test1');
$ds->do_create_table( 'test1', [
  { name => 'id', type => 'sequential' },
  { name => 'name', type => 'text', length => 16 },
  { name => 'color', type => 'text', length => 8 },
]);
ok( 1 );

###

my @cols = $ds->detect_table( 'test1' );
ok( scalar( @cols ) == 3 );
@cols = $ds->detect_table( 'table42' );
ok( scalar( @cols ) == 0 );

###

$ds->do_insert( table => 'test1', values => { name=>'Sam', color=>'green' }, sequence => 'id' );
ok( 1 );

my $rows = $ds->fetch_select( table => 'test1' );
ok( ref $rows and scalar @$rows == 1 );
ok( $rows->[0]->{'name'} eq 'Sam' and $rows->[0]->{'color'} eq 'green' );

$ds->do_insert( table => 'test1', values => { name=>'Dave', color=>'blue' }, sequence => 'id' );
ok( 1 );

my $rows = $ds->fetch_select( table => 'test1' );
ok( ref $rows and scalar @$rows == 2 );

###

my $rows = $ds->fetch_select( table => 'test1', criteria => { name=>'Dave' } );
ok( ref $rows and scalar @$rows == 1 and $rows->[0]->{'name'} eq 'Dave' );

my $rows = $ds->fetch_select( table => 'test1', criteria => "name = 'Dave'" );
ok( ref $rows and scalar @$rows == 1 and $rows->[0]->{'name'} eq 'Dave' );

my $rows = $ds->fetch_select( sql => "select * from test1 where name = 'Dave'" );
ok( ref $rows and scalar @$rows == 1 and $rows->[0]->{'name'} eq 'Dave' );

my $rows = $ds->fetch_select( sql => [ 'select * from test1 where name = ?', 'Dave' ] );
ok( ref $rows and scalar @$rows == 1 and $rows->[0]->{'name'} eq 'Dave' );

###

$ds->do_update( table => 'test1', criteria => { name=>'Dave' }, values => { color=>'yellow' } );
ok( 1 );

my $rows = $ds->fetch_select( table => 'test1', criteria => { name=>'Dave' } );
ok( ref $rows and scalar @$rows == 1 and $rows->[0]->{'color'} eq 'yellow' );

###

$ds->do_delete( table => 'test1', criteria => { name=>'Sam' } );
ok( 1 );

my $rows = $ds->fetch_select( table => 'test1' );
ok( ref $rows and scalar @$rows == 1 );

###

$ds->do_sql("drop table test1");
ok( 1 );

########################################################################

1;
