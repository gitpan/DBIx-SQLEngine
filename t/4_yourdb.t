#!/usr/bin/perl

use Test;
BEGIN {
  unless ( $ENV{DBI_DSN} ) {
    plan( tests => 1 );
    skip(
      "Skipping: specify DBI_DSN in environment to test your local server.\n",
      0,
    );
    # ok( 1 );
    exit 0;
  }
}

@ConnectArgs = map $ENV{$_}, qw( DBI_DSN DBI_USER DBI_PASS );

require "t/common.pl";

1;
