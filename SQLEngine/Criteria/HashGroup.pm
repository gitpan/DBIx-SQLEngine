package DBIx::SQLEngine::Criteria::HashGroup;
use DBIx::SQLEngine::Criteria;
@ISA = 'DBIx::SQLEngine::Criteria';
use strict;

use DBIx::SQLEngine::Criteria::And;
use DBIx::SQLEngine::Criteria::Or;
use DBIx::SQLEngine::Criteria::StringEquality;

use Class::MakeMethods (
  'Template::Hash:new --with_values' => 'new',
);

sub normalized {
  my $hashref = shift;
  
  DBIx::SQLEngine::Criteria::And->new(
    map {
      my $key = $_;
      ( ref( $hashref->{$key} ) eq 'ARRAY' ) 
	? DBIx::SQLEngine::Criteria::Or->new( 
	    map {
	      DBIx::SQLEngine::Criteria::StringEquality->new( $key, defined($_) ? $_ : '' ) 
	    } @{ $hashref->{$key} }
	  )
        : DBIx::SQLEngine::Criteria::StringEquality->new( $key, defined($hashref->{$key}) ? $hashref->{$key} : '' ) 
    } keys %$hashref 
  );
}

sub sql_where {
  (shift)->normalized->sql_where( @_ ) 
}

1;
