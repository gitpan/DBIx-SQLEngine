package DBIx::SQLEngine::Driver::NullP;

# $sth = $self->prepare_execute($sql);
# $sth = $self->prepare_execute($sql, @params);
sub prepare_execute {
  my ($self, $sql, @params) = @_;
  
  my $sth;
  $sth = $self->prepare_cached($sql);
  $self->{_last_sth_params} = [];
  for my $param_no ( 0 .. $#params ) {
    my $param_v = $params[$param_no];
    my @param_v = ( ref($param_v) eq 'ARRAY' ) ? @$param_v : $param_v;
    # $sth->bind_param( $param_no+1, @param_v );
    $self->{_last_sth_params}[ $param_no ] = $param_v;
  }
  $self->{_last_sth_execute} = $sth->execute();
  $self->{_last_sth_statement} = $sth->{Statement};
  
  return $sth;
}

1;
