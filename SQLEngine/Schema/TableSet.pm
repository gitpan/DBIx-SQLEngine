=head1 NAME

DBIx::SQLEngine::Schema::TableSet - Group of tables 

=head1 SYNOPSIS

  use DBIx::SQLEngine::Schema::TableSet;
  my $ts = DBIx::SQLEngine::Schema::TableSet->new();
  $ts->connect_datasource( $dsn, $user, $pass );
  $ts->packages( 'MyClassName' => 'mytablename' );
  $ts->require_packages;
  $ts->declare_tables;

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
  my @cols = map {
    ( ref($_) eq 'HASH' ) ? DBIx::SQLEngine::Schema::Table->new_from_hash(%$_)
			  : $_
  } @_;
  bless \@cols, $package;
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
