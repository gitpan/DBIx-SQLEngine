package DBIx::SQLEngine::Criteria::StringLike;

use DBIx::SQLEngine::Criteria::Comparison;
@ISA = 'DBIx::SQLEngine::Criteria::Comparison';
use strict;
use Carp;

__PACKAGE__->sql_comparator('like');

1;

__END__

########################################################################

=head1 NAME

DBIx::SQLEngine::Criteria::StringLike - SQL92 Like Criteria

=head1 SYNOPSIS

  my $crit = DBIx::SQLEngine::Criteria::StringLike->new( $expr, $value );


=head1 DESCRIPTION

DBIx::SQLEngine::Criteria::StringLike objects check that an expression
matches a given SQL wildcard pattern. ANSI SQL 92 provides for "%"
wildcards, and some vendors support additional patterns.


=head1 SEE ALSO

See L<DBIx::SQLEngine::Criteria> and L<DBIx::SQLEngine::Criteria::Comparison>
for more information on using these objects.

See L<DBIx::SQLEngine> for the overall interface and developer documentation.

See L<DBIx::SQLEngine::Docs::ReadMe> for general information about
this distribution, including installation and license information.

=cut
