=head1 NAME

DBIx::SQLEngine::Criteria::Comparison - Superclass for comparisons

=head1 SYNOPSIS

  my $crit = DBIx::SQLEngine::Criteria::ComparisonSubclass->new( $key, $value );


=head1 DESCRIPTION

DBIx::SQLEngine::Criteria::Comparison objects provide a structured representation of certain simple kinds of SQL criteria clauses, those of the form C<column_or_expression comparison_operator comparison_value>.

Each Criteria::Comparison object is implemented in the form of blessed arrayref, with two items in the array. The first is the column name (or SQL expression) to be compared against, and the second is the comparison value. The type of comparison operator to use is indicated by which subclass of Criteria::Comparison the object is blessed into. 

The comparison value is assumed by default to be a literal string or numeric value, and uses parameter substitution to avoid having to deal with quoting. If you actually want to compare against another column or expression, pass a reference to the column name or expression string. For example, to select records where C<first_name = last_name>, you could use:

  DBIx::SQLEngine::Criteria::StringEquality->('first_name', \'last_name');

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
  # 2002-11-02 Patch from Michael Kroell, University of Innsbruck
  #( defined $compv ) or Carp::confess("Comparison value is missing or empty");
  my $cmp = $self->sql_comparator;
  ( length $cmp ) or Carp::confess("sql_comparator is missing or empty");
  
  # 2002-11-02 Based on patch from Michael Kroell, University of Innsbruck
  if ( ! defined($compv) ) {
    if ( $cmp eq '=' ) { $cmp = 'IS' }
    join(' ', $expr, $cmp, 'NULL' );
  } elsif ( ! ref($compv) ) {
    join(' ', $expr, $cmp, '?' ), $compv;
  } elsif ( ref($compv) eq 'SCALAR' ) {
    join(' ', $expr, $cmp, $$compv );
  } else {
    Carp::confess("Can't use '$compv' as a comparison value");
  }
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
