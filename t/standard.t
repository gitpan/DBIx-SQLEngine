#!/usr/bin/perl

use Test;
use DBIx::SQLEngine;
  # DBIx::SQLEngine->DBILogging(1);

########################################################################

BEGIN { require 't/get_test_dsn.pl' }

BEGIN { plan tests => 40 }

########################################################################

my ($sqldb) = DBIx::SQLEngine->new($dsn, $user, $pass);
my ($type) = ( ref($sqldb) =~ /DBIx::SQLEngine::(.+)/ );

if ( ! $sqldb ) {
warn <<".";
  Skipping: Could not connect to this DBI_DSN to test your local server.

.
  skip(
    "Skipping: Could not connect to this DBI_DSN to test your local server.",
    0,
  );
  exit 0;
}

warn <<".";
  Connected using DBIx::SQLEngine::$1 and DBD::$sqldb->{dbh}->{Driver}->{Name}.

.
ok( $sqldb and $type );

ok( $sqldb->detect_any );

########################################################################

my $table = 'sqle_test';

# FETCH_COLUMN_INFO_1: {
   # my @cols = $sqldb->detect_table( $table, 'quietly' );
   # ok( scalar( @cols ) == 0 );
# }

CREATE_TABLE: {

  $sqldb->do_drop_table( $table ) if $sqldb->detect_table($table, 'quietly');
  $sqldb->do_create_table( $table, [
    { name => 'id', type => 'sequential' },
    { name => 'name', type => 'text', length => 16 },
    { name => 'color', type => 'text', length => 8 },
  ]);
  ok( 1 );

}

FETCH_COLUMN_INFO_2: {

# warn "detect";
  # my @cols = $sqldb->detect_table( $table );
  # warn "cols $#cols";
  # ok( scalar( @cols ) == 3 );
#warn "detect 51";
  my @cols = $sqldb->detect_table( 'area_51_secrets', 'quietly' );
# warn "cols $#cols";
  ok( scalar( @cols ) == 0 );
#warn "done";
}

INSERTS_AND_SELECTS: {

  $sqldb->do_insert( table => $table, sequence => 'id', 
			values => { name=>'Sam', color=>'green' } );
  $sqldb->do_insert( table => $table, sequence => 'id', 
			values => { name=>'Ellen', color=>'orange' } );
  $sqldb->do_insert( table => $table, sequence => 'id', 
			values => { name=>'Sue', color=>'purple' } );
  ok( 1 );
  
  my $rows = $sqldb->fetch_select( table => $table, order => 'id' );
  ok( ref $rows and scalar @$rows == 3 );
  ok( $rows->[0]->{'name'} eq 'Sam' and $rows->[0]->{'color'} eq 'green' );

   # use Data::Dumper;
   # warn Dumper( $rows );

  ok( $rows->[0]->{'id'} );
  ok( $rows->[0]->{'id'} ne $rows->[1]->{'id'} );
  ok( $rows->[1]->{'id'} ne $rows->[2]->{'id'} );
  ok( $rows->[2]->{'id'} );
  
  $sqldb->do_insert( table => $table, sequence => 'id', 
			values => { name=>'Dave', color=>'blue' } );
  
  $sqldb->do_insert( table => $table, sequence => 'id', 
			values => { name=>'Bill', color=>'blue' } );
  ok( 1 );
  
  $rows = $sqldb->fetch_select( table => $table );
  ok( ref $rows and scalar @$rows == 5 );

}

SELECT_CRITERIA_SINGLE: {

  my $rows = $sqldb->fetch_select( table => $table, criteria => {name=>'Dave'});
  ok( ref $rows and scalar @$rows == 1 and $rows->[0]->{'name'} eq 'Dave' );
  
  $rows = $sqldb->fetch_select( table => $table, criteria => "name = 'Dave'" );
  ok( ref $rows and scalar @$rows == 1 and $rows->[0]->{'name'} eq 'Dave' );
  
  $rows = $sqldb->fetch_select( sql => "select * from $table where name = 'Dave'" );
  ok( ref $rows and scalar @$rows == 1 and $rows->[0]->{'name'} eq 'Dave' );
  
  $rows = $sqldb->fetch_select( sql => [ "select * from $table where name = ?", 'Dave' ] );
  ok( ref $rows and scalar @$rows == 1 and $rows->[0]->{'name'} eq 'Dave' );
  
  $rows = $sqldb->fetch_select( sql => "select * from $table", criteria => [ "name = ?", 'Dave' ] );
  ok( ref $rows and scalar @$rows == 1 and $rows->[0]->{'name'} eq 'Dave' );

}

SELECT_CRITERIA_MULTI: {

  my $rows = $sqldb->fetch_select( table => $table, criteria =>{color=>'blue'});
  ok( ref $rows and scalar @$rows == 2 and ( $rows->[0]->{'name'} eq 'Dave' or $rows->[1]->{'name'} eq 'Dave' ) );

  $rows = $sqldb->fetch_select( table => $table, criteria => {color=>'blue', name=>'Dave'});
  ok( ref $rows and scalar @$rows == 1 and $rows->[0]->{'name'} eq 'Dave' );
  
  $rows = $sqldb->fetch_select( sql => "select * from $table where name = 'Dave'", criteria => {color=>'blue'});
  ok( ref $rows and scalar @$rows == 1 and $rows->[0]->{'name'} eq 'Dave' );

  $rows = $sqldb->fetch_select( sql => "select * from $table where color = 'blue'", criteria => {name=>'Dave'});
  ok( ref $rows and scalar @$rows == 1 and $rows->[0]->{'name'} eq 'Dave' );

}

SELECT_CRITERIA_JOIN: {

  if ( $sqldb->dbms_select_table_as_unsupported ) {
    skip("Skipping: This database does not support selects with table aliases.", 0);
    skip("Skipping: This database does not support selects with table aliases.", 0);
    skip("Skipping: This database does not support selects with table aliases.", 0);
  } else {

    my $rows = $sqldb->fetch_select( table => ["$table as a", "$table as b"] );
    ok( ref $rows and scalar @$rows == 25 );
  
    $rows = $sqldb->fetch_select( table => [ "$table as a", "$table as b" ], criteria => { 'a.color'=>'blue'});
    ok( ref $rows and scalar @$rows == 10 );
    
    $rows = $sqldb->fetch_select( table => [ "$table as a", inner_join=>[ 'a.color = b.color' ],  "$table as b" ]);
    ok( ref $rows and scalar @$rows == 7 );
  }

}

SELECT_UNION: {

  my $rows = $sqldb->fetch_select( union => [
    { table => $table, criteria => {color=>'orange'} },
    { table => $table, criteria => {color=>'purple'} },
  ] );

  ok( ref $rows and scalar @$rows == 2 );
  ok( $rows->[0]->{'name'} eq 'Ellen' or $rows->[1]->{'name'} eq 'Ellen' );

}

UPDATE: {

  $sqldb->do_update( table => $table, criteria => { name=>'Dave' }, values => { color=>'yellow' } );
  ok( 1 );
  
  my $rows = $sqldb->fetch_select( table => $table, criteria =>{name=>'Dave'} );
  ok( ref $rows and scalar @$rows == 1 and $rows->[0]->{'color'} eq 'yellow' );

}

USE_OF_LITERAL_EXPRESSIONS: {

  $sqldb->do_update( table => $table, criteria => { name=>\"'Dave'" }, values => { color=>\"'mauve'" } );
  ok( 1 );
  
  my $rows = $sqldb->fetch_select( table=>$table, criteria=>{name=>\"'Dave'"} );
  ok( ref $rows and scalar @$rows == 1 and $rows->[0]->{'color'} eq 'mauve' );

}

DELETE: {

  $sqldb->do_delete( table => $table, criteria => { name=>'Sam' } );
  ok( 1 );
  
  my $rows = $sqldb->fetch_select( table => $table );
  ok( ref $rows and scalar @$rows == 4 );

}

NULL_VALUE_LOGIC: {

  my $rows = $sqldb->fetch_select( table=>$table, criteria=>{ name=>undef() } );
  ok( ref $rows and scalar @$rows == 0 );
  
  $sqldb->do_update( table => $table, criteria => { name=>\"'Dave'" }, values => { name=>undef() } );
  ok( 1 );
  
  if ( $sqldb->dbms_null_becomes_emptystring ) { 
    skip("Skipping: This database does not support storing null values.", 0);
  } else {
    $rows = $sqldb->fetch_select( table=>$table, criteria=>{ name=>undef() } );
    ok( (ref $rows and scalar @$rows == 1 and $rows->[0]->{'color'} eq 'mauve'), 1, "Couldn't select null value rows" );
  }

}

TABLESET: {

  ok( ref( $sqldb->tables ) );

  if ( $sqldb->dbms_detect_tables_unsupported() ) {
    skip("Skipping: This database does not support retrieving table names.", 0);
  } else {
    ok( scalar( $sqldb->tables->table_names ) > 0, 1, "Couldn't detect tables" );
  }
  ok( scalar( $sqldb->tables->table_names ) == scalar ($sqldb->detect_table_names) );

}

DROP_TABLE: {

  $sqldb->do_drop_table( $table );
  ok( 1 );

}

# FETCH_COLUMN_INFO_3: {
  # my @cols = $sqldb->detect_table( $table, 'quietly' );
  # warn "Columns: " . join(', ', map "'$_'", @cols );
  # ok( scalar( @cols ) == 0 );
# }

########################################################################

1;
