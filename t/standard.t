#!/usr/bin/perl

my ($dsn, $user, $pass);
BEGIN { 
  ($dsn, $user, $pass) = ( 
    scalar(@ARGV) ? ( @ARGV ) : 
    $ENV{DBI_DSN} ? ( map $ENV{$_}, qw( DBI_DSN DBI_USER DBI_PASS ) ) :
    ()
  );
  $dsn = '' if ( ! $dsn or $dsn eq '-' );
}

########################################################################

use Test;
BEGIN { plan tests => ( $dsn ? 31 : 1 ) }

use DBIx::SQLEngine;
  # DBIx::SQLEngine->DBILogging(1);

########################################################################

if ( ! $dsn ) {

  warn <<'.';

  Note: By default, DBIx::SQLEngine will only perform a limited series of
  tests; to be fully tested, it must connect to a working DBI database driver.
  Using that connection, this test script will create a table named sqle_test,
  run several queries against it, and then drop it.

  In order to test DBIx::SQLEngine against your local database, set the
  DBI_DSN environment variable to your connection string before running the
  tests, and if needed, also set the DBI_USER and DBI_PASS variables.
    Example:  > setenv DBI_DSN "DBI:mysql:test"; make test

  This script will now query DBI for available drivers and suggested DSNs: 
.

  %common_cases = (
    'AnyData' => 'dbi:AnyData:',
    'SQLite' => 'dbi:SQLite:dbname=test_data/test.sqlite',
    'mysql' => 'dbi:mysql:test',
  );
  @exclude_patterns = (
    'blib$', 	  # for file-based DBDs, don't show the compilation directory
    'SQLEngine$', # nor the source directory...
    't$', 	  # nor the test directory -- this should leave test_data/
  );
  foreach my $driver ( DBI->available_drivers ) {
    eval {
      DBI->install_driver($driver);
      my @data_sources;
      eval {
	@data_sources = DBI->data_sources($driver);
      };
      push @data_sources, split(' ', $common_cases{$driver} || '');
      if (@data_sources) {
	foreach my $source ( @data_sources ) {
	  next if grep { $source =~ /\b$_\b/ } @exclude_patterns;
	  push @suggestions, ($source =~ /:/ ? $source : "dbi:$driver:$source");
	} 
      } else { 
	push @suggestions, "dbi:$driver";
      }
    };
  } 

  if ( scalar @suggestions ) {
    %suggestions = map { $_ => 1 } grep { ! /dbi:ExampleP/ } @suggestions;
    @suggestions = sort { lc($a) cmp lc($b) } keys %suggestions;
    warn join '', map "    $_\n", @suggestions;
  } else {
    warn "    (No suggestions found.)\n";
  }

  skip(
    "Skipping: specify DBI_DSN in environment to test your local server.\n",
    0,
  );
  exit 0;

}

########################################################################

warn <<".";

  The remaining tests will use the DBI DSN specified in your environment: 
    $dsn

  In a few seconds, this script will connect to this data source, create
  a table named sqle_test, run several queries against that table, and 
  then drop it. 
  
.

sleep(1);

my ($sqldb) = DBIx::SQLEngine->new($dsn, $user, $pass);
my ($type) = ( ref($sqldb) =~ /DBIx::SQLEngine::(.+)/ );

if ( ! $sqldb ) {
warn <<".";
  Skipping: Could not connect to this DBI_DSN to test your local server.

.
  skip(
    "Skipping: Could not connect to this DBI_DSN to test your local server.\n",
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
  
  $sqldb->do_insert( table => $table, sequence => 'id', 
			values => { name=>'Dave', color=>'blue' } );
  
  $sqldb->do_insert( table => $table, sequence => 'id', 
			values => { name=>'Bill', color=>'blue' } );
  ok( 1 );
  
  $rows = $sqldb->fetch_select( table => $table );
  ok( ref $rows and scalar @$rows == 5 );

}

SELECT_CRITERIA: {

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


  $rows = $sqldb->fetch_select( table => $table, criteria => {color=>'blue'});
  ok( ref $rows and scalar @$rows == 2 and ( $rows->[0]->{'name'} eq 'Dave' or $rows->[1]->{'name'} eq 'Dave' ) );

  $rows = $sqldb->fetch_select( table => $table, criteria => {color=>'blue', name=>'Dave'});
  ok( ref $rows and scalar @$rows == 1 and $rows->[0]->{'name'} eq 'Dave' );
  
  $rows = $sqldb->fetch_select( sql => "select * from $table where name = 'Dave'", criteria => {color=>'blue'});
  ok( ref $rows and scalar @$rows == 1 and $rows->[0]->{'name'} eq 'Dave' );

  $rows = $sqldb->fetch_select( sql => "select * from $table where color = 'blue'", criteria => {name=>'Dave'});
  ok( ref $rows and scalar @$rows == 1 and $rows->[0]->{'name'} eq 'Dave' );

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
  
  $rows = $sqldb->fetch_select( table=>$table, criteria=>{ name=>undef() } );
  ok( (ref $rows and scalar @$rows == 1 and $rows->[0]->{'color'} eq 'mauve'), 1, "Couldn't select null value rows" );

}


TABLESET: {

  ok( ref( $sqldb->tables ) );
  ok( scalar( $sqldb->tables->table_names ) > 1 );
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
