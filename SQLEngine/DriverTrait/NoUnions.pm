=head1 NAME

DBIx::SQLEngine::DriverTrait::NoUnions - For databases without select unions

=head1 SYNOPSIS

  # Classes can import this behavior if they don't have native unions
  use DBIx::SQLEngine::DriverTrait::NoUnions ':all';
  
  # Implements a workaround for unavailable sql_union capability
  $rows = $sqldb->fetch_select_rows( union => [
    { table => 'foo', columns => '*' },
    { table => 'bar', columns => '*' },
  ] );

=head1 DESCRIPTION

This package supports SQL database servers which do natively provide a SQL
select with unions. Instead, queries with unions are executed separately and
their results combined.

Note: this feature has been added recently, and the interface is subject to change.

=head2 Caution

Because of the way DBIx::AnyDBD munges the inheritance tree, DBIx::SQLEngine
subclasses can not reliably inherit from this package. To work around this,
we export all of the methods into their namespace using Exporter and @EXPORT.

In addition we go through some effort to re-dispatch methods because we can't
rely on SUPER and we don't want to require NEXT. This isn't too complicated,
as we know the munged inheritance tree only uses single inheritance. See the
source code for the _super_dispatch function that handles this.

=cut

########################################################################

package DBIx::SQLEngine::DriverTrait::NoUnions;

use Exporter;
sub import { goto &Exporter::import } 
@EXPORT_OK = qw( 
  sql_union dbms_union_unsupported
  fetch_select fetch_select_rows 
  visit_select visit_select_rows
);
%EXPORT_TAGS = ( all => \@EXPORT_OK );

use strict;
use Carp;

########################################################################

sub _super_dispatch {
  my ( $self, $method, @args ) = @_;
  
  no strict 'refs';
  my $super = ${ ref($self) . '::ISA' }[0] . "::" . $method;
  # warn "_super_d: $super " . wantarray() . "\n";
  $self->$super( @args );
}

########################################################################

=head1 REFERENCE

The following methods are provided:

=cut

########################################################################

=head2 dbms_union_unsupported()

Set to 1.

=head2 sql_union()

Calls Carp::confess().

=cut

sub dbms_union_unsupported { 1 }

sub sql_union { confess("Union unsupported on this platform") }

########################################################################

=head2 fetch_select()

Simply calls the superclass method unless the union clause is provided. 
Runs each of the provided queries separately and concatenates their results.

=head2 fetch_select_rows()

Simply calls the superclass method unless the union clause is provided. 
Runs each of the provided queries separately and concatenates their results.

=head2 visit_select()

Simply calls the superclass method unless the union clause is provided. 
Runs each of the provided queries separately and concatenates their results.

Note: This method doesn't yet munge the column names retrived by the later queries.

=head2 visit_select_rows()

Simply calls the superclass method unless the union clause is provided. 
Runs each of the provided queries separately and concatenates their results.

=cut

sub fetch_select {
  my ( $self, %clauses ) = @_;
  my $union = delete $clauses{'union'} 
    or return _super_dispatch($self, 'fetch_select', %clauses);

  my ( $union_rows, $union_columns );
  foreach my $query ( @$union ) {
    my ( $rows, $columns ) = $self->fetch_select_rows( 
	( ref($query) eq 'ARRAY' ) ? @$query : %$query );

    # use Data::Dumper;
    # warn "No union hashes: " . Dumper( $rows );
    # warn "No union cols: " . Dumper( $columns );

    push @$union_rows, @$rows;
    $union_columns ||= $columns;
  }
  
  my @colnames = map { $_->{name} } @$union_columns;
  
  my $union_hashes = [
    map { my %hash; @hash{ @colnames } = @$_; \%hash } @$union_rows
  ];
  
  wantarray ? ( $union_hashes, $union_columns ) : $union_hashes;
}

sub fetch_select_rows {
  my ( $self, %clauses ) = @_;
  my $union = delete $clauses{'union'}
	or return _super_dispatch($self, 'fetch_select_rows', %clauses );

  my ( $union_rows, $union_columns );
  foreach my $query ( @$union ) {
    my ( $rows, $columns ) = $self->fetch_select_rows( 
	( ref($query) eq 'ARRAY' ) ? @$query : %$query );

    use Data::Dumper;
    # warn "No union rows: " . Dumper( $rows );
    # warn "No union cols: " . Dumper( $columns );

    push @$union_rows, @$rows;
    $union_columns ||= $columns;
  }
  wantarray ? ( $union_rows, $union_columns ) : $union_rows;
}

sub visit_select {
  my $self = shift;
  my $code = ( ref($_[0]) ? shift : pop );
  my %clauses = @_;

  my $union = delete $clauses{'union'}
	or return _super_dispatch($self, 'visit_select_rows', $code, %clauses );

  my @results;
  foreach my $query ( @$union ) {

    # INCOMPLETE -- this should mangle the column names to match first query

    push @results, $self->visit_select( $code,
	( ref($query) eq 'ARRAY' ) ? @$query : %$query );
  }
  @results;
}

sub visit_select_rows {
  my $self = shift;
  my $code = ( ref($_[0]) ? shift : pop );
  my %clauses = @_;

  my $union = delete $clauses{'union'}
	or return _super_dispatch($self, 'visit_select_rows', $code, %clauses );

  my @results;
  foreach my $query ( @$union ) {
    push @results, $self->visit_select_rows( $code,
	( ref($query) eq 'ARRAY' ) ? @$query : %$query );
  }
  @results;
}

########################################################################

=head1 SEE ALSO

See L<DBIx::SQLEngine> for the overall interface and developer documentation.

See L<DBIx::SQLEngine::Docs::ReadMe> for general information about
this distribution, including installation and license information.

=cut

########################################################################

1;

