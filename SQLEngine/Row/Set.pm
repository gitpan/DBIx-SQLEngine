=head1 NAME

DBIx::SQLEngine::Row::Set - Class for arrays of rows

=head1 SYNOPSIS

  $sqldb = DBIx::SQLEngine->new( ... );
  
  $row_class = $sqldb->row_class( $table_name );
  
  $row_set = $row_class->fetch_select( criteria => { status => 2 } );


=head1 DESCRIPTION

This package is not yet complete.

=cut

########################################################################

package DBIx::SQLEngine::Row::Set;
use strict;

use Carp;

use DBIx::SQLEngine::Row::Base;

########################################################################

=head1 SEE ALSO

See L<DBIx::SQLEngine> for the overall interface and developer documentation.

See L<DBIx::SQLEngine::Docs::ReadMe> for general information about
this distribution, including installation and license information.

=cut

########################################################################

1;
