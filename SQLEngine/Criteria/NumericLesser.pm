package DBIx::SQLEngine::Criteria::NumericLesser;

use DBIx::SQLEngine::Criteria::Comparison;
@ISA = 'DBIx::SQLEngine::Criteria::Comparison';
use strict;
use Carp;

__PACKAGE__->sql_comparator('<');

1;

__END__

########################################################################

=head1 NAME

DBIx::SQLEngine::Criteria::NumericLesser- Basic Numeric Criteria

=head1 SYNOPSIS

  my $crit = DBIx::SQLEngine::Criteria::NumericLesser->new( $expr, $value );


=head1 DESCRIPTION

DBIx::SQLEngine::Criteria::NumericLesser objects check that an expression is less than a given reference value.

See L<DBIx::SQLEngine::Criteria::Comparison> for more.


=head1 VERSION

2001-06-28 Cloned from StringEquality.


=head1 AUTHORS

Developed by Evolution Online Systems:

  M. Simon Cavalletto, simonm@evolution.com


=head1 LICENSE

This module is free software. It may be used, redistributed and/or
modified under the same terms as Perl.

Copyright (c) 1998, 1999, 2000, 2001 Evolution Online Systems, Inc.

=cut
