=head1 NAME

DBIx::SQLEngine::DriverTrait::NoComplexJoins - For databases without complex joins

=head1 SYNOPSIS

  # Classes can import this behavior if they don't have joins using ON
  use DBIx::SQLEngine::DriverTrait::NoComplexJoins ':all';
  
  # Implements a workaround for unavailable "inner join on ..." capability
  $rows = $sqldb->fetch_select_rows( tables => [
    'foo', inner_join=>[ 'foo.id = bar.id' ], 'bar'
  ] );
  
  # Attempts to use the "outer join" produce an exception
  $rows = $sqldb->fetch_select_rows( tables => [
    'foo', inner_join=>[ 'foo.id = bar.id' ], 'bar'
  ] );

=head1 DESCRIPTION

This package supports SQL database servers which do natively provide a SQL
select with inner and outer joins. Instead, inner joins are replaced with cross joins and a where clause. Outer joins, including left and right joins, are not supported and will cause an exception.

Note: this feature has been added recently, and the interface is subject to change.

=head2 Caution

Because of the way DBIx::AnyDBD munges the inheritance tree, DBIx::SQLEngine
subclasses can not reliably inherit from this package. To work around this,
we export all of the methods into their namespace using Exporter and @EXPORT.

=cut

########################################################################

package DBIx::SQLEngine::DriverTrait::NoComplexJoins;

use Exporter;
sub import { goto &Exporter::import } 
@EXPORT_OK = qw( 
  sql_join
  dbms_join_on_unsupported dbms_outer_join_unsupported
);
%EXPORT_TAGS = ( all => \@EXPORT_OK );

use strict;
use Carp;

########################################################################

sub dbms_join_on_unsupported { 1 }
sub dbms_outer_join_unsupported { 1 }

########################################################################

sub sql_join {
  my ($self, @exprs) = @_;
  my $sql = '';
  my @params;
  my @where_sql;
  my @where_params;
  while ( scalar @exprs ) {
    my $expr = shift @exprs;
    if ( ! ref $expr and $expr =~ /^[\w\s]+join$/i and ref($exprs[0]) ) {
      my $join = $expr;
      my $criteria = shift @exprs;
      my $table = shift @exprs or croak("No table name provided to join to");

      $join =~ tr[_][ ];
      ( $join !~ /outer|right|left/i ) 
	  or confess("This database does not support outer joins");

      my ( $expr_sql, @expr_params ) = $self->sql_join_expr( $table );
      if ( $expr_sql =~ s/ where (.*)$// ) {
	push @where_sql, $1;
	push @where_params, @expr_params;
      }
      $sql .= ", $expr_sql";
      push @params, @expr_params;

      my ($crit_sql, @crit_params) = 
			DBIx::SQLEngine::Criteria->auto_where( $criteria );
      push @where_sql, $crit_sql if ( $crit_sql );
      push @where_params, @crit_params;

    } else {
      my ( $expr_sql, @expr_params ) = $self->sql_join_expr( $expr );
      $sql .= ", $expr_sql";
      push @params, @expr_params;
    }
  }
  $sql =~ s/^, // or carp("Suspect table join: '$sql'");
  if ( scalar @where_sql ) {
    $sql .= " where " . ( ( scalar(@where_sql) == 1 ) ? $where_sql[0] 
				  : join( 'and', map "( $_ )", @where_sql ) );
    push @params, @where_params;
  }
  ( $sql, @params );
}

########################################################################

=head1 SEE ALSO

See L<DBIx::SQLEngine> for the overall interface and developer documentation.

See L<DBIx::SQLEngine::Docs::ReadMe> for general information about
this distribution, including installation and license information.

=cut

########################################################################

1;

