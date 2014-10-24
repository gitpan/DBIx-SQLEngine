=head1 NAME

DBIx::SQLEngine::Driver::Trait::NoColumnTypes - For Type-less Databases

=head1 SYNOPSIS

  # Classes can import this behavior if they don't have types
  use DBIx::SQLEngine::Driver::Trait::NoColumnTypes ':all';

=head1 DESCRIPTION

This package supports SQL database servers which do natively provide any column types, storing all numeric and string values in the same way. 

Note: this feature has been added recently, and the interface is subject to change.

Note: Because of the way DBIx::AnyDBD munges the inheritance tree,
DBIx::SQLEngine subclasses can not reliably inherit from this package. To work
around this, we export all of the methods into their namespace using Exporter
and @EXPORT.

=cut

########################################################################

package DBIx::SQLEngine::Driver::Trait::NoColumnTypes;

use Exporter;
sub import { goto &Exporter::import } 
@EXPORT_OK = qw( 
  dbms_column_types_unsupported
);
%EXPORT_TAGS = ( all => \@EXPORT_OK );

use strict;
use Carp;

########################################################################

=head1 ADVANCED CAPABILITIES

=cut

########################################################################

=head2 Database Capability Information

The following methods are provided:

=over 4

=item dbms_column_types_unsupported

  $sqldb->dbms_column_types_unsupported () : 1

Capability Limitation: This driver does not store column type information or enforce type restrictions.

=back

=cut

sub dbms_column_types_unsupported { 1 }

########################################################################

=head1 SEE ALSO

See L<DBIx::SQLEngine> for the overall interface and developer documentation.

See L<DBIx::SQLEngine::Docs::ReadMe> for general information about
this distribution, including installation and license information.

=cut

########################################################################

1;

