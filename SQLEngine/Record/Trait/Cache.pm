=head1 NAME

DBIx::SQLEngine::Record::Trait::Cache - Avoid Repeated Selects

=head1 SYNOPSIS

B<Setup:> Several ways to create a class.

  my $sqldb = DBIx::SQLEngine->new( ... );

  $class_name = $sqldb->record_class( $table_name, undef, 'Cache' );
  
  $sqldb->record_class( $table_name, 'My::Record', 'Cache' );
  
  package My::Record;
  use DBIx::SQLEngine::Record::Class '-isasubclass', 'Cache';  
  My::Record->table( $sqldb->table($table_name) );

B<Cache:> Uses Cache::Cache interface.

  $class_name->use_cache_style('simple');

  # requires Cache::FastMemoryCache
  $class_name->use_cache_style('active'); 

  use Cache::Cache;
  $class_name->cache_cache( $my_cache_cache_object );

B<Basics:> Layered over superclass.

  # Fetches from cache if it's been seen before
  $record = $class_name->fetch_record( $primary_key );

  # Fetches from cache if we've run this query before
  @records = $class_name->fetch_select(%clauses)->records;
  
  # Clears cache so it's seen by next select query
  $record->insert_record();
  
  # Clears cache so it's seen by next select query
  $record->update_record();
  
  # Clears cache so it's seen by next select query
  $record->delete_record();


=head1 DESCRIPTION

This package is not yet complete.

This package provides a caching layer for DBIx::SQLEngine::Record objects.

Don't use this module directly; instead, pass its name as a trait when you create a new record class. This package provides a multiply-composable collection of functionality for Record classes. It is combined with the base class and other traits by DBIx::SQLEngine::Record::Class. 

=cut

########################################################################

package DBIx::SQLEngine::Record::Trait::Cache;

use strict;
use Carp;
use vars qw( @MIXIN );

# use Cache::Cache;
use Storable 'freeze';
use String::Escape 'qprintable';

########################################################################

########################################################################

=head1 CACHE INTERFACE

=cut

########################################################################

=head2 Cache Configuration

=over 4

=item cache_cache()

  $record_class->cache_cache() : $cache_cache
  $record_class->cache_cache( $cache_cache ) 

=back

B<Cache Object Requirements:> This package in intended to work with cache object that use the Cache::Cache interface. However, any package which support the limited cache interface used by this package should be sufficient. 

=over 4

=item new()

Constructor.

=item namespace()

Used to differentiate one cache object from another.

=item get()

Fetch a value from the cache, if it is present.

=item set()

Set a value in the cache.

=item clear()

Clear some or all values in the cache.

=back

B<Included Cache Classes:> Two small classes are included that support this interface; see L<DBIx::SQLEngine::Cache::TrivialCache> and  L<DBIx::SQLEngine::Cache::BasicCache>.

=cut

use Class::MakeMethods (
  'Template::ClassInherit:scalar' => 'cache_cache',
);

########################################################################

=head2 Cache Operations

=over 4

=item cache_get()

  $record_class->cache_get( $key ) : $value
  $record_class->cache_get( $key ) : ( $value, $updater_code_ref )

=item cache_set()

  $record_class->cache_set( $key, $value )

=item cache_get_set()

  $record_class->cache_get_set( $key, $code_ref, @args ) : $value

=item cache_clear()

  $record_class->cache_clear()
  $record_class->cache_clear( $key )

=back

=cut

# $value = $self->cache_get( $key );
# ( $value, $update ) = $self->cache_get( $key );
sub cache_get {
  my ( $self, $key ) = @_;
  
  my $cache = $self->cache_cache() or return;
  
  $key = do { local $Storable::canonical = 1; freeze($key) } if ( ref $key );
  my $current = $cache->get( $key );
  
  if ( ! defined $current ) {
    $self->cache_log_operation( $cache, 'miss', $key );
  } else {
    $self->cache_log_operation( $cache, 'hit', $key );
  } 
  
  ! wantarray ? $current : ( $current, sub { 
    $self->cache_log_operation( $cache, 'update', $key );
    $cache->set( $key, @_ );
  } );
}

# $self->cache_set( $key, $value );
sub cache_set {
  my ( $self, $key, @value ) = @_;
  
  my $cache = $self->cache_cache() or return;
  
  $key = do { local $Storable::canonical = 1; freeze($key) } if ( ref $key );
  
  $self->cache_log_operation( $cache, 'write', $key );
  $cache->set( $key, @value );
}

# $value = $self->cache_get_set( $key, \&sub, @args );
sub cache_get_set {
  my ( $self, $key, $sub, @args ) = @_;
  
  my ($current, $update) = $self->cache_get($key);
  
  if ( ! defined $current ) {
    $current = &$sub( @args );
    &$update( defined($current) ? $current : '' );
  }
  
  $current;
}

# $self->cache_clear();
# $self->cache_clear( $key );
sub cache_clear {
  my ( $self, $key ) = @_;
  
  my $cache = $self->cache_cache() or return;

  if ( ! $key ) {
    $self->cache_log_operation( $cache, 'clear' );
    $cache->clear();
  } else {
    $self->cache_log_operation( $cache, 'clear', $key );
    $cache->set($key, undef);
  }
}

########################################################################

=head2 Cache Logging

=over 4

=item CacheLogging()

=item cache_log_operation()

=back

=cut

use Class::MakeMethods (
  'Standard::Inheritable:scalar' => 'CacheLogging',
);

use vars qw( %CachingHistory );

sub cache_log_operation {
  my ( $self, $cache, $oper, $key ) = @_;
  my $level = $self->CacheLogging() or return;
  my $namespace = $cache->get_namespace;
  if ( $level < 2 ) {
    warn "Cache $namespace: $oper " . qprintable($key) . "\n";
  } else {
    my $history = ( $CachingHistory{ $key } ||= [] );
    warn "Cache $namespace: $oper (" . join(' ', @$history ) . ") "  .
				      qprintable($key)."\n";
    push @$history, $oper;
  }
}

########################################################################

=head2 Cache Styles

=over 4

=item define_cache_styles()

  DBIx::SQLEngine->define_cache_styles( $name, $code_ref )
  DBIx::SQLEngine->define_cache_styles( %names_and_code_refs )

Define a named caching style.

=item cache_styles()

  DBIx::SQLEngine->cache_styles() : %names_and_info
  DBIx::SQLEngine->cache_styles( $name ) : $info
  DBIx::SQLEngine->cache_styles( \@names ) : @info
  DBIx::SQLEngine->cache_styles( $name, $info, ... )
  DBIx::SQLEngine->cache_styles( \%names_and_info )

Accessor for global hash mapping cache names to initialization subroutines.

=item use_cache_style()

  $class_name->use_cache_style( $cache_style_name )

=back

=cut

use Class::MakeMethods (
  'Standard::Global:hash' => 'cache_styles',
);

sub define_cache_styles {
  my $self = shift;
  $self->cache_styles( @_ );
}

sub use_cache_style {
  my ( $class, $style, %options ) = @_;
  my $sub = $class->cache_styles( $style );
  my $cache = $sub->( $class, %options );
  $class->cache_cache( $cache );
}

########################################################################

=pod

B<Defaults:> The following cache styles are predefined. Except for 'simple', using any of these styles will require installation of the Cache::Cache distribution.

=over 4

=item 'simple'

Uses DBIx::SQLEngine::Cache::TrivialCache.

=item 'live'

Uses Cache::FastMemoryCache with a default expiration time of 1 seconds.

=item 'active'

Uses Cache::FastMemoryCache with a default expiration time of 5 seconds.

=item 'stable'

Uses Cache::FastMemoryCache with a default expiration time of 30 seconds.

=item 'file'

Uses Cache::FileCache with a default expiration time of 30 seconds.

=back

=cut

__PACKAGE__->define_cache_styles( 
  'simple' => sub {
    require DBIx::SQLEngine::Cache::TrivialCache;
    DBIx::SQLEngine::Cache::TrivialCache->new();
  },
  'live' => sub {
    require Cache::FastMemoryCache;
    Cache::FastMemoryCache->new( { 
      'namespace' => 'RecordCache:' . (shift), 
      'default_expires_in'  => 1,
      'auto_purge_interval' => 10,
      @_
    } )
  },
  'active' => sub {
    require Cache::FastMemoryCache;
    Cache::FastMemoryCache->new( { 
      'namespace' => 'RecordCache:' . (shift), 
      'default_expires_in'  => 5,
      'auto_purge_interval' => 60,
      @_
    } )
  },
  'stable' => sub {
    require Cache::FastMemoryCache;
    Cache::FastMemoryCache->new( { 
      'namespace' => 'RecordCache:' . (shift), 
      'default_expires_in'  => 30,
      'auto_purge_interval' => 60,
      @_
    } )
  },
  'file' => sub {
    require Cache::FileCache;
    Cache::FileCache->new( { 
      'namespace' => 'RecordCache:' . (shift), 
      'default_expires_in'  => 30,
      'auto_purge_interval' => 60,
      @_
    } )
  },
);

########################################################################

########################################################################

=head1 FETCHING DATA (SQL DQL)

=over 4

=item fetch_select()

  $class_name->fetch_select ( %select_clauses ) : $record_set


=item fetch_one_record()

  $sqldb->fetch_one_record( %select_clauses ) : $record_hash


=item select_record()

  $class_name->select_record ( $primary_key_value ) : $record_obj
  $class_name->select_record ( \@compound_primary_key ) : $record_obj
  $class_name->select_record ( \%hash_with_primary_key_value ) : $record_obj


=item select_records()

  $class_name->select_records ( @primary_key_values_or_hashrefs ) : $record_set


=item visit_select()

  $class_name->visit_select ( $sub_ref, %select_clauses ) : @results
  $class_name->visit_select ( %select_clauses, $sub_ref ) : @results


=back

=cut



# $records = $record_class->fetch_select( %select_clauses );
BEGIN { push @MIXIN, "#line ".__LINE__.' "'.__FILE__.'"', "", <<'/' }
sub fetch_select {
  my $self = shift;
  my %clauses = @_;
  
  my ($records, $update) = $self->cache_get( $self->cache_key_for_fetch( %clauses ) );
  
  if ( ! defined $records ) {
    $records = $self->SUPER::fetch_select( %clauses );
    $update->( $records ) if ( $update and $records );
  }
  
  return $records;
}
/

sub fetch_one_record {
  local $SIG{__DIE__} = \&Carp::confess;
  (shift)->fetch_select( @_, 'limit' => 1 )->record( 0 )
}

# $record = $record_class->select_record( $id_value );
sub select_record {
  my ( $self, $id ) = @_;
  $self->fetch_one_record( where => $self->get_table()->primary_criteria($id) )
}

########################################################################

sub cache_key_for_fetch {
  my ($self, %clauses) = @_;
  
  join "\0/\0", $self->get_table->sqlengine_do( 'sql_select', %clauses )
}

########################################################################

=head2 Vivifying Records From The Database

These methods are called internally by the various select methods and do not need to be called directly.

=over 4

=item record_from_table()

  $class_name->record_from_table( $hash_ref )

Calls SUPER method, then cache_records().

=item record_set_from_table()

  $class_name->record_set_from_table( $hash_array_ref )

Calls SUPER method, then cache_records().

=item cache_records()

  $class_name->cache_records( @records )

Adds records to the cache.

=back

=cut

# $record_class->record_from_table( $hash_ref );
BEGIN { push @MIXIN, "#line ".__LINE__.' "'.__FILE__.'"', "", <<'/' }
sub record_from_table {
  my $self = shift;
  my $record = $self->SUPER::record_from_table( @_ );
  $self->cache_records( $record );
  $record;
}
/

# $record_class->record_set_from_table( $hash_array_ref );
BEGIN { push @MIXIN, "#line ".__LINE__.' "'.__FILE__.'"', "", <<'/' }
sub record_set_from_table {
  my $self = shift;
  my $recordset = $self->SUPER::record_set_from_table( @_ );
  $self->cache_records( @$recordset );
  $recordset;
}
/

sub cache_records {
  my $self = shift;
  my $id_col = $self->column_primary_name();
  foreach my $record ( @_ ) {
    my $tablename = $self->table->name;
    my $criteria = { $id_col => $record->{ $id_col } };
    my %index = ( where => { $id_col => $record->{ $id_col } }, limit => 1, table => $self->table->name );
    $self->cache_set( \%index, DBIx::SQLEngine::Record::Set->new($record) );
  }
}

########################################################################

########################################################################

=head1 EDITING DATA (SQL DML)

=head2 Insert to Add Records

After constructing a record with one of the new_*() methods, you may save any changes by calling insert_record.

=over 4

=item insert_record

  $record_obj->insert_record() : $flag

Attempt to insert the record into the database. Calls SUPER method, so implemented using MIXIN.

Clears the cache.

=back

=cut

# $record->insert_record()
BEGIN { push @MIXIN, "#line ".__LINE__.' "'.__FILE__.'"', "", <<'/' }
sub insert_record {
  my $self = shift;
  $self->cache_clear();
  $self->SUPER::insert_record( @_ );
}
/

########################################################################

=head2 Update to Change Records

After retrieving a record with one of the fetch methods, you may save any changes by calling update_record.

=over 4

=item update_record

  $record_obj->update_record() : $record_count

Attempts to update the record using its primary key as a unique identifier. 
Calls SUPER method, so implemented using MIXIN.

Clears the cache.

=back

=cut

# $record->update_record()
BEGIN { push @MIXIN, "#line ".__LINE__.' "'.__FILE__.'"', "", <<'/' }
sub update_record {
  my $self = shift;
  $self->cache_clear();
  $self->SUPER::update_record( @_ );
}
/

########################################################################

=head2 Delete to Remove Records

=over 4

=item delete_record()

  $record_obj->delete_record() : $record_count

Delete this existing record based on its primary key. 
Calls SUPER method, so implemented using MIXIN.

Clears the cache.

=back

=cut

# $record->delete_record()
BEGIN { push @MIXIN, "#line ".__LINE__.' "'.__FILE__.'"', "", <<'/' }
sub delete_record {
  my $self = shift;
  $self->cache_clear();
  $self->SUPER::delete_record( @_ );
}
/

########################################################################

########################################################################

=head1 SEE ALSO

For more about the Record classes, see L<DBIx::SQLEngine::Record::Class>.

See L<DBIx::SQLEngine> for the overall interface and developer documentation.

See L<DBIx::SQLEngine::Docs::ReadMe> for general information about
this distribution, including installation and license information.

=cut

########################################################################

1;

__END__

### DBO::Row::CachedRow

### Change History
  # 2000-12-29 Added table_or_die() for better debugging output.
  # 2000-05-24 Adjusted fall-back behavior in fetch_sql.
  # 2000-04-12 Check whether being called on instance or class before blessing.
  # 2000-04-11 Fixed really anoying fetch_id problem. 
  # 2000-04-05 Completed expiration and pruning methods.
  # 2000-04-04 Check for empty-string criteria, ordering in cache_key_for_fetch
  # 2000-03-29 Fixed cache expiration for multi-row fetch.
  # 2000-03-06 Touchups.
  # 2000-01-13 Overhauled. -Simon

########################################################################





########################################################################

# $rows = RowClass->fetch( $criteria, $order )
sub fetch {
  my $self = shift;
  
  return $self->query_cache->cache_get_set(
    $self->cache_key_for_fetch( @_ ),
    \&___cache_fetch, $self, @_
  );
}

# $rows = RowClass->fetch_sql( $sql )
sub fetch_sql {
  my $self = shift;
  
  return $self->query_cache->cache_get_set(
    join('__', @_),
    \&___cache_fetch_sql, $self, @_
  );
}

# $row = RowClass->fetch_id( $id )
sub fetch_id {
  my $self = shift;

  return $self->row_cache->cache_get_set(
    join('__', @_),
    \&___cache_fetch_id, $self, @_
  );
}

########################################################################

sub insert_row {
  my $row = shift;
  
  $row->query_cache->clear_all() if ( $row->query_cache );
  
  my $id_col = $row->table_or_die()->id_column();
  my $row_cache = $row->row_cache;
  if ( $id_col and $row_cache ) {
    $row_cache->replace( $row->{$id_col}, $row );
  }
  
  return $row->SUPER::insert_row(@_);
}

sub update_row {
  my $row = shift;
  $row->query_cache->clear_all() if ( $row->query_cache );
  return $row->SUPER::update_row(@_);
}

sub delete_row {
  my $row = shift;
  
  my $id_col = $row->table_or_die()->id_column();
  my $row_cache = $row->row_cache;
  if ( $id_col and $row_cache ) {
    $row_cache->clear( $row->{$id_col} );
  }
  
  $row->query_cache->clear_all() if ( $row->query_cache );
  return $row->SUPER::delete_row(@_);
}


