=head1 NAME

DBIx::SQLEngine::Schema::ColumnSet - Array of Schema::Column objects


=head1 SYNOPSIS

  my $colset = DBIx::SQLEngine::Schema::ColumnSet->new( $column1, $column2 );
  
  print $colset->count;
  
  foreach my $column ( $colset->columns ) {
    print $column->name;
  }
  
  $column = $colset->column_named( $name );


=head1 DESCRIPTION

DBIx::SQLEngine::Schema::ColumnSet objects contain an array of DBIx::SQLEngine::Schema::Column objects

=cut

package DBIx::SQLEngine::Schema::ColumnSet;
use strict;
use Carp;

########################################################################

=head1 REFERENCE

=over 4

=item new()

  DBIx::SQLEngine::Schema::ColumnSet->new( @columns ) : $colset

Basic array constructor.

=item columns()

  $colset->columns () : @columns

Returns a list of column objects. 

=item column_names()

  $colset->column_names () : @column_names

Returns the result of calling name() on each column.

=item column_named()

  $colset->column_named ( $name ) : $column

Finds the column with that name, or dies trying.

=back

=cut

sub new {
  my $package = shift;
  my @cols = map {
    ( ref($_) eq 'HASH' ) ? DBIx::SQLEngine::Schema::Column->new_from_hash(%$_)
			  : $_
  } @_;
  bless \@cols, $package;
}

sub columns {
  my $colset = shift;
  @$colset
}

# @colnames = $colset->column_names;
sub column_names {
  my $colset = shift;
  return map { $_->name } @$colset;
}

# $text_summary = $colset->column_info;
sub column_info {
  my $colset = shift;
  join(', ', map { $_->name() . " (". $_->type() .")" } @$colset)
}

# $column = $colset->column_named( $column_name );
# $column = $colset->column_named( $column_name );
sub column_named {
  my $colset = shift;
  my $column_name = shift;
  foreach ( @$colset ) {
    return $_ if ( $_->name eq $column_name );
  }
  croak(
    "No column named $column_name in $colset->{name} table\n" . 
    "  (Perhaps you meant one of these: " . $colset->column_info . "?)"
  );
}

########################################################################

=head1 SEE ALSO

See L<DBIx::SQLEngine> for the overall interface and developer documentation.

See L<DBIx::SQLEngine::Docs::ReadMe> for general information about
this distribution, including installation and license information.

=cut

########################################################################

1;
