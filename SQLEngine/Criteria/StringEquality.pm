package DBIx::SQLEngine::Criteria::StringEquality;

use DBIx::SQLEngine::Criteria::Equality;
@ISA = 'DBIx::SQLEngine::Criteria::Equality';

1;

__END__

########################################################################

=head1 NAME

DBIx::SQLEngine::Criteria::StringEquality - Old name for Equality

=head1 SYNOPSIS

  my $crit = DBIx::SQLEngine::Criteria::Equality->new( $expr, $value );


=head1 DESCRIPTION

DBIx::SQLEngine::Criteria::StringEquality is the old name for DBIx::SQLEngine::Criteria::Equality.


=head1 SEE ALSO

See L<DBIx::SQLEngine::Criteria> and L<DBIx::SQLEngine::Criteria::Comparison>
for more information on using these objects.

See L<DBIx::SQLEngine> for the overall interface and developer documentation.

See L<DBIx::SQLEngine::Docs::ReadMe> for general information about
this distribution, including installation and license information.

=cut
