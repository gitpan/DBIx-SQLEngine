=head1 NAME

DBIx::SQLEngine::Record::Base - Class for rows in a table

=head1 SYNOPSIS

  $sqldb = DBIx::SQLEngine->new( ... );
  
  $class_name = $sqldb->record_class( $table_name );
  
  $record_set = $class_name->fetch_select( criteria => { status => 2 } );

  $record = $class_name->fetch_record( $primary_key );
  $record->change( somefield => 'New Value' );
  $record->update_record();

  $record = $class_name->new_with_values(somefield => 'New Value');
  $record->insert_record();

  $record->delete_record();


=head1 DESCRIPTION

This package is not yet complete.

DBIx::SQLEngine::Record::Base is a superclass for database records in tables accessible via DBIx::SQLEngine.

By subclassing this package, you can easily create a class whose instances represent each of the rows in a SQL database table.

=cut

########################################################################

package DBIx::SQLEngine::Record::Base;
use strict;

use Carp;

use DBIx::SQLEngine::Schema::Table;

########################################################################

=head1 CLASS INSTANTIATION

=head2 Record Class Creation

=over 4

=item SQLEngine->record_class()

  $sqldb->record_class( $tablename ) : $class_name
  $sqldb->record_class( $tablename, $name ) : $class_name

Convenience function to create a record class with the given table name.

=item Table->record_class()

  $table->record_class( ) : $class_name
  $table->record_class( $name ) : $class_name

Convenience function to create a record class for a given table.

=item new_subclass()

  DBIx::SQLEngine::Record::Base->new_subclass( table=>$table ) : $class_name
  DBIx::SQLEngine::Record::Base->new_subclass( table=>$table, name=>$name ) : $class_name

Subclass constructor. You are expected to provde a DBIx::SQLEngine::Schema::Table object.

If you do not supply a class name, one is generated based on the table name. 

If the class name does not contain a "::" package separator, it is prepended with DBIx::SQLEngine::Record::.

=back

=cut

sub new_subclass {
  my ( $class, %options ) = @_;
  my $table = $options{table} or croak("$class new_subclass requires a table");
  my $name = $options{name} || $class->generate_subclass_name_for_table($table);
  $name = "DBIx::SQLEngine::Record::" . $name unless ( $name =~ /::/ );
  {
    no strict 'refs';
    push @{"$name\::ISA"}, $class;
  }
  $name->table( $table );
  return $name;
}

my %generated_names_for_table;
sub generate_subclass_name_for_table {
  my ($class, $table) = @_;
  my $tname = $table->name;
  my $tsqle = $table->sqlengine;
  my $t_str = "$tname-$tsqle";

  if ( my $names = $generated_names_for_table{ $tname } ) {
    return $tname if ( $names->{ $tname } eq $t_str );
    my $t_index = $tname . "_1";
    until ( $names->{ $t_index } eq $t_str ) { $t_index ++ }
    return $t_index;
  } else {
    $generated_names_for_table{ $tname } = { $tname => $t_str };
    return $tname;
  }
}

########################################################################

=head2 Table Accessor

=over 4

=item table()

  $class_name->table() : $table
  $class_name->table($table)

Get and set our current DBIx::SQLEngine::Schema::Table. Required value.
Establishes the table a specific class of record will be stored in.  The table
provides the DBI connection and SQL execution capabilities required to talk
to the remote data storage.

=item get_table()

  $table->get_table() : $table or exception

Returns the table, or throws an exception if it is not set.

=back

=cut

use Class::MakeMethods (
  'Template::ClassInherit:object' => [ 
		  table => {class=>'DBIx::SQLEngine::Schema::Table'}
  ],
);

sub get_table {
  ($_[0])->table() or croak("No table set for record class '$_[0]'")
}

########################################################################

=head2 Table Methods

=over 4

=item detect_sqlengine()

  $class_name->detect_sqlengine : $flag

Detects whether the SQL database is avaialable by attempting to connect.

=item table_exists()

  $class_name->table_exists : $flag

Detects whether the table has been created and has not been dropped.

=item columnset()

  $class_name->columnset () : $columnset

Returns the current columnset, if any.

=item fetch_one_value()

  $table->fetch_one_value( %sql_clauses ) : $scalar

Calls fetch_select, then returns the first value from the first row of results.

=item count_rows()

  $class_name->count_rows ( ) : $number
  $class_name->count_rows ( $criteria ) : $number

Return the number of rows in the table. If called with criteria, returns the number of matching rows. 

=back

=cut

use Class::MakeMethods (
  'Standard::Universal:delegate' => [ [ qw( 
	detect_sqlengine table_exists fetch_one_value count_rows columnset column_primary_name 
    ) ] => { target=>'table' },
  ],
);

########################################################################

########################################################################

=head1 RECORD OBJECTS

=head2 Creating Record Objects

=over 4

=item new_empty_record()

  $class_name->new_empty_record() : $empty_record

Creates and blesses an empty hash object into the given record class.

=item new_copy()

  $record->new_copy() : $new_record

Makes a copy of a record and then clears its primary key so that it will be recognized as a distinct, new row in the database rather than overwriting the original when you save it.

=back

=cut

# $record = $record_class->new_empty_record();
# $record = $record->new_empty_record();
sub new_empty_record {
  my $self = shift;
  my $class = ( ref($self) || $self );
  bless {}, $class;
}

# $record = $record->new_copy();
sub new_copy { 
  my $self = shift;
  $self->new_with_values( %$self, $self->column_primary_name() => '', @_ );
}

# $hash_ref = $record_obj->hash_from_record();
# %hash_list = $record_obj->hash_from_record();
sub hash_from_record {
  my $self = shift;
  wantarray ? %$self : { %$self }
}

########################################################################

=head2 Simple Fetch, Change and Save

This interface provides a succinct means of fetching records, making changes to them, and then saving them.

=over 4

=item get_record 

  $class_name->get_record ( ) : $new_empty_record
  $class_name->get_record ( $p_key ) : $fetched_record_or_undef

Calls new if no primary key is provided, or if the primary key is zero; otherwise calls fetch_record.

=item change_values

  $record->change_values( key => value1, ... ); 

Sets the associated key-value pairs in the provided record.

=item save_record

  $record->save_record () : $record_or_undef

Determines whether the record has an primary key assigned to it and then calls either insert_record or update_record. Returns the record unless it fails to save it.

=back

=cut

# $new_record = $package->get_record()
# $selected_record = $package->get_record( $id )
sub get_record {
  my $package = shift;
  my $id = shift;
  if ( ! $id ) {
    $package->new_empty_record();
  } else {
    $package->fetch_record( $id );
  }
}

sub change_values {
  my $self = shift;
  ref($self) or croak("Not a class method");
  %$self = ( %$self, @_ )
}

# $record->save_record()
sub save_record {
  my $self = shift;
  
  my $id = $self->{ $self->column_primary_name() };
  if ( ! $id ) {
    $self->insert_record( @_ );
  } else {
    $self->update_record( @_ );
  }
  $self;
}

########################################################################

=head2 Change and Save Combinations

=over 4

=item new_with_values 

  $class_name->new_with_values ( %key_argument_pairs ) : $record

Calls new_empty_record, and then change_values.

=item change_and_save 

  $record->change_and_save ( %key_argument_pairs ) : $record

Calls change_values, and then save_record.

=item new_and_save 

  $class_name->new_and_save ( %key_argument_pairs ) : $record

Calls new_empty_record, and then change_and_save.

=back

=cut

# $record->change_and_save( 'fieldname' => 'new_value', ... )
sub change_and_save {
  my $self = shift;
  $self->change_values( @_ );
  $self->save_record;
  $self;
}

# $record = $record_class->new_with_values( 'fieldname' => 'new_value', ... )
sub new_with_values {
  my $self = (shift)->new_empty_record();
  $self->change_values( @_ );
  $self;
}

# $record_class->new_and_save( 'fieldname' => 'new_value', ... )
sub new_and_save {
  (shift)->new_with_values( @_ )->save_record();
}

########################################################################

########################################################################

=head1 FETCHING DATA (SQL DQL)

=head2 Select to Retrieve Records

=over 4

=item fetch_select()

  $class_name->fetch_select ( %select_clauses ) : $record_set

Calls the corresponding SQLEngine method with the table name and the provided arguments. Return rows from the table that match the provided criteria, and in the requested order, by executing a SQL select statement. 

Each row hash is blessed into the record class before being wrapped in a Record::Set object.

=item fetch_one_record()

  $sqldb->fetch_one_record( %select_clauses ) : $record_hash

Calls fetch_select, then returns only the first row of results.

The row hash is blessed into the record class before being returned.

=item select_record()

  $class_name->select_record ( $primary_key_value ) : $record_obj
  $class_name->select_record ( \@compound_primary_key ) : $record_obj
  $class_name->select_record ( \%hash_with_primary_key_value ) : $record_obj

Fetches a single record by primary key.

The row hash is blessed into the record class before being returned.

=item select_records()

  $class_name->select_records ( @primary_key_values_or_hashrefs ) : $record_set

Fetches a set of one or more by primary key.

Each row hash is blessed into the record class before being wrapped in a Record::Set object.

=item visit_select()

  $class_name->visit_select ( $sub_ref, %select_clauses ) : @results
  $class_name->visit_select ( %select_clauses, $sub_ref ) : @results

Calls the provided subroutine on each matching record as it is retrieved. Returns the accumulated results of each subroutine call (in list context).

Each row hash is blessed into the record class before being the subroutine is called.

=back

=cut

# $records = $record_class->fetch_select( %select_clauses );
sub fetch_select {
  my $self = shift;
  $self->record_set_from_table( $self->get_table()->fetch_select( @_ ) )
}

# $record = $record_class->fetch_one_record( %clauses );
sub fetch_one_record {
  my $self = shift;
  $self->record_from_table( $self->get_table()->fetch_one_row( @_ ) )
}

# @results = $record_class->visit_select( %select_clauses, $sub );
sub visit_select {
  my $self = shift;
  my $sub = ( ref($_[0]) ? shift : pop );
  $self->get_table()->visit_select(@_, 
				sub { $self->record_from_table($_[0]); &$sub })
}

# $record = $record_class->select_record( $id_value );
# $record = $record_class->select_record( \@compound_id );
# $record = $record_class->select_record( \%hash_with_pk );
sub select_record {
  my $self = shift;
  $self->record_from_table( $self->get_table()->select_row( @_ ) )
}

# $records = $record_class->select_records( @ids_or_hashes );
sub select_records {
  my $self = shift;
  $self->record_set_from_table( $self->get_table()->select_records( @_ ) )
}

########################################################################

=head2 Vivifying Records From The Database

These methods are called internally by the various select methods and do not need to be called directly.

=over 4

=item record_from_table()

  $class_name->record_from_table( $hash_ref )
  $class_name->record_from_table( $hash_ref ) : $record
  $class_name->record_from_table( %hash_contents ) : $record

Converts a hash retrieved from the table to a Record object.

=item record_set_from_table()

  $class_name->record_set_from_table( $hash_array_ref )
  $class_name->record_set_from_table( $hash_array_ref ) : $record_set
  $class_name->record_set_from_table( @hash_refs ) : $record_set

Converts an array of hashrefs retrieved from the table to a Record::Set object containing Record objects.

=back

=cut

# $record_class->record_from_table( $hash_ref );
# $record = $record_class->record_from_table( $hash_ref );
# $record = $record_class->record_from_table( %hash_contents );
sub record_from_table {
  my $self = shift;
  my $class = ( ref($self) || $self );
  my $hash = ( @_ == 1 ) ? shift : { @_ }
	or return;
  confess("from table : '$hash'") unless $hash; 
  bless $hash, $class;
}

# $record_class->record_set_from_table( $hash_array_ref );
# $record_set = $record_class->record_set_from_table( $hash_array_ref );
# $record_set = $record_class->record_set_from_table( @hash_refs );
sub record_set_from_table {
  my $self = shift;
  my $class = ( ref($self) || $self );
  my $array = ( @_ == 1 ) ? shift : [ @_ ];
  bless [ map { bless $_, $class } @$array ], 'DBIx::SQLEngine::Record::Set';
}

########################################################################

########################################################################

=head1 EDITING DATA (SQL DML)

=head2 Insert to Add Records

=over 4

=item insert_record()

  $record_obj->insert_record() : $flag

Adds the values from this record to the table. Returns the number of rows affected, which should be 1 unless there's an error.

=back

=cut

# $record_obj->insert_record();
sub insert_record {
  my $self = shift;
  my $class = ref( $self ) or croak("Not a class method");
  $self->get_table()->insert_row( $self );
}

########################################################################

=head2 Update to Change Records

=over 4

=item update_record()

  $record_obj->update_record() : $record_count

Update this existing record based on its primary key. Returns the number of rows affected, which should be 1 unless there's an error.

=back

=cut

# $record_obj->update_record();
sub update_record {
  my $self = shift;
  my $class = ref( $self ) or croak("Not a class method");
  $self->get_table()->update_row( $self );
}

########################################################################

=head2 Delete to Remove Records

=over 4

=item delete_record()

  $record_obj->delete_record() : $record_count

Delete this existing record based on its primary key. Returns the number of rows affected, which should be 1 unless there's an error.

=back

=cut

# $record_obj->delete_record();
sub delete_record {
  my $self = shift;
  my $class = ref( $self ) or croak("Not a class method");
  $self->get_table()->delete_row( $self );
}

########################################################################

=head1 SEE ALSO

See L<DBIx::SQLEngine> for the overall interface and developer documentation.

See L<DBIx::SQLEngine::Docs::ReadMe> for general information about
this distribution, including installation and license information.

=cut

########################################################################

1;
