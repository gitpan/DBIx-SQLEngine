=head1 NAME

DBIx::SQLEngine::Criteria::Compound - Superclass for And and Or

=head1 SYNOPSIS

  my $crit = DBIx::SQLEngine::Criteria::CompoundSubclass->new( $crit, ... );


=head1 DESCRIPTION

DBIx::SQLEngine::Criteria::Compound objects are built around an array of other criteria.

=cut

package DBIx::SQLEngine::Criteria::Compound;
@ISA = 'DBIx::SQLEngine::Criteria';
use strict;
use Carp;

########################################################################

=head1 REFERENCE

=head2 Constructor

=over 4

=item new ( @criteria ) : $compound

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

=item subs () : @criteria

Accessor

=item push_subs ( @criteria ) 

=item unshift_subs ( @criteria ) 

=back

=cut

sub subs {
  my $crit = shift;
  @$crit
}

sub push_subs {
  my $crit = shift;
  push @{ $crit->subs }, @_
}

sub unshift_subs {
  my $crit = shift;
  unshift @{ $crit->subs }, @_
}

########################################################################

use Class::MakeMethods (
  'Template::Class:string' => 'sql_join',
);

sub sql_where {
  my $self = shift;
  my (@clauses, @params);
  foreach my $sub ( $self->subs ) {
    my ($sql, @v_params) = $sub->sql_where( @_ );
    next if ( ! length $sql );
    push @clauses, $sql;
    push @params, @v_params;
  }
  return unless scalar @clauses;
  return ($clauses[0], @params) if ( scalar @clauses == 1 );
  my $joiner = $self->sql_join or Carp::confess "Class does not have a joiner";
  return ( '( ' . join( " $joiner ", @clauses ) . ' )', @params );
}

########################################################################

=head1 CHANGES

2002-01-31 Remove redundant parentheses around single-item list.

2001-06-28 Moved to DBIx::O2:: namespace. Switched to Class::MakeMethods. Renamed from Group to Compound.

2000-12-22 Added new_with_contents constructor

1999-01-31 Removed Data::Collection dependancy; now handled by Data::DRef.

1998-09-18 Updated to use MethodMaker::Compatibility instead of NamedFactory.

1998-03-17 Split DBO::Criteria subclasses into new .pm files.


=head1 AUTHORS

Developed by Evolution Online Systems:

  M. Simon Cavalletto, simonm@evolution.com


=head1 LICENSE

This module is free software. It may be used, redistributed and/or
modified under the same terms as Perl.

Copyright (c) 1996, 1997, 1999, 2000, 2001 Evolution Online Systems, Inc.

=cut

1;
