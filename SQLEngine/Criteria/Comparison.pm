=head1 NAME

DBIx::SQLEngine::Criteria::Comparison - Superclass for comparisons

=head1 SYNOPSIS

  my $crit = DBIx::SQLEngine::Criteria::ComparisonSubclass->new( $key, $value );


=head1 DESCRIPTION

DBIx::SQLEngine::Criteria::Comparison objects are built around an array of other criteria.

=cut

package DBIx::SQLEngine::Criteria::Comparison;
@ISA = 'DBIx::SQLEngine::Criteria';
use strict;

########################################################################

=head1 REFERENCE

=head2 Constructor

=over 4

=item new ( $key, $value ) : $Comparison

Constructor.

=back

=cut

sub new {
  my $package = shift;
  bless [ @_ ], $package;
}


########################################################################

=head2 Content Access

=over 4

=item expr () : $fieldname

=item expr ( $fieldname )

=item compv () : $comparsion_value

=item compv ( $comparsion_value )

Accessor

=back

=cut

use Class::MakeMethods (
  'Standard::Array:scalar' => 'expr',
  'Standard::Array:scalar' => 'compv',
);

########################################################################

use Class::MakeMethods (
  'Template::Class:string' => 'sql_comparator',
);

sub sql_where {
  my $self = shift;
  my $expr = $self->expr;
  ( length $expr ) or Carp::confess("Expression is missing or empty");
  my $compv = $self->compv;
  ( defined $compv ) or Carp::confess("Comparison value is missing or empty");
  my $cmp = $self->sql_comparator;
  ( length $cmp ) or Carp::confess("sql_comparator is missing or empty");
  join(' ', $expr, $cmp, '?' ), $compv;
}

########################################################################

=head1 VERSION

2001-06-28 Simon: Moved to DBIx::O2:: namespace. Switched to Class::MakeMethods. Renamed from SimpleSQL to Comparison.

1999-10-13 Chaos: Added NumericInequality criterion. 

1999-10-05 Chaos: Fixed StringInequality criterion. 

1999-01-31 Simon: Removed Data::Collection dependancy; now handled by Data::DRef.

1998-09-18 Simon: Updated to use MethodMaker::Compatibility instead of NamedFactory.

1998-03-19 Simon: Switched to new table->quote_for_column method.

1998-03-17 Simon: Split DBO::Criteria subclasses into new .pm files. 


=head1 AUTHORS

Developed by Evolution Online Systems:

  M. Simon Cavalletto, simonm@evolution.com


=head1 LICENSE

This module is free software. It may be used, redistributed and/or
modified under the same terms as Perl.

Copyright (c) 1996, 1997, 1999, 2000, 2001 Evolution Online Systems, Inc.

=cut

1;
