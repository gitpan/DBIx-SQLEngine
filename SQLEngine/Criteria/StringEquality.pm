package DBIx::SQLEngine::Criteria::StringEquality;

use DBIx::SQLEngine::Criteria::Comparison;
@ISA = 'DBIx::SQLEngine::Criteria::Comparison';
use strict;
use Carp;

__PACKAGE__->sql_comparator('=');

1;

__END__

########################################################################

=head1 NAME

DBIx::SQLEngine::Criteria::StringEquality - Basic String Criteria

=head1 SYNOPSIS

  my $crit = DBIx::SQLEngine::Criteria::StringEquality->new( $expr, $value );


=head1 DESCRIPTION

DBIx::SQLEngine::Criteria::StringEquality objects are check that an expression exactly matches a given reference value.

See L<DBIx::SQLEngine::Criteria::Comparison> for more.


=head1 VERSION

2001-06-28 Moved to DBIx::O2:: namespace. Separated from base Comparison module.


=head1 AUTHORS

Developed by Evolution Online Systems:

  M. Simon Cavalletto, simonm@evolution.com


=head1 LICENSE

This module is free software. It may be used, redistributed and/or
modified under the same terms as Perl.

Copyright (c) 1998, 1999, 2000, 2001 Evolution Online Systems, Inc.

=cut
