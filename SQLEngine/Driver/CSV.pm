=head1 NAME

DBIx::SQLEngine::Driver::CSV - Extends SQLEngine for DBMS Idiosyncrasies

=head1 SYNOPSIS

  my $sqldb = DBIx::SQLEngine->new( 'dbi:CSV:f_dir=my_data_path' );
  
  $hash_ary = $sqldb->fetch_select( 
    table => 'students' 
    limit => 5, offset => 10
  );

=head1 DESCRIPTION

This package provides a subclass of DBIx::SQLEngine which compensates for
some of DBD::CSV's idiosyncrasies.

Note that DBD::CSV does not support the normal full range of SQL DBMS
functionality. Upgrade to the latest versions of DBI and SQL::Statement and
consult their documentation to understand their current limits.

=cut

########################################################################

package DBIx::SQLEngine::Driver::CSV;

use strict;
use Carp;

########################################################################

use DBIx::SQLEngine::Driver::Trait::NoUnions ':all';

use DBIx::SQLEngine::Driver::Trait::NoComplexJoins ':all';

########################################################################

=head2 fetch_one_value

Special handling for simple functions.

=cut

sub fetch_one_value {
  my $self = shift;
  my %args = @_;
  if ( my $column_clause = $args{columns} ) {
    if ( $column_clause =~ /\A\s*max\((.*?)\)\s*\Z/ ) {
      $args{columns} = $1;
      $args{order} = "$1 desc";
    } elsif ( $column_clause =~ /\A\s*min\((.*?)\)\s*\Z/ ) {
      $args{columns} = $1;
      $args{order} = "$1";
    }
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

Implemented using DBIx::SQLEngine::Driver::Trait::NoSequences.

=cut

use DBIx::SQLEngine::Driver::Trait::NoSequences  qw( :all !sql_seq_increment );

# $sql, @params = $sqldb->sql_seq_increment( $table, $field, $current, $next );
sub sql_seq_increment {
  my ($self, $table, $field, $current, $next) = @_;
  my $seq_table = $self->seq_table_name;
  $self->sql_update(
    table => $seq_table,
    values => { seq_value => $next },
    criteria => ['seq_name = ?', "$table.$field"]
  );
}

########################################################################

=head2 detect_any

  $sqldb->detect_any ( )  : $boolean

Returns 1, as we presume that the requisite driver modules are
available or we wouldn't have reached this point.

=head2 sql_detect_any

This should not be called. Throws fatal exception.

=head2 sql_detect_table

  $sqldb->sql_detect_table ( $tablename )  : %sql_select_clauses

Implemented using DBD::CSV's "select * from $tablename where 1 = 0".

=cut

sub detect_any {
  return 1;
}

sub sql_detect_any {
  croak "Unsupported";
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
sub sql_create_columns {
  my($self, $table, $column, $columns) = @_;

  return if ( $column->{type} eq 'primary' );
  $self->SUPER::sql_create_columns( $table, $column, $columns );
}

sub dbms_create_column_types {
  'sequential' => 'int',
}

sub dbms_create_column_text_long_type {
  'varchar(16384)'
}

########################################################################

=head2 dbms_joins_unsupported

  $sqldb->dbms_joins_unsupported () : 1

Capability Limitation: This driver does not support joins.

=head2 dbms_select_table_as_unsupported

  $sqldb->dbms_select_table_as_unsupported () : 1

Capability Limitation: This driver does not support table aliases such as "select * from foo as bar".

=head2 dbms_column_types_unsupported

  $sqldb->dbms_column_types_unsupported () : 1

Capability Limitation: This driver does not store column type information.

=head2 dbms_null_becomes_emptystring

  $sqldb->dbms_null_becomes_emptystring () : 1

Capability Limitation: This driver does not store real null or undefined values, converting them instead to empty strings.

=head2 dbms_indexes_unsupported

  $sqldb-> dbms_indexes_unsupported () : 1

Capability Limitation: This driver does not support indexes.

=head2 dbms_storedprocs_unsupported

  $sqldb-> dbms_storedprocs_unsupported () : 1

Capability Limitation: This driver does not support stored procedures.

=cut

sub dbms_select_table_as_unsupported { 1 }

sub dbms_joins_unsupported           { 1 }
sub dbms_column_types_unsupported    { 1 }
sub dbms_null_becomes_emptystring    { 1 }

use DBIx::SQLEngine::Driver::Trait::NoAdvancedFeatures  qw( :all );

########################################################################

=head1 SEE ALSO

See L<DBIx::SQLEngine> for the overall interface and developer documentation.

See L<DBIx::SQLEngine::Docs::ReadMe> for general information about
this distribution, including installation and license information.

=cut

########################################################################

1;
