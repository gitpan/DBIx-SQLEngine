=head1 NAME

DBIx::SQLEngine::Schema::Table - A table in a datasource

=head1 SYNOPSIS

  my $sqldb = DBIx::SQLEngine->new( ... );
  
  my $table = DBIx::SQLEngine::Schema::Table->new( name => 'foo', datasource => $ds );
  
  my $row = $table->fetch_id(1);
  my $row_ary = $table->fetch_select( criteria => { status => 2 } );

=head1 DESCRIPTION

The DBIx::SQLEngine::Schema::Table class represents database tables accessible via DBIx::SQLEngine.

A B<table> acts as an interface to a particular set of data, uniquely identfied by the B<datasource> that it connects to and the b<name> of the table.

It facilitates generation of SQL queries that operate on the named table.

Each table can retrieve and cache a ColumnSet containing information about the name and type of the columns in the table. Column information is loaded from the storage as needed, but if you are creating a new table you must provide the definition.

=cut

package DBIx::SQLEngine::Schema::Table;
use strict;

use Carp;
use Class::MakeMethods;
use DBIx::SQLEngine;

########################################################################

=head1 REFERENCE

=cut

########################################################################

=head2 Constructor


=over 4

=item new

You are expected to provde the name and datasource arguments. (Standard::Hash:new)

=back

=cut

use Class::MakeMethods ( 'Standard::Hash:new' => 'new' );

########################################################################

=head2 Name

Required. Identifies this table in the DataSource. 

=over 4

=item name

  $table->name($string)
  $table->name() : $string

Set and get the table name. (Template::Hash:string)

=back

=cut

use Class::MakeMethods ( 'Template::Hash:string' => 'name' );

########################################################################

=head2 DataSource

Required. The DataSource provides the DBI connection and SQL execution capabilities required to talk to the remote data storage.

=over 4

=item datasource

Refers to our current DBIx::SQLEngine. (Standard::Hash:object)

=back

=cut

use Class::MakeMethods (
  'Standard::Hash:object' => { name=>'datasource', class=>'DBIx::SQLEngine::Default' },
  'Standard::Universal:delegate'=>[ 
    [ qw( do_update do_insert do_delete ) ] 
	=> { target=>'datasource'} 
  ],
);

########################################################################

=head2 Selecting Rows

=over 4

=item fetch_select

  $table->fetch_select ( %select_clauses ) : $row_hash_array

Return rows from the table that match the provided criteria, and in the requested order, by executing a SQL select statement.

=item fetch_id

  $table->fetch_id ( $PRIMARY_KEY ) : $row

Fetch the row with the specified ID. 

=item visit_select

  $table->visit_select ( $sub_ref, %select_clauses ) : @results

Calls the provided subroutine on each matching row as it is retrieved. Returns the accumulated results of each subroutine call (in list context).

=back

=cut

# $rows = $self->fetch_select( %select_clauses );
sub fetch_select {
  my $self = shift;
  my $datasource = $self->datasource() or croak("No datasource set for $self");
  $datasource->fetch_select( table => $self->name, @_ )
}

# $rows = $self->visit_select( $sub, %select_clauses );
sub visit_select {
  my $self = shift;
  my $sub = shift;
  
  my $datasource = $self->datasource() or croak("No datasource set for $self");
  $datasource->visit_select( $sub, table => $self->name, @_ )
}

# $rows = $self-> fetch_one_value( %select_clauses );
sub fetch_one_value {
  my $self = shift;
  my $datasource = $self->datasource() or croak("No datasource set for $self");
  $datasource->fetch_select( table => $self->name, @_ )
}

# $row = $self->fetch_id($id);
  # Retrieve a specific row by id
sub fetch_id {
  my ($self, $id) = @_;
  my $datasource = $self->datasource() or croak("No datasource set for $self");
  $datasource->fetch_one_row( 
    table => $self->name, 
    columns => '*', 
    criteria => { $self->column_primary_name => $id }
  );
}

########################################################################

=head2 Inserting Rows

=over 4

=item insert_row

  $table->insert_row ( $row_hash ) : ()

Adds the provided row by executing a SQL insert statement.

=item insert_rows

  $table->insert_rows ( $row_hash_ary ) : ()

Insert each of the rows from the provided array into the table.

=back

=cut

# $self->insert_row( $row );
sub insert_row {
  my ($self, $row) = @_;
  
  my $primary = $self->column_primary_name;
  my @colnames = grep { $_ eq $primary or defined $row->{$_} } $self->column_names;
  
  $self->do_insert( 
    table => $self->name,
    ( $self->column_primary_is_sequence ? ( sequence => $primary ) : () ),
    columns => \@colnames,
    values => $row,
  );
}

# $self->insert_rows( $rows_arrayref );
sub insert_rows {
  my ($self, $rows) = @_;
  foreach ( @$rows ) { $self->insert_row( $_ ); }
}

########################################################################

=head2 Updating Rows

=over 4

=item update_row

  $table->update_row ( $row_hash ) : ()

Update this existing row based on its primary key.

=item update_where

  $table->update_where ( CRITERIA, $changes_hash ) : ()

Make changes as indicated in changes hash to all rows that meet criteria

=back

=cut

# $self->do_update( %clauses);
sub do_update {
  my $self = shift;
  my $datasource = $self->datasource() or croak("No datasource set for $self");
  $datasource->do_update( table => $self->name, @_ )
}

# $self->update_row( $row );
sub update_row {
  my($self, $row) = @_;
  
  $self->do_update( 
    columns => [ $self->column_names ],
    criteria => $self->primary_criteria( $row )
    values => $row,
  );
}

# $self->update_where( $criteria, $change_hash );
sub update_where {
  my($self, $criteria, $changes) = @_;
  
  $self->do_update( 
    criteria => $criteria,
    values => $changes,
  );
}

sub primary_criteria {
  my($self, $row) = @_;
  my $primary_col = $self->column_primary_name;
  my $primary_value = ( ref $row ) ? $row->{$primary_col} : $row;
  { $primary_col => $primary_value },
}

########################################################################

=head2 Deleting Rows

=over 4

=item delete_all

  $table->delete_all () : ()

Delete all of the rows from table.

=item delete_where

  $table->delete_where ( $criteria ) : ()

=item delete_row

  $table->delete_row ( $row_hash ) : ()

Deletes the provided row from the table.

=item delete_id

  $table->delete_id ( $PRIMARY_KEY ) : ()

Deletes the row with the provided ID.

=back

=cut

# $self->do_delete( %clauses);
sub do_delete {
  my $self = shift;
  my $datasource = $self->datasource() or croak("No datasource set for $self");
  $datasource->do_delete( table => $self->name, @_ )
}

# $self->delete_all;
sub delete_all { 
  my $self = shift;  
  $self->do_delete();
}

# $self->delete_where( $criteria );
sub delete_where { 
  my $self = shift;
  
  $self->do_delete( 
    criteria => shift 
  );
}

# $self->delete_row( $row );
sub delete_row { 
  my($self, $row) = @_;
  
  $self->do_delete( 
    criteria => $self->primary_criteria( $row )
  );
}

# $self->delete_id( $id );
sub delete_id {
  my($self, $id) = @_;
  
  $self->do_delete( 
    criteria => $self->primary_criteria( $id )
  );
}

########################################################################

=head2 Agregate functions

=over 4

=item count_rows

  $table->count_rows ( CRITERIA ) : $number

Return the number of rows in the table. If called with criteria, returns the number of matching rows. 

=item fetch_max

  $table->count_rows ( $colname, CRITERIA ) : $number

Returns the largest value in the named column. 

=back

=cut

# $rowcount = $self->count_rows
# $rowcount = $self->count_rows( $criteria );
sub count_rows {
  my $self = shift;
  my $criteria = shift;
  
  $self->fetch_one_value( 
    columns => 'count(*)', 
    criteria => $criteria,
  );
}

sub try_count_rows {
  my $table = shift;
  my $count; 
  eval { 
    $count = $table->count_rows 
  };
  return ( wantarray ? ( $count, $@ ) : $count );
}

# $max_value = $self->fetch_max( $colname, $criteria );
sub fetch_max {
  my $self = shift;
  my $colname = shift;
  my $criteria = shift;
  
  $self->fetch_one_value( 
    columns => "max($colname)", 
    criteria => $criteria,
  );
}

########################################################################

=head2 Storage And Source Management

=over 4

=item detect_datasource

  $table->detect_datasource : $flag

Detects whether the SQL database is avaialable by attempting to connect.


=item table_exists

  $table->table_exists : $flag

Checks to see if the table exists in the SQL database by attempting to retrieve its columns.


=back

=cut

# $flag = $table->detect_datasource;
sub detect_datasource {
  my $self = shift;
  my $datasource = $self->datasource() or croak("No datasource set for $self");
  $datasource->detect_any;
}

# $flag = $table->table_exists;
sub table_exists {
  my $self = shift;
  my $datasource = $self->datasource() or croak("No datasource set for $self");
  $datasource->detect_table( $self->name ) ? 1 : 0;
}

########################################################################

=head2 ColumnSet

=over 4

=item columnset

  $table->columnset () : $columnset

Returns the current columnset, if any.

=item get_columnset

  $table->get_columnset () : $columnset

Returns the current columnset, or runs a trivial query to detect the columns in the DataSource. If the table doesn't exist, the columnset will be empty.

=item columns

  $table->columns () : @columns

Return the column objects from the current columnset.

=item column_names

  $table->column_names () : @column_names

Return the names of the columns, in order.

=item column_named

  $table->column_named ( $name ) : $column

Return the column info object for the specicifcally named column.

=back

=cut

use Class::MakeMethods (
  'Standard::Hash:object' => { name=>'columnset', class=>'DBIx::SQLEngine::Schema::ColumnSet' },
  'Standard::Universal:delegate' => [
    [ qw( columns column_names column_named column_primary ) ] => { target=>'get_columnset' },
  ],
);

use Class::MakeMethods (
  'Standard::Inheritable:scalar' => { name=>'column_primary_name',  },
  'Standard::Inheritable:scalar' => { name=>'column_primary_is_sequence',  },
);

(__PACKAGE__)->column_primary_name( 'id' );
(__PACKAGE__)->column_primary_is_sequence( 1 );

# Qyestion: should we croak if we've got a multiple-column primary key?

sub get_columnset {
  my $self = shift;
  
  if ( my $columns = $self->columnset ) { return $columns }
  
  my @columns = $self->datasource->detect_table( $self->name );
  unless ( scalar @columns ) { 
    confess("Couldn't fetch column information for table $self->{name}");
  }
  $self->columnset( DBIx::SQLEngine::Schema::ColumnSet->new( @columns ) );
}

########################################################################

=head2 DDL

=over 4

=item table_create

  $table->table_create () 
  $table->table_create ( $column_ary ) 

=item table_drop

  $table->table_drop () 

=item table_ensure_exists

  $table->table_ensure_exists ( $column_ary )

Create the table's remote storage if it does not already exist.

=item table_recreate

  $table->table_recreate ()

Remove and then recreate the table's remote storage.

=back

=cut

# $self->table_create();
sub table_create {
  my $self = shift;
  my $columnset = shift || $self->columnset;
  $self->datasource->do_create_table( $self->name, $columnset->as_hashes ) ;
}

# $sql_stmt = $table->table_drop();
sub table_drop {
  my $self = shift;
  $self->datasource->do_drop_table( $self->name ) ;
}

# $table->table_ensure_exists( $column_ary )
  # Create the remote data source for a table if it does not already exist
sub table_ensure_exists {
  my $self = shift;
  $self->table_create(@_) unless $self->table_exists;
}

# $table->table_recreate
# $table->table_recreate( $column_ary )
  # Delete the source, then create it again
sub table_recreate { 
  my $self = shift;
  my $column_ary = shift || $self->columns;
  $self->table_drop if ( $self->table_exists );
  $self->table_create( $column_ary );
}

# $package->table_recreate_with_rows;
# $package->table_recreate_with_rows( $column_ary );
sub table_recreate_with_rows {
  my $self = shift;
  my $column_ary = shift || $self->columns;
  my $rows = $self->fetch_select();
  $self->table_drop;
  $self->table_create( $column_ary );
  $self->insert_rows( $rows );
}

########################################################################

=head1 SEE ALSO

See L<DBIx::SQLEngine> for the overall interface and developer documentation.

See L<DBIx::SQLEngine::Docs::ReadMe> for general information about
this distribution, including installation and license information.

=cut

########################################################################

1;
