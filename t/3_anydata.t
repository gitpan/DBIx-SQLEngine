#!/usr/bin/perl

use Test;
BEGIN {
  eval { require DBD::AnyData };
  if ( $@ ) {
    plan( tests => 1 );
    skip(
      "Skipping: Unable to load the optional DBD::AnyData module.", 0
    );
    exit 0;
  }
}

@ConnectArgs = ( 'dbi:AnyData:' );

require "t/common.pl";

1;
