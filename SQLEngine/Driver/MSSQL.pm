=head1 NAME

DBIx::SQLEngine::Driver::MSSQL - Extends SQLEngine for DBMS Idiosyncrasies

=head1 SYNOPSIS

  my $sqldb = DBIx::SQLEngine->new( 'dbi:MSSQL:test' );
  
  $hash_ary = $sqldb->fetch_select( 
    table => 'students' 
    limit => 5, offset => 10
  );

=head1 DESCRIPTION

This package provides a subclass of DBIx::SQLEngine which compensates for Microsoft SQL Server's idiosyncrasies.

=cut

########################################################################

package DBIx::SQLEngine::Driver::MSSQL;

use strict;
use Carp;

########################################################################

=head2 sql_limit

Adds support for SQL select limit clause.

=cut

sub sql_limit {
  my $self = shift;
  my ( $limit, $offset, $sql, @params ) = @_;

  # You can't apply "limit" to non-table fetches like "select LAST_INSERT_ID"
  if ( $sql =~ /\bfrom\b/ and defined $limit or defined $offset) {
    $sql .= " limit $limit" if $limit;
    $sql .= " offset $offset" if $offset;
  }
  
  return ($sql, @params);
}

########################################################################

=head2 do_insert_with_sequence

  $sqldb->do_insert_with_sequence( $sequence_name, %sql_clauses ) : $row_count

Implemented using _seq_do_insert_postfetch and seq_fetch_current.

=head2 seq_fetch_current

  $sqldb->seq_fetch_current( ) : $current_value

Implemented using MSSQL's "select @@IDENTITY". Note that this
doesn't fetch the current sequence value for a given table, since
it doesn't respect the table and field arguments, but merely returns
the last sequencial value created during this session.

=cut

# $rows = $self->do_insert_with_sequence( $sequence, %clauses );
sub do_insert_with_sequence {
  (shift)->_seq_do_insert_postfetch( @_ )
}

# $current_id = $sqldb->seq_fetch_current( );
sub seq_fetch_current {
  my ($self, $table, $field) = @_;
  $self->fetch_one_value( 
    sql => 'select @@IDENTITY AS lastID'
  );
}

########################################################################

=head2 dbms_create_column_types

  $sqldb->dbms_create_column_types () : %column_type_codes

Implemented using MSSQL's blob and int types.

=head2 dbms_create_column_text_long_type

  $sqldb->dbms_create_column_text_long_type () : $col_type_str

Implemented using MSSQL's blob type.

=cut

sub dbms_create_column_types {
  'sequential' => 'int not null', 
  'binary' => 'blob',
}

sub dbms_create_column_text_long_type {
  'blob'
}

########################################################################

=head2 prepare_execute

After the normal prepare_execute cycle, this also sets the sth's LongReadLen to dbms_longreadlen_bufsize().

=head2 dbms_longreadlen_bufsize

Set to 1_000_000.

=cut

sub dbms_longreadlen_bufsize { 1_000_000 }

sub prepare_execute {
  my $self = shift;
  my $sth = $self->SUPER::prepare_execute( @_ );
  $sth->{LongReadLen} = $self->dbms_longreadlen_bufsize;
  $sth->{LongTruncOk} = 0;
  $sth;
}

########################################################################

=head2 recoverable_query_exceptions

  $sqldb->recoverable_query_exceptions() : @common_error_messages

Provides a list of error messages which represent common
communication failures or other incidental errors.

=cut

sub recoverable_query_exceptions {
  'Communication link failure',
  'General network error',
}

########################################################################

=head1 SEE ALSO

See L<DBIx::SQLEngine> for the overall interface and developer documentation.

See L<DBIx::SQLEngine::Docs::ReadMe> for general information about
this distribution, including installation and license information.

=cut

########################################################################

1;
