package DBIx::SQLEngine::SQLite;

use strict;
use Carp;

########################################################################

sub detect_any {
  return 1;
}

sub sql_detect_any {
  return ( sql => 'select 1' )
}

sub sql_detect_table {
  my ($self, $tablename) = @_;
  return ( sql => "select * from $tablename limit 1" );
}

sub sql_create_column_type {
  my($self, $table, $column, $columns) = @_;
  my $type = $column->{type};
  if ( $type eq 'sequential' ) {
    return 'int auto_increment primary key';
  } elsif ( $type eq 'binary' ) {
    return 'blob';
  } else {
    $self->SUPER::sql_create_columns( $table, $column, $columns );
  }
}

sub sql_create_column_text_long_type {
  'blob'
}

########################################################################

sub fetch_one_row {
  my $self = shift;
  my $rows = $self->fetch_select( limit => 1, @_ ) or return;
  $rows->[0];
}

sub sql_select {
  my $self = shift;
  my %args = @_;
  
  my $limit;
  unless ( $limit = $args{limit} ) {
    return $self->SUPER::sql_select( %args );
  }
  
  delete $args{limit};
  my ($sql, @params) = $self->SUPER::sql_select( %args );
  
  # You can't apply "limit" to non-table fetches like "select LAST_INSERT_ID"
  $sql .= " limit $limit" if ( $sql =~ /\bfrom\b/ );
  
  return ($sql, @params);
}

########################################################################

# $rows = $self->do_insert( %clauses );
sub do_insert {
  my $self = shift;
  my %args = @_;
  
  my $seq_name = $args{sequence};
  unless ( $seq_name ) {
    return $self->SUPER::do_insert( %args );
  }
  delete $args{sequence};    
  $self->do_insert_with_sequence( $seq_name, %args );
}

# $rows = $self->do_insert_with_sequence( $sequence, %clauses );
sub do_insert_with_sequence {
  my $self = shift;
  my $seq_name = shift;
  my %args = @_;
  
  unless ( UNIVERSAL::isa($args{values}, 'HASH') ) {
    croak "DBIx::SQLEngine::SQLite insert with sequence requires values to be hash-ref"
  }
  
  my $rv = $self->do_insert( %args );
  
  $args{values}->{$seq_name} = $self->get_dbh->func('last_insert_rowid');
  
  $rv;
}

########################################################################

sub x_catch_query_exception {
  my $self = shift;
  my $error = shift;
  if ( $error =~ /\Q{TYPE}: unrecognised attribute\E/i ) {
      # This means the query failed; we'll return nothing.
      return 'OK';
  } elsif ( 0 and $error =~ / /i or $error =~ / /i ) {
      $self->reconnect() and return 'REDO';
  } else {
    $self->SUPER::catch_query_exception( $error, @_ );
  }
}

########################################################################

1;
