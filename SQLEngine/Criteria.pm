package DBIx::SQLEngine::Criteria;
use strict;

use Class::MakeMethods (
  'Standard::Universal:abstract' => 'new',
  'Template::ClassName:subclass_name --require' => 'type',
);

sub type_new {
  (shift)->type( shift )->new( @_ );
}

1;

__END__

=head1 NAME

DBIx::SQLEngine::Criteria - Struct for database criteria info

=head1 SYNOPSIS

  my $crit = DBIx::SQLEngine::Criteria->type_new( $type, ... );
  
  print $crit->sql_where();


=head1 DESCRIPTION

DBIx::SQLEngine::Criteria objects hold information about particular query criteria.


=head1 REFERENCE

=head2 Constructor

Multiple subclasses based on type.

=over 4

=item new - abstract

Implemented in each subclass

=item type_new ( $type, @args ) : $criteria

Looks up type, then calls new.

=item type - Template::ClassName:subclass_name

Multiple subclasses based on type.

=back

=cut
