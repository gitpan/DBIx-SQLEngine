=head1 NAME

DBIx::SQLEngine::Schema::Column - Struct for database column info

=head1 SYNOPSIS

  my $col = DBIx::SQLEngine::Schema::Column->new( 
    name=>$colname, type=>$typename   
  );
  
  print $col->name;
  
  if ( $col->type eq 'text' ) {
    print "text, length " . $col->length;
  } else {
    print $col->type;
  }

=head1 DESCRIPTION

DBIx::SQLEngine::Schema::Column objects are very simple structures that hold information about columns in a database table or query result.

They are generally contained in a DBIx::SQLEngine::Schema::ColumnSet.

=cut

package DBIx::SQLEngine::Schema::Column;
use strict;

########################################################################

=head1 REFERENCE

These methods are available for all types of column.

=head2

=over 4

=item new - Template::Hash:new

Constructor

=item type - Template::ClassName:subclass_name

Dynamically reblesses instances into different subclasses of DBIx::SQLEngine::Schema::Column.

=item name - Template::Hash:string

=item required - Template::Hash:boolean

=back

=cut

use Class::MakeMethods::Template::Hash (
  'Template::Hash:new' => 'new',
  'Template::ClassName:subclass_name' => 'type',
  string		=> 'name',
  boolean		=> 'required',
);

sub new_from_hash {
  my $class = shift;
  my %hash = (scalar @_ == 1) ? %{ $_[0] } : @_;
  my $self = DBIx::SQLEngine::Schema::Column->new( type => $hash{type}, );
  foreach my $k ( grep { $_ ne 'type' and $self->can($_) } keys %hash ) {
    $self->$k($hash{$k});
  }
}

########################################################################

=head2 text Attributes  

These methods are only available for columns of type text.

=over 4

=item length - Template::Hash:number

=back

=cut

package DBIx::SQLEngine::Schema::Column::text; 
@DBIx::SQLEngine::Schema::Column::text::ISA = 'DBIx::SQLEngine::Schema::Column';

use Class::MakeMethods::Template::Hash (
  number		=> 'length',
);

########################################################################

=head1 SEE ALSO

See L<DBIx::SQLEngine> for the overall interface and developer documentation.

See L<DBIx::SQLEngine::Docs::ReadMe> for general information about
this distribution, including installation and license information.

=cut

########################################################################

1;
