=head1 NAME

DBIx::SQLEngine::Schema::TableSet - Array of Schema::Table objects 

=head1 SYNOPSIS

  use DBIx::SQLEngine::Schema::TableSet;
  my $tables = DBIx::SQLEngine::Schema::TableSet->new( $table1, $table2 );
  
  print $tables->count;
  
  foreach my $table ( $tables->tables ) {
    print $table->name;
  }
  
  $table = $tables->table_named( $name );

  $ts->create_tables;

=head1

This is an example use of the DBIx::DBO2 framework used for testing purposes.

=cut

package DBIx::SQLEngine::Schema::TableSet;

use strict;
use Carp;
use Class::MakeMethods;

use DBIx::SQLEngine::Schema::Table;

########################################################################

sub new {
  my $package = shift;
  my @tables = map {
    ( ref($_) eq 'HASH' ) ? DBIx::SQLEngine::Schema::Table->new_from_hash(%$_)
			  : $_
  } @_;
  bless \@tables, $package;
}

sub tables {
  my $tables = shift;
  @$tables
}

# @colnames = $tables->table_names;
sub table_names {
  my $tables = shift;
  return map { $_->name } @$tables;
}

# $table = $tables->table_named( $table_name );
# $table = $tables->table_named( $table_name );
sub table_named {
  my $tables = shift;
  my $table_name = shift;
  foreach ( @$tables ) {
    return $_ if ( $_->name eq $table_name );
  }
  croak(
    "No table named $table_name in this set\n" . 
    "  (Perhaps you meant one of these: ".join(', ',$tables->table_names)."?)"
  );
}

########################################################################

sub create_tables {
  my $self = shift;
  
  foreach my $table ( $self->tables ) {
    $table->table_create;
  }
}

sub ensure_tables_exist {
  my $self = shift;
  
  foreach my $table ( $self->tables ) {
    next if $table->table_exists;
    $table->table_create;
  }
}

sub refresh_tables_schema {
  my $self = shift;
  
  foreach my $table ( $self->tables ) {
    next if $table->table_exists;
    $table->table_recreate_with_rows;
  }
}

sub drop_tables {
  my $self = shift;
  
  foreach my $table ( $self->tables ) {
    $table->table_drop;
  }
}

########################################################################

=head1 SEE ALSO

See L<DBIx::SQLEngine> for the overall interface and developer documentation.

See L<DBIx::SQLEngine::Docs::ReadMe> for general information about
this distribution, including installation and license information.

=cut

########################################################################

1;
