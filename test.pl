#!/usr/bin/perl

my ($dsn, $user, $pass);
BEGIN { 
  ($dsn, $user, $pass) = ( 
    scalar(@ARGV) ? ( @ARGV ) : 
    $ENV{DBI_DSN} ? ( map $ENV{$_}, qw( DBI_DSN DBI_USER DBI_PASS ) ) :
    ()
  );
  $dsn = '' if ( $dsn eq '-' );
}

use Test;
BEGIN { plan tests => ( $dsn ? 39 : 10 ) }

########################################################################

use DBIx::SQLEngine;
BEGIN { ok( 1 ) }

BEGIN { 
  
  eval "use DBIx::SQLEngine 0.001;";
  ok( ! $@ );
  
  eval "use DBIx::SQLEngine 2.0;";
  ok( $@ );

}

########################################################################

EXAMPLEP: {

  my $sqldb = DBIx::SQLEngine->new( 'dbi:ExampleP:',  );
  ok( 2 );
  
  ok( ref($sqldb) eq 'DBIx::SQLEngine' );
  
  # $sqldb->DBILogging(1); 
  
  my @cols = $sqldb->detect_table( 'SQLEngine' );
  ok( scalar( @cols ), 14 );
  @cols = $sqldb->detect_table( 'area_51_secrets', 'quietly' );
  ok( scalar( @cols ), 0 );
  
  my $rows = $sqldb->fetch_select( table => '.' );
  ok( ref $rows and scalar @$rows > 1 );
  ok( grep { $_->{name} =~ /SQLEngine/ } @$rows );

}

########################################################################

if ( ! $dsn ) {
  skip(
    "Skipping: specify DBI_DSN in environment to test your local server.\n",
    0,
  );

  print <<'.';
  Note: By default, DBIx::SQLEngine will only perform a limited series of
  tests; to be fully tested, it must connect to a working DBI database driver.

  In order to test DBIx::SQLEngine against your local database, set the DBI_DSN 
  environment variable to your connection string before running the tests, and 
  if needed, also set the DBI_USER and DBI_PASS variables. 
    Example:  > setenv DBI_DSN "DBI:mysql:test"
              > make test

  Alternately, you can run test.pl and pass the DSN, user, and password as
  command-line arguments.
    Example:  > perl -Iblib test.pl "DBI:mysql:test"

  A table named sqle_test will be created in this database, queried, and 
  then dropped.

.

  foreach my $driver ( DBI->available_drivers ) {
    eval {
      DBI->install_driver($driver);
      my @data_sources;
      eval {
	@data_sources = DBI->data_sources($driver);
      };
      if (@data_sources) {
	foreach my $source ( @data_sources ) {
	  push @suggestions, ( $source =~ /:/ ? $source : "dbi:$driver:$source" );
	} 
      } else { 
	push @suggestions, "dbi:$driver";
      }
    };
  } 

  eval { require DBD::AnyData };
  unless ( $@ ) {
    push @suggestions, 'dbi:AnyData:';
  }

  eval { require DBD::SQLite };
  unless ( $@ ) {
    push @suggestions, 'dbi:SQLite:dbname=test.sqlite';
  }

  eval { require DBD::mysql };
  unless ( $@ ) {
    push @suggestions, 'dbi:mysql:test';
  }
  if ( scalar @suggestions ) {
    %suggestions = map { $_ => 1 } grep { ! /dbi:ExampleP/ } @suggestions;
    @suggestions = sort { lc($a) cmp lc($b) } keys %suggestions;
    print join '', map "$_\n", "  You may wish to try one or more of the following suggested DSN values:", map "    $_", @suggestions;
  }

  exit 0;

}

########################################################################

print <<".";

  The remaining tests will use the DBI DSN specified on the command line, 
  or in your environment variables, currently: 
    $dsn

  In a few seconds, this script will connect to the database, create a 
  table named sqle_test, run various queries aginst it, and then drop it.
  
.

sleep(3);

my $sqldb;
ok( $sqldb = DBIx::SQLEngine->new($dsn, $user, $pass) );

ok( ref($sqldb) =~ /DBIx::SQLEngine::(.+)/ );
warn "  Using a DBI $sqldb->{dbh}->{Driver}->{Name} handle, SQLEngine subclass is $1... \n";

if ( $^W ) {
  $sqldb->DBILogging(1);
}

ok( $sqldb->detect_any );

########################################################################

my $table = 'sqle_test';

CREATE_TABLE: {

  $sqldb->do_drop_table( $table ) if $sqldb->detect_table($table, 'quietly');
  $sqldb->do_create_table( $table, [
    { name => 'id', type => 'sequential' },
    { name => 'name', type => 'text', length => 16 },
    { name => 'color', type => 'text', length => 8 },
  ]);
  ok( 1 );

}

FETCH_COLUMN_INFO: {

  my @cols = $sqldb->detect_table( $table );
  ok( scalar( @cols ) == 3 );
  @cols = $sqldb->detect_table( 'area_51_secrets', 'quietly' );
  ok( scalar( @cols ) == 0 );

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
  ok( 1 );
  
  $rows = $sqldb->fetch_select( table => $table );
  ok( ref $rows and scalar @$rows == 4 );

}

SELECT_CRITERIA: {

  my $rows = $sqldb->fetch_select( table => $table, criteria => { name=>'Dave' } );
  ok( ref $rows and scalar @$rows == 1 and $rows->[0]->{'name'} eq 'Dave' );
  
  $rows = $sqldb->fetch_select( table => $table, criteria => "name = 'Dave'" );
  ok( ref $rows and scalar @$rows == 1 and $rows->[0]->{'name'} eq 'Dave' );
  
  $rows = $sqldb->fetch_select( sql => "select * from $table where name = 'Dave'" );
  ok( ref $rows and scalar @$rows == 1 and $rows->[0]->{'name'} eq 'Dave' );
  
  $rows = $sqldb->fetch_select( sql => [ "select * from $table where name = ?", 'Dave' ] );
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
  ok( ref $rows and scalar @$rows == 3 );

}

NULL_VALUE_LOGIC: {

  my $rows = $sqldb->fetch_select( table=>$table, criteria=>{ name=>undef() } );
  ok( ref $rows and scalar @$rows == 0 );
  
  $sqldb->do_update( table => $table, criteria => { name=>\"'Dave'" }, values => { name=>undef() } );
  ok( 1 );
  
  $rows = $sqldb->fetch_select( table=>$table, criteria=>{ name=>undef() } );
  ok( (ref $rows and scalar @$rows == 1 and $rows->[0]->{'color'} eq 'mauve'), 1, "Couldn't select null value rows" );

}

DROP_TABLE: {

  $sqldb->do_drop_table( $table );
  ok( 1 );

}

########################################################################

1;
