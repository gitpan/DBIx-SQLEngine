package DBIx::SQLEngine::Criteria::Not;

@ISA = 'DBIx::SQLEngine::Criteria';
use strict;

sub new {
  my $package = shift;
  bless [ shift ], $package;
}

sub sql_where {
    my $self = shift;
    my ($clause, @params) = $self->[0]->sql_where;

    return unless defined $clause and length $clause;

    return ( " NOT ( " . $clause . " ) ", @params )

}

1;

__END__

#########################################################################

=head1 NAME

DBIx::SQLEngine::Criteria::Not - Negating A Single Criteria

=head1 SYNOPSIS

  my $crit = DBIx::SQLEngine::Criteria::Not->new( $crit );


=head1 DESCRIPTION

DBIx::SQLEngine::Criteria::Not logicaly inverts a single given
criteria by wrapping it in a NOT criteria.

See L<DBIx::SQLEngine::Criteria> for more.


=head1 REFERENCE

=head2 Constructor

=over 4

=item new ( @criteria ) : $notcriteria

Constructor.

=back

=head1 AUTHORS

Developed by Innsbruck University:

   Christian Glahn, christian.glahn@uibk.ac.at

=head1 LICENSE

This module is free software. It may be used, redistributed and/or
modified under the same terms as Perl.

Copyright (c) 2002 ZID, Innsbruck University (Austria)

=cut
