#!/usr/bin/perl

use Test;
BEGIN { plan tests => 18 }

use DBIx::SQLEngine;
ok( 1 );
sub clone { &DBIx::SQLEngine::Driver::Default::_clone_with_parameters }

########################################################################

ok( clone(1), 1 );

$array = clone([ 1, 2, 3]);
ok( ref $array, 'ARRAY' );
ok( $array->[0] == 1 and $array->[1] == 2 and $array->[2] == 3 );

$hash = clone({ foo => 'FooBar', baz => 'Basil' });
ok( ref $hash, 'HASH' );
ok( $hash->{foo} eq 'FooBar' and $hash->{baz} eq 'Basil' );

########################################################################

ok( clone(\$1, 1), 1 );

ok( clone(\$1, 2), 2 );

$array = clone([ \$1, \$2, \$3], 3, 2, 1);
ok( ref $array, 'ARRAY' );
ok( $array->[0] == 3 and $array->[1] == 2 and $array->[2] == 1 );

$array = clone([ 1, \$1, 3], 2);
ok( ref $array, 'ARRAY' );
ok( $array->[0] == 1 and $array->[1] == 2 and $array->[2] == 3 );

$hash = clone({ foo => \$1, baz => \$2 }, 'FooBar', 'Basil');
ok( ref $hash, 'HASH' );
ok( $hash->{foo} eq 'FooBar' and $hash->{baz} eq 'Basil' );

########################################################################

$hash = clone({ foo => \$2, baz => \$2 }, 'FooBar', 'Basil');
ok( ref $hash, 'HASH' );
ok( $hash->{foo} eq 'Basil' and $hash->{baz} eq 'Basil' );

########################################################################

ok( ! eval { clone(\$1); 1 } );

ok( ! eval { clone(\$1, 1, 2, 3); 1 } );

########################################################################

1;
