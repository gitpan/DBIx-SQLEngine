package DBIx::SQLEngine::Driver::NullP;

use strict;
use Carp;

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

sub last_query {
  my $self = shift;
  join('/', $self->{_last_sth_statement}, @{ $self->{_last_sth_params} } )
}

1;

__END__

########################################################################

=head1 NAME

DBIx::SQLEngine::Driver::NullP - Extends SQLEngine for Simple Testing

=head1 SYNOPSIS

  my $sqldb = DBIx::SQLEngine->new( 'dbi:NullP:' );
  
  $sqldb->fetch_select( 
    table => 'students' 
  );
  
  ok( $sqldb->last_query, 'select * from students' );

=head1 DESCRIPTION

This package provides a subclass of DBIx::SQLEngine which works with the DBI's DBD::NullP to provide a simple testing capability. See the "t/null.t" test script for a usage example.

Queries using the NullP driver and subclass never return any data, but do keep track of the SQL statements that are executed against them, allowing a simple way of checking whether the SQL generation code is working as expected.

=head2 Testing Interface

=over 4

=item last_query()

Testing interface. Returns the most recent query and parameters captured by prepare_execute().

=back

=head2 Internal Methods

=over 4

=item prepare_execute()

Internal method. Captures the query and parameters that would have been sent to the database.

=back


=head1 SEE ALSO

See L<DBIx::SQLEngine> for the overall interface and developer documentation.

See L<DBIx::SQLEngine::Docs::ReadMe> for general information about
this distribution, including installation and license information.

=cut

########################################################################
