package DBIx::SQLEngine::MSSQL;

########################################################################

sub prepare_execute {
  my $sth = (shift)->SUPER::prepare_execute( @_ );
  $sth->{LongReadLen} = 10000000;
  $sth->{LongTruncOk} = 0;
  $sth;
}

########################################################################

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
    die "DBIx::SQLEngine::MySQL insert with sequence requires values to be hash-ref"
  }
  unless ( %{$args{values}}->{$seq_name} ) {
    @{$args{columns}} = grep { $_ ne $seq_name } @{$args{columns}};
  }
  my $rv = $self->do_insert( %args,  );


  $args{values}->{$seq_name} = $self->fetch_one_value( 
    sql => 'select @@IDENTITY AS lastID'
  );
 
  $rv;
}

########################################################################

sub catch_query_exception {
  my $self = shift;
  my $error = shift;
  if ( 
    $error =~ /Communication link failure/i 
    or $error =~ /General network error/i
  ) {
      $self->reconnect() and return 'REDO';
  } else {
    $self->SUPER::catch_query_exception( $error, @_ );
  }
}

########################################################################

1;
