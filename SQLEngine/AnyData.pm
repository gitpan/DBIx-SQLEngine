package DBIx::SQLEngine::AnyData;

use strict;
use Carp;

sub fetch_detect_any {
  (shift)->fetch_one_value(sql => 'select 1')
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
  if ( $error =~ /resource/ ) {
      $self->reconnect() and return 'REDO';
  } else {
    $self->SUPER::catch_query_exception( $error, @_ );
  }
}

sub sql_create_column_text_long_type {
  'varchar'
}

########################################################################

# $ds->ad_catalog('TableName', 'AnyDataFormat', 'FileName');
sub ad_catalog { 
  (shift)->func( @_, 'ad_catalog' );
}

1;
