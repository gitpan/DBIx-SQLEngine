=head1 NAME

DBIx::SQLEngine::Criteria::LiteralSQL - Holder for SQL snippets

=head1 SYNOPSIS

  my $crit = DBIx::SQLEngine::Criteria::LiteralSQL->new( "name = 'Dave'" );


=head1 DESCRIPTION

DBIx::SQLEngine::Criteria::Comparison objects are built around an array of a SQL string, followed by values to be bound the the '?' placeholders in the string, if any.

=cut

package DBIx::SQLEngine::Criteria::LiteralSQL;
@ISA = 'DBIx::SQLEngine::Criteria';
use strict;

########################################################################

=head1 REFERENCE

=head2 Constructor

=over 4

=item new

  DBIx::SQLEngine::Criteria::LiteralSQL->new( $sql ) : $Comparison

  DBIx::SQLEngine::Criteria::LiteralSQL->new( $sql, @params ) : $Comparison

Constructor.

=back

=cut

sub new {
  my $package = shift;
  bless [ @_ ], $package;
}

########################################################################

sub sql_where {
  my $self = shift;
  @$self;
}

########################################################################

=head1 VERSION

2002-01-31 Simon: Created.


=head1 SEE ALSO

L<DBIx::SQLEngine::ReadMe>.

=cut
