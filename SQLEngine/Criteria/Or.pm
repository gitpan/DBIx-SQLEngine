package DBIx::SQLEngine::Criteria::Or;
use DBIx::SQLEngine::Criteria::Compound;
@ISA = 'DBIx::SQLEngine::Criteria::Compound';
use strict;

__PACKAGE__->sql_join('or');

1;

__END__

########################################################################

=head1 NAME

DBIx::SQLEngine::Criteria::Or - Compound Any Criteria

=head1 SYNOPSIS

  my $crit = DBIx::SQLEngine::Criteria::Or->new( $crit, ... );


=head1 DESCRIPTION

DBIx::SQLEngine::Criteria::Or objects are built around an array of other criteria, any of which may be satisified in order for the Or criterion to be met.

See L<DBIx::SQLEngine::Criteria::Compound> for more.


=head1 VERSION

2001-06-28 Moved to DBIx::O2:: namespace. Separated from base Compound module.


=head1 AUTHORS

Developed by Evolution Online Systems:

  M. Simon Cavalletto, simonm@evolution.com


=head1 LICENSE

This module is free software. It may be used, redistributed and/or
modified under the same terms as Perl.

Copyright (c) 1996, 1997, 1999, 2000, 2001 Evolution Online Systems, Inc.

=cut

1;
