package DBIx::SQLEngine::Mysql;

use strict;
use Carp;

# $self->last_insert_id()
sub last_insert_id {
  (shift)->fetch_one_value( 
    sql => 'select LAST_INSERT_ID()'
  );
}

sub fetch_detect_any {
  (shift)->fetch_one_value(sql => 'select 1')
}

sub do_insert {
  my $self = shift;
  my %args = @_;
  
  if ( my $seq_name = $args{sequence} ) {
    ( UNIVERSAL::isa($args{values}, 'HASH') ) 
	  or croak "Mysql sequence insert requires hash-ref for values";
    delete $args{sequence};
    $self->SUPER::do_insert( %args );
    $args{values}->{$seq_name} = $self->last_insert_id();
  } else {
    $self->SUPER::do_insert( %args );
  }
}

sub sql_select {
  my $self = shift;
  my %args = @_;
  if ( my $limit = $args{limit} ) {
    delete $args{limit};
    my ($sql, @params) = $self->SUPER::sql_select( %args );
    $sql .= " limit $limit" if ( $sql =~ /\bfrom\b/ );
    return ($sql, @params);
  } else {
    $self->SUPER::sql_select( %args );
  }
}

sub fetch_detect_table {
  (shift)->fetch_one_row(
    table => (shift),
    criteria => '1 = 0'
  )
}

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


sub sql_create_column_text_long_type {
  'blob'
}

1;
