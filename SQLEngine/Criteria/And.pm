package DBIx::SQLEngine::Criteria::And;
use DBIx::SQLEngine::Criteria::Compound;
@ISA = 'DBIx::SQLEngine::Criteria::Compound';
use strict;

__PACKAGE__->sql_join('and');

1;

__END__

########################################################################

=head1 NAME

DBIx::SQLEngine::Criteria::And - Compound All Criteria

=head1 SYNOPSIS

  my $crit = DBIx::SQLEngine::Criteria::And->new( $crit, ... );


=head1 DESCRIPTION

DBIx::SQLEngine::Criteria::And objects are built around an array of other criteria, all of which must be satisified in order for the And criterion to be met.

See L<DBIx::SQLEngine::Criteria::Compound> for more.


=head1 VERSION

2001-06-28 Moved to DBIx::O2:: namespace. Separated from base Compound module.


=head1 AUTHORS

Developed by Evolution Online Systems:

  M. Simon Cavalletto, simonm@evolution.com


=head1 LICENSE

This module is free software. It may be used, redistributed and/or
modified under the same terms as Perl.

Copyright (c) 1998, 1999, 2000, 2001 Evolution Online Systems, Inc.

=cut
