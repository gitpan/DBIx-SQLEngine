package DBIx::SQLEngine::Mysql;

use strict;
use Carp;

########################################################################

sub sql_detect_any {
  return ( sql => 'select 1' )
}

sub sql_detect_table {
  my ($self, $tablename) = @_;
  return ( sql => "select * from $tablename limit 1" )
  return ( sql => "select * from $tablename where 1 = 0" )
  
  return (
    table => $tablename,
    criteria => '1 = 0',
    limit => 1,
  )
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
    croak "DBIx::SQLEngine::MySQL insert with sequence requires values to be hash-ref"
  }
    
  my $rv = $self->do_insert( %args );
  
  $args{values}->{$seq_name} = $self->fetch_one_value( 
    sql => 'select LAST_INSERT_ID()'
  );
  
  $rv;
}

########################################################################

sub sql_create_columns {
  my($self, $table, $column , $columns) = @_;
  my $name = $column->{name};
  my $type = $column->{type};
  if ( $type eq 'sequential' ) {
    return '  ' . $name . 
	    ' ' x ( ( length($name) > 31 ) ? ' ' : ( 32 - length($name) ) ) .
	    'auto_increment';
  } elsif ( $type eq 'binary' ) {
    return '  ' . $name . 
	    ' ' x ( ( length($name) > 31 ) ? ' ' : ( 32 - length($name) ) ) .
	    'blob';
  } else {
    $self->SUPER::sql_create_columns( $table, $column , $columns );
  }
}

########################################################################

sub catch_query_exception {
  my $self = shift;
  my $error = shift;
  if ( $error =~ /Lost connection to MySQL server/ ) {
      $self->reconnect() and return 'REDO';
  } elsif ( $error =~ /MySQL server has gone away/ ) {
      $self->reconnect() and return 'REDO';
  } else {
    $self->SUPER::catch_query_exception( $error, @_ );
  }
}

########################################################################

1;
