=head1 NAME

DBIx::SQLEngine::Driver::File - Extends SQLEngine for DBMS Idiosyncrasies

=head1 SYNOPSIS

  my $sqldb = DBIx::SQLEngine->new( 'dbi:file:f_dir=my_data_path' );
  
  $hash_ary = $sqldb->fetch_select( 
    table => 'students' 
    limit => 5, offset => 10
  );

=head1 DESCRIPTION

This package provides a subclass of DBIx::SQLEngine which compensates for DBD::File's idiosyncrasies.

=cut

########################################################################

package DBIx::SQLEngine::Driver::File;

use strict;
use Carp;

########################################################################

=head2 fetch_one_value

Special handling for simple functions.

=cut

sub fetch_one_value {
  my $self = shift;
  my %args = @_;
  if ( $args{columns} =~ /\A\s*max\((.*?)\)\s*\Z/ ) {
    $args{columns} = $1;
    $args{order} = "$1 desc";
  } elsif ( $args{columns} =~ /\A\s*min\((.*?)\)\s*\Z/ ) {
    $args{columns} = $1;
    $args{order} = "$1";
  } 
  $self->SUPER::fetch_one_value( %args );
}

########################################################################

=head2 sql_limit

Adds support for SQL select limit clause.

TODO: Needs workaround to support offset.

=cut

sub sql_limit {
  my $self = shift;
  my ( $limit, $offset, $sql, @params ) = @_;
  
  # You can't apply "limit" to non-table fetches
  $sql .= " limit $limit" if ( $sql =~ / from / );
  
  return ($sql, @params);
}

########################################################################

=head2 do_insert_with_sequence

  $sqldb->do_insert_with_sequence( $sequence_name, %sql_clauses ) : $row_count

Implemented using DBIx::SQLEngine::Mixin::SeqTable.

=cut

use DBIx::SQLEngine::Mixin::SeqTable ':all';

########################################################################

=head2 detect_any

  $sqldb->detect_any ( )  : $boolean

Returns 1, as we presume that the requisite driver modules are
available or we wouldn't have reached this point.

=head2 sql_detect_table

  $sqldb->sql_detect_table ( $tablename )  : %sql_select_clauses

Implemented using DBD::CSV's "select * from $tablename where 1 = 0".

=cut

sub detect_any {
  return 1;
}

sub sql_detect_table {
  my ($self, $tablename) = @_;
  
  return (
    table => $tablename,
    criteria => '1 = 0',
  )
}

########################################################################

=head2 dbms_create_column_types

  $sqldb->dbms_create_column_types () : %column_type_codes

Implemented using the standard int and varchar types.

=head2 dbms_create_column_text_long_type

  $sqldb->dbms_create_column_text_long_type () : $col_type_str

Implemented using the standard varchar type.

=cut

# Filter out primary key clauses in SQL create statements
sub sql_create_column_type {
  my($self, $table, $column, $columns) = @_;

  return if ( $column->{type} eq 'primary' );
  $self->SUPER::sql_create_column_type( $table, $column, $columns );
}

sub dbms_create_column_types {
  'sequential' => 'int not null',
}

sub dbms_create_column_text_long_type {
  'varchar(1024)'
}

########################################################################

=head1 SEE ALSO

See L<DBIx::SQLEngine> for the overall interface and developer documentation.

See L<DBIx::SQLEngine::Docs::ReadMe> for general information about
this distribution, including installation and license information.

=cut

########################################################################

1;
