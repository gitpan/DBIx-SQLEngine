#!/usr/bin/perl

use Test::Harness;
use File::Find;

sub get_tests {
  my @t;
  find( sub { /\.t\z/ and push @t, $File::Find::name }, @_ );
  return sort { lc $a cmp lc $b } @t
	or die "$0: Can't find any tests in @_\n";
}

@t_all = get_tests( 'test_core' );

@t_dsn = get_tests( 'test_drivers' );

open( CNXNS, 'test.config' );
@dsns = <CNXNS>;
close( CNXNS );

( -d "test_data" ) or mkdir("test_data");
foreach ( @dsns ) {
  if ( m{(test_data/\w+)} ) {
    next if ( -d $1 );
    warn "Creating test data directory:  $1\n";
    mkdir $1;
  }
}

# define_named_connections_from_text

my $separator = ( '=' x 79 ) . "\n";

print $separator;

if ( scalar(@dsns) ) {
  warn "Running " . ( scalar(@t_all) + scalar(@t_dsn) * scalar(@dsns)  ) . " tests: " . scalar(@t_all) . " core tests plus " . scalar(@t_dsn) . " tests for use with each of " . scalar(@dsns) . " DSNs.\n";
} else {
  warn "Running " . ( scalar(@t_all) + scalar(@t_dsn) * scalar(@dsns)  ) . " tests: " . scalar(@t_all) . " core tests.\n";
  warn <<".";
  In order to run the driver tests against one or more local databases, edit the 
  test.config file. Using each of the connections listed in that file, 
  the driver test scripts will create various tables with "sqle_test" in their 
  names, run various queries against those tables, and then drop the tables. 

  Although this should not affect other applications, for safety's sake, use
  a test account or temporary data space, and avoid testing this on any
  mission-critical production systems.
.
}

print $separator;

unshift @INC, qw( blib/arch blib/lib );
$Test::Harness::verbose = $ENV{TEST_VERBOSE} || 0;

local $ENV{DBI_DSN}="";
Test::Harness::runtests( @t_all );

foreach my $dsn ( @dsns ) {

  chomp $dsn;
  print $separator;

  $ENV{DBI_DSN} = "$dsn"; 

  print "Starting Driver Tests For: $dsn\n";

  eval {
    Test::Harness::runtests( @t_dsn );
  };
  if ( $@ ) {
    warn "Failure: $@"
  }

}

print $separator;
