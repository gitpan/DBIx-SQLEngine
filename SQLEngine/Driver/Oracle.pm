=head1 NAME

DBIx::SQLEngine::Driver::Oracle - Extends SQLEngine for DBMS Idiosyncrasies

=head1 SYNOPSIS

  my $sqldb = DBIx::SQLEngine->new( 'dbi:oracle:test' );
  
  $hash_ary = $sqldb->fetch_select( 
    table => 'students' 
    limit => 5, offset => 10
  );

=head1 DESCRIPTION

This package provides a subclass of DBIx::SQLEngine which compensates for Oracle's idiosyncrasies.

=cut

package DBIx::SQLEngine::Driver::Oracle;

use strict;
use Carp;

########################################################################

=head2 sql_limit

Adds support for SQL select limit clause.

=cut

sub sql_limit {
  my $self = shift;
  my ( $limit, $offset, $sql, @params ) = @_;

  # remove tablealiases and group-functions from outer query properties
  my $properties = ($sql =~ /^\s*SELECT\s(.*?)\sFROM\s/i);
  $properties =~ s/[^\s]+\s*as\s*//ig;
  $properties =~ s/\w+\.//g;
  
  $offset ||= 0;
  my $position = ( $offset + $limit );
  
  $sql = "SELECT $properties FROM ( SELECT $properties, ROWNUM AS sqle_position FROM ( $sql ) ) WHERE sqle_position > $offset AND sqle_position <= $position";
  
  return ($sql, @params);
}

########################################################################

=head2 do_insert_with_sequence

  $sqldb->do_insert_with_sequence( $sequence_name, %sql_clauses ) : $row_count

Implemented using _seq_do_insert_preinc and seq_increment.

=head2 seq_increment

  $sqldb->seq_increment( $table, $field ) : $new_value

Increments the sequence, and returns the newly allocated value. 

=cut

# $rows = $self->do_insert_with_sequence( $sequence, %clauses );
sub do_insert_with_sequence { 
  (shift)->_seq_do_insert_preinc( @_ )
}

# $current_id = $sqldb->seq_increment( $table, $field );
sub seq_increment {
  my ($self, $table, $field) = @_;
  $self->fetch_one_value(
    sql => "SELECT $field.NEXTVAL FROM DUAL')"
  );
}

########################################################################

=head2 sql_detect_any

  $sqldb->sql_detect_any : %sql_select_clauses

Implemented using Oracle's "select 1 from dual".

=head2 sql_detect_table

  $sqldb->sql_detect_table ( $tablename )  : %sql_select_clauses

Implemented using Oracle's "select * from $tablename limit 1".

=cut

sub sql_detect_any {
  return ( sql => 'select 1 from dual' )
}

sub sql_detect_table {
  my ($self, $tablename) = @_;
  return (
    table => $tablename,
    criteria => '1 = 0',
    limit => 1,
  )
}

########################################################################

=head2 dbms_create_column_types

  $sqldb->dbms_create_column_types () : %column_type_codes

Implemented using Oracle's blob and number types.

I<Portability:> Note that this capability is currently limited, and 
additional steps need to be taken to manually define sequences in Oracle.

=head2 dbms_create_column_text_long_type

  $sqldb->dbms_create_column_text_long_type () : $col_type_str

Implemented using Oracle's clob type.

=cut

sub dbms_create_column_types {
  # sequences have to be defined extra manually with Oracle :-|
  'sequential' => 'number not null', 
  'binary' => 'blob',
}

sub dbms_create_column_text_long_type {
  'clob'
}

########################################################################

=head2 recoverable_query_exceptions

  $sqldb->recoverable_query_exceptions() : @common_error_messages

Provides a list of error messages which represent common
communication failures or other incidental errors.

=cut

sub recoverable_query_exceptions {
  'ORA-03111',	# ORA-03111 break received on communication channel
  'ORA-03113',	# ORA-03113 end-of-file on communication channel
  'ORA-03114',	# ORA-03114 not connected to ORACLE
}

########################################################################

=head1 SEE ALSO

See L<DBIx::SQLEngine> for the overall interface and developer documentation.

See L<DBIx::SQLEngine::Docs::ReadMe> for general information about
this distribution, including installation and license information.

=cut

########################################################################

1;
