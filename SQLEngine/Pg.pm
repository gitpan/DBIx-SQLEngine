package DBIx::SQLEngine::Pg;

use strict;
use Carp;

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
    croak "DBIx::SQLEngine::Pg insert with sequence requires values to be hash-ref"
  }
  
  $args{values}->{$seq_name} = $self->fetch_one_value( 
    sql => "SELECT nextval('$args{table}_${seq_name}_seq')"
  );
  
  $self->do_insert( %args );
}

########################################################################

sub sql_create_columns {
  my($self, $table, $column , $columns) = @_;
  my $name = $column->{name};
  my $type = $column->{type};
  if ( $type eq 'sequential' ) {
    return '  ' . $name . 
	    ' ' x ( ( length($name) > 31 ) ? ' ' : ( 32 - length($name) ) ) .
	    'serial';
  } else {
    $self->SUPER::sql_create_columns( $table, $column , $columns );
  }
}

sub sql_create_column_text_long_type { 'text' }

########################################################################

1;
