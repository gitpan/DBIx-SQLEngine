=head1 NAME

DBIx::SQLEngine::Criteria - Struct for database criteria info

=head1 SYNOPSIS

  my $crit = DBIx::SQLEngine::Criteria->type_new( $type, ... );
  
  print $crit->sql_where();


=head1 DESCRIPTION

DBIx::SQLEngine::Criteria objects hold information about particular query criteria.

=cut

package DBIx::SQLEngine::Criteria;
use strict;

########################################################################

=head1 REFERENCE

=head2 Constructor

Multiple subclasses based on type.

=over 4

=item new 

Abstract. Implemented in each subclass

=item type_new

  DBIx::SQLEngine::Criteria->type_new( $type, @args ) : $criteria

Looks up type, then calls new.

=item type 

Multiple subclasses based on type. (See L<Class::MakeMethods::Template::ClassName/subclass_name>.)

=back

=cut

use Class::MakeMethods (
  'Standard::Universal:abstract' => 'new',
  'Template::ClassName:subclass_name --require' => 'type',
);

sub type_new {
  (shift)->type( shift )->new( @_ );
}

########################################################################

=head2 Generic Argument Parsing

=over 4

=item auto

  DBIx::SQLEngine::Criteria->auto( $sql_string ) : $criteria
  DBIx::SQLEngine::Criteria->auto( [ $sql_string, @params ] ) : $criteria
  DBIx::SQLEngine::Criteria->auto( $criteria_object ) : $criteria_object
  DBIx::SQLEngine::Criteria->auto( { fieldname => matchvalue, ... } ) : $criteria

Convert any one of several standard criteria representations into a DBIx::SQLEngine::Criteria object.

=item auto_and 

  DBIx::SQLEngine::Criteria->auto( @any_of_the_above ) : $criteria

Create a single criteria requiring the satisfaction of each of the separate criteria passed in. Supports the same argument forms as auto.

=item auto_where

  DBIx::SQLEngine::Criteria->auto_where( @any_of_the_above ) : $sql, @params

Create a single criteria requiring the satisfaction of each of the separate criteria passed in, and returns its sql_where results. Supports the same argument forms as auto.

=back

=cut

sub auto {
  my $package = shift;
  local $_ = shift;
  if ( ! $_ ) {
    ();
  } elsif ( ! ref( $_ ) and length( $_ ) ) {
    $package->type('LiteralSQL')->new( $_ );
  } elsif ( UNIVERSAL::can($_, 'sql_where') ) {
    $_;
  } elsif ( ref($_) eq 'ARRAY' ) {
    $package->type('LiteralSQL')->new( @$_ );
  } elsif ( ref($_) eq 'HASH' ) {
    $package->type('HashGroup')->new( %$_ );
  } else {
    confess("Unsupported criteria spec '$_'");
  }
}

sub auto_and {
  my $package = shift;
  $package->type('And')->new(
    map {
      if ( ! $_ ) {
	();
      } elsif ( ! ref( $_ ) and length( $_ ) ) {
	$package->type('LiteralSQL')->new( $_ );
      } elsif ( UNIVERSAL::can($_, 'sql_where') ) {
	$_;
      } elsif ( ref($_) eq 'ARRAY' ) {
	$package->type('LiteralSQL')->new( @$_ );
      } elsif ( ref($_) eq 'HASH' ) {
	$package->type('HashGroup')->new( %$_ );
      } else {
	confess("Unsupported criteria spec '$_'");
      }
    } @_
  )
}

sub auto_where {
  my $package = shift;
  $package->auto_and( @_ )->sql_where;
}

1;

