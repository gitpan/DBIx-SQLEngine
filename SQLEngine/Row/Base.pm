=head1 NAME

DBIx::SQLEngine::Row::Base - Class for rows in a table

=head1 SYNOPSIS

  $sqldb = DBIx::SQLEngine->new( ... );
  
  $row_class = $sqldb->row_class( $table_name );
  
  $row_set = $row_class->fetch_select( criteria => { status => 2 } );
  $row_class->do_update(values => { status => 3 }, criteria => { status => 2 });

  $row = $row_class->get_record(); 
  $row->{somefield} = 'New Value';
  $row->insert_row();

  $row = $row_class->fetch_row( $primary_key );

  $row->{somefield} = 'New Value';
  $row->update_row();

  $row->delete_row();


=head1 DESCRIPTION

This package is not yet complete.

=cut

########################################################################

package DBIx::SQLEngine::Row::Base;
use strict;

use Carp;

use DBIx::SQLEngine::Schema::Table;

########################################################################

=head1 SEE ALSO

See L<DBIx::SQLEngine> for the overall interface and developer documentation.

See L<DBIx::SQLEngine::Docs::ReadMe> for general information about
this distribution, including installation and license information.

=cut

########################################################################

1;
