=head1 NAME

DBIx::SQLEngine::Driver::AnyData - Support DBD::AnyData driver

=head1 SYNOPSIS

B<DBI Wrapper>: Adds methods to a DBI database handle.

  my $sqldb = DBIx::SQLEngine->new( 'dbi:AnyData:test' );
  
B<Portability Subclasses:> Uses driver's idioms or emulation.
  
  $hash_ary = $sqldb->fetch_select( 
    table => 'students' 
    limit => 5, offset => 10
  );

=head1 DESCRIPTION

This package provides a subclass of DBIx::SQLEngine which compensates for DBD::AnyData's idiosyncrasies.

=head2 About Driver Subclasses

You do not need to use this package directly; when you connect to a database, the SQLEngine object is automatically re-blessed in to the appropriate subclass.

=cut

########################################################################

package DBIx::SQLEngine::Driver::AnyData;

use strict;
use Carp;

########################################################################

use DBIx::SQLEngine::Driver::Trait::NoUnions ':all';

########################################################################

=head2 fetch_one_value

Special handling for simple functions.

=cut

sub fetch_one_value {
  my $self = shift;
  my %args = @_;
  if ( my $column_clause = $args{columns} ) {
    if ( $column_clause =~ /\A\s*count\((.*?)\)\s*\Z/ ) {
      $args{columns} = $1;
      my $rows = $self->fetch_select( %args );
      return( $rows ? scalar( @$rows ) : 0 )
    } elsif ( $column_clause =~ /\A\s*max\((.*?)\)\s*\Z/ ) {
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

use DBIx::SQLEngine::Driver::Trait::NoSequences ':all';

########################################################################

=head2 detect_any

  $sqldb->detect_any ( )  : $boolean

Returns 1, as we presume that the requisite driver modules are
available or we wouldn't have reached this point.

=head2 sql_detect_table

  $sqldb->sql_detect_table ( $tablename )  : %sql_select_clauses

Implemented using AnyData's "select * from $tablename limit 1".

=cut

sub detect_any { 
  return 1
}

sub sql_detect_table {
  my ($self, $tablename) = @_;
  return ( table => $tablename, limit => 1 )
}

########################################################################

=head2 dbms_create_column_types

  $sqldb->dbms_create_column_types () : %column_type_codes

Implemented using AnyData's varchar and int types.

=head2 dbms_create_column_text_long_type

  $sqldb->dbms_create_column_text_long_type () : $col_type_str

Implemented as varchar(16384).

=cut

sub dbms_create_column_types {
  'sequential' => 'int',
}

sub dbms_create_column_text_long_type {
  'varchar(16384)'
}

# Filter out primary keys
sub sql_create_columns {
  my($self, $table, $column , $columns) = @_;
  return if ( $column->{type} eq 'primary' );
  $self->SUPER::sql_create_columns( $table, $column , $columns );
}

########################################################################

=head2 ad_catalog

  $ds->ad_catalog( $table_name, $any_data_format, $file_name );

Uses AnyData's 'ad_catalog' function to map in a new data file.

=cut

# $ds->ad_catalog('TableName', 'AnyDataFormat', 'FileName');
sub ad_catalog { 
  (shift)->func( @_, 'ad_catalog' );
}

########################################################################

=head2 recoverable_query_exceptions

  $sqldb->recoverable_query_exceptions() : @common_error_messages

Provides a list of error messages which represent common
communication failures or other incidental errors.

=cut

sub recoverable_query_exceptions {
  'resource',
}

########################################################################

=head2 dbms_select_table_as_unsupported

  $sqldb->dbms_select_table_as_unsupported () : 1

Capability Limitation: This driver does not support table aliases such as "select * from foo as bar".

=head2 dbms_column_types_unsupported

  $sqldb->dbms_column_types_unsupported () : 1

Capability Limitation: This driver does not store column type information.

=head2 dbms_indexes_unsupported

  $sqldb->dbms_indexes_unsupported () : 1

Capability Limitation: This driver does not support indexes.

=head2 dbms_storedprocs_unsupported

  $sqldb->dbms_storedprocs_unsupported () : 1

Capability Limitation: This driver does not support stored procedures.

=cut

use DBIx::SQLEngine::Driver::Trait::NoAdvancedFeatures  qw( :all );

use DBIx::SQLEngine::Driver::Trait::NoColumnTypes ':all';

sub dbms_select_table_as_unsupported { 1 }

########################################################################

=head1 SEE ALSO

See L<DBIx::SQLEngine> for the overall interface and developer documentation.

See L<DBIx::SQLEngine::Docs::ReadMe> for general information about
this distribution, including installation and license information.

=cut

########################################################################

1;
