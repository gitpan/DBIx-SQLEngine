package DBIx::SQLEngine::File;

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
  
  return (
    table => $tablename,
    criteria => '1 = 0',
    limit => 1,
  )
}

########################################################################

# Filter out primary key clauses in SQL create statements
sub sql_create_columns {
  my($self, $table, $column, $columns) = @_;

  return if ( $column->{type} eq 'primary' );
  $self->SUPER::sql_create_columns( $table, $column, $columns );
}

sub sql_create_column_type {
  my($self, $table, $column, $columns) = @_;
  my $type = $column->{type};
  if ( $type eq 'sequential' ) {
    return 'int primary key';
  } elsif ( $type eq 'binary' ) {
    return $self->sql_create_column_text_long_type;
  } else {
    $self->SUPER::sql_create_columns( $table, $column, $columns );
  }
}

sub sql_create_column_text_long_type {
  'varchar(1024)'
}

########################################################################

sub fetch_one_row {
  my $self = shift;
  my $rows = $self->fetch_select( limit => 1, @_ ) or return;
  $rows->[0];
}

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

sub sql_select {
  my $self = shift;
  my %args = @_;
  
  my $limit;
  unless ( $limit = $args{limit} ) {
    return $self->SUPER::sql_select( %args );
  }
  
  delete $args{limit};
  my ($sql, @params) = $self->SUPER::sql_select( %args );
  
  # You can't apply "limit" to non-table fetches
  $sql .= " limit $limit" if ( $sql =~ / from / );
  
  return ($sql, @params);
}

########################################################################

use DBIx::SQLEngine::Mixin::SeqTable;

# $rows = $self->do_insert( %clauses );
sub do_insert {
  my $self = shift;
  my %args = @_;
  
  if ( my $seq_name = $args{sequence} ) {
    delete $args{sequence};    
    $self->do_insert_with_sequence( $seq_name, %args );
  } else {
    $self->SUPER::do_insert( %args );
  }
}

# $rows = $self->do_insert_with_sequence( $sequence, %clauses );
sub do_insert_with_sequence {
  my $self = shift;
  my $seq_name = shift;
  my %args = @_;
  
  push @DBIx::SQLEngine::File::ISA, 'DBIx::SQLEngine::Mixin::SeqTable'
    unless ( grep $_ eq 'DBIx::SQLEngine::Mixin::SeqTable', @DBIx::SQLEngine::File::ISA );

  # $self->SQLLogging(1);

  unless ( UNIVERSAL::isa($args{values}, 'HASH') ) {
    croak "DBIx::SQLEngine::File insert with sequence requires values to be hash-ref"
  }
  
  $args{values}->{$seq_name} = $self->seq_increment($args{table}, $seq_name);
  
  $self->do_insert( %args );
}

########################################################################

1;
