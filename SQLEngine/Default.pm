=head1 NAME

DBIx::SQLEngine::Default - Core SQLEngine methods

=head1 SYNOPSIS

  # This module is loaded by DBIx::SQLEngine; do not use it directly.
  my $db = DBIx::SQLEngine->new( $DBIConnectionString );
  
  $datasource->do_insert(
    table => 'students', 
    values => { 'name'=>'Dave', 'age'=>'19', 'status'=>'minor' },
  );
  
  $hash_ary = $datasource->fetch_select( 
    table => 'students' 
    criteria => { 'status'=>'minor' },
  );
  
  $datasource->do_update( 
    table => 'students', 
    criteria => 'age > 20' 
    values => { 'status'=>'adult' },
  );
  
  $datasource->do_delete(
    table => 'students', 
    criteria => { 'name'=>'Dave' },
  );


=head1 DESCRIPTION


Each DBIx::SQLEngine object is a wrapper around a DBI database handle.

=cut

########################################################################

package DBIx::SQLEngine::Default;

use strict;
use Carp;
use Class::MakeMethods;

use DBIx::SQLEngine::Criteria::HashGroup;

########################################################################

=head1 PUBLIC INTERFACE

The public interface described below is shared by all SQLEngine subclasses. To facilitate cross-platform subclassing, many these methods are implemented by calling combinations of other methods described in the INTERNALS sections below.

=cut

########################################################################

=head2 Object Creation

Create one SQLEngine for each DBI datasource you will use.

=over 4

=item new

  DBIx::SQLEngine->new( $DBIConnectionString ) : $sqldb
  DBIx::SQLEngine->new( $DBIConnectionString, $user, $pass, $args ) : $sqldb

Accepts the same arguments as the standard DBI connect method. 

=back

=cut

sub new_connection {
  my $class = shift;
  my ($dsn, $user, $pass, $args) = @_;
  $args ||= { AutoCommit => 1, PrintError => 0, RaiseError => 1, };
  __PACKAGE__->log_connect( $dsn ) if __PACKAGE__->DBILogging;
  my $self = DBIx::AnyDBD->connect($dsn, $user, $pass, $args, 'DBIx::SQLEngine');
  return undef unless $self;
  $self->{'reconnector'} = sub { DBI->connect($dsn, $user, $pass, $args) };
  return $self;
}

########################################################################

=head2 Retrieving Data

=over 4

=item fetch_select

  $sqldb->fetch_select( %sql_clauses ) : $row_hashes
  $sqldb->fetch_select( %sql_clauses ) : ( $row_hashes, $column_hashes )

Retrieve rows from the datasource as an array of hashrefs. If called in a list context, also returns an array of hashrefs containing information about the columns included in the result set.

=item visit_select

  $sqldb->visit_select( $code_ref, %sql_clauses ) : @results

Retrieve rows from the datasource as a series of hashrefs, and call the user provided function for each one. Returns the results returned by each of those function calls. This can allow for more efficient processing if you are processing a large number of rows and do not need to keep them all in memory.

=item fetch_one_row

  $sqldb->fetch_one_row( %sql_clauses ) : $row_hash

Calls fetch_select, then returns only the first row of results.

=item fetch_one_value

  $sqldb->fetch_one_value( %sql_clauses ) : $scalar

Calls fetch_select, then returns a single value from the first row of results.

=back

=cut

# $rows = $self->fetch_select( %clauses );
sub fetch_select {
  my $self = shift;
  $self->fetch_sql( $self->sql_select( @_ ) );
}

# $rows = $self->visit_select( $coderef, %clauses );
sub visit_select {
  my $self = shift;
  $self->visit_sql( shift, $self->sql_select( @_ ) );
}

sub fetch_one_row {
  my $self = shift;
  my $rows = $self->fetch_select( @_ ) or return;
  $rows->[0];
}

sub fetch_one_value {
  my $self = shift;
  my $row = $self->fetch_one_row( @_ ) or return;
  (%$row)[1];
}

########################################################################

=head2 Updating Data

=over 4

=item do_insert  

  $sqldb->do_insert( %sql_clauses ) : $row_count

Insert a single row into a table in the datasource. Should always return 1.

=item do_update  

  $sqldb->do_update( %sql_clauses ) : $row_count

Modify one or more rows in a table in the datasource.

=item do_delete

  $sqldb->do_delete( %sql_clauses ) : $row_count

Delete one or more rows in a table in the datasource.

=back

=cut

# $rows = $self->do_insert( %clauses );
sub do_insert {
  my $self = shift;
  $self->do_sql( $self->sql_insert( @_ ) );
}

# $rows = $self->do_update( %clauses );
sub do_update {
  my $self = shift;
  $self->do_sql( $self->sql_update( @_ ) );
}

# $rows = $self->do_delete( %clauses );
sub do_delete {
  my $self = shift;
  $self->do_sql( $self->sql_delete( @_ ) );
}

########################################################################

=head2 Checking For Existence

To determine if the connection is working and whether a table exists.

=over 4

=item detect_any

  $sqldb->detect_any () : $boolean

Attempts to confirm that values can be retreived from the database, using a server-specific "trivial" or "guaranteed" query provided by sql_detect_any.
Catches any exceptions; if the query fails for any reason we return nothing.

=item detect_table

  $sqldb->detect_table ( $tablename ) : @columns_or_empty

Attempts to query the given table without retrieving many (or any) rows. Uses a server-specific "trivial" or "guaranteed" query provided by sql_detect_any. 
Catches any exceptions; if the query fails for any reason we return nothing.

=back

=cut

sub detect_any {
  my $self = shift;
  eval {
    local $SIG{__DIE__};
    $self->fetch_one_value($self->sql_detect_any);
    return 1;
  };
  # warn "Unable to detect_any: $@";
  return;
}

sub detect_table {
  my ($self, $tablename) = @_;
  my @sql;
  my $columns;
  eval {
    local $SIG{__DIE__};
    @sql = $self->sql_detect_table( $tablename );
    ( my($rows), $columns ) = $self->fetch_select( @sql );
  };
  if ( ! $@ ) {
    return @$columns;
  } else {
    # warn "Unable to detect_table $tablename: $@";
    return;
  }
}

########################################################################

=head2 Create and Drop Tables

=over 4

=item do_create_table  

  $sqldb->do_create_table( $tablename, $column_hash_ary ) 

Create a table.

=item do_drop_table  

  $sqldb->do_drop_table( $tablename ) 

Delete a table.

=back

=cut

# $rows = $self->do_create_table( $tablename, $columns );
sub do_create_table {
  my $self = shift;
  $self->do_sql( $self->sql_create_table( @_ ) );
}


# $rows = $self->do_drop_table( $tablename );
sub do_drop_table {
  my $self = shift;
  $self->do_sql( $self->sql_drop_table( @_ ) );
}


########################################################################

=head1 INTERNAL DBH METHODS

The following methods manage the DBI database handle through which we communicate with the datasource.

=over 4

=item _init

  $sqldb->_init () 

Called by DBIx::AnyDBD after connection is made and class hierarch has been juggled.

=item reconnect

  $sqldb->reconnect () 

Attempt to re-establish connection with original parameters

=back

=cut

sub _init  {  }

sub reconnect {
  my $self = shift;
  my $reconnector = $self->{'reconnector'} 
	or croak("Can't reconnect; reconnector is missing");
  if ( $self->{'dbh'} ) {
    $self->{'dbh'}->disconnect;
  }
  $self->{'dbh'} = &$reconnector()
	or croak("Can't reconnect; reconnector returned nothing");
  $self->rebless;
  $self->_init if $self->can('_init');
  return $self;
}

########################################################################

=head2 DBH Access

=over 4

=item get_dbh

  $sqldb->get_dbh () : $dbh

Get the current DBH

=item check_or_reconnect

  $sqldb->check_or_reconnect () : $dbh

Incomplete. Subclass hook. Get the current DBH or reconnect.

=back

=cut

sub get_dbh {
  # maybe add code here to check connection status.
  # or maybe add check once every 10 get_dbh's...
  my $self = shift;
  ( ref $self ) or ( Carp::confess("Not a class method") );
  return $self->{dbh};
}

sub check_or_reconnect {

}

########################################################################

=head1 INTERNAL STH METHODS

The following methods manipulate DBI statement handles as part of processing queries and their results.

=cut

########################################################################

=head2 Query Execution

  $db->do_sql('insert into table values (?, ?)', 'A', 1);
  my $rows = $db->fetch_sql('select * from table where status = ?', 2);

This is the public interface for accessing data through the SQLEngine.

=over 4

=item do_sql

  $sqldb->do_sql ($sql, @params) : $rowcount 

Execute a SQL query by sending it to the DBI connection.

Returns the number of rows modified, or -1 if unknown.

=item fetch_sql 

  $sqldb->fetch_sql ($sql, @params) : ( $row_hash_ary, $columnset )

Similar to do_sql, but returns any rows that were produced.

=item visit_sql 

  $sqldb->visit_sql ($coderef, $sql, @params) : ()

Similar to fetch_sql, but calls your coderef on each row, rather than returning them.

=back

=cut

# $rowcount = $self->do_sql($sql);
# $rowcount = $self->do_sql($sql, @params);
sub do_sql {
  my $self = shift;
  my ($sql, @params) = @_;
  $self->try_query( $sql, \@params, 'get_execute_rowcount' );  
}

# $rows = $self->fetch_sql($sql);
# $rows = $self->fetch_sql($sql, @params);
# ($rows, $columns) = $self->fetch_sql($sql);
sub fetch_sql {
  my $self = shift;
  my ($sql, @params) = @_;
  my ($rows, $columns) = $self->try_query( $sql, \@params, 'fetchall_hashref_columns' );
  return wantarray ? ($rows, $columns) : $rows;
}

# $self->visit_sql($coderef, $sql);
# $self->visit_sql($coderef, $sql, @params);
# $self->visit_sql($coderef, $sql);
sub visit_sql {
  my $self = shift;
  my $coderef = shift;
  my ($sql, @params) = @_;
  $self->try_query( $sql, \@params, 'visitall_hashref', $coderef );
}

########################################################################

=head2 Error Handling

=over 4

=item try_query

  $sqldb->try_query ( $sql, \@params, $result_method, @result_args ) : @results

Error handling wrapper around execute_query.

=item try_query

  $sqldb->catch_query_exception ( $exception, $sql, \@params, $result_method, @result_args ) : $resolution

Subclass hook. Exceptions are passed to catch_query_exception; if it returns "REDO" the query will be retried up to five times.

=back

=cut

# $results = $self->try_query($sql, \@params, $result_method, @result_args);
# @results = $self->try_query($sql, \@params, $result_method, @result_args);
sub try_query {
  my $self = shift;
  
  my $attempts = 0;
  my @results;
  ATTEMPT: {
    $attempts ++;
    eval {
      local $SIG{__DIE__};
      @results = $self->execute_query(@_);
    };
    if ( $@ ) {
      my $catch = $self->catch_query_exception($@, @_);
      if ( ! $catch ) {
	die "Query failed: $@";
      } elsif ( $catch eq 'OK' ) {
	return;
      } elsif ( $catch eq 'REDO' ) {
	if ( $attempts < 5 ) {
	  warn "Retrying query after failure: $@";
	  redo ATTEMPT;
	} else {
	  confess "Query failed on $attempts consecutive attempts: $@\n";
	}
      } else {
	confess "Query failed: $@\n" . 
		"Unknown return from exception handler '$catch'";
      }
    }
  }
  
  wantarray ? @results : ( @results < 2 ) ? $results[0] : 
    croak "This method returns a list, but was called in scalar context";
}

sub catch_query_exception {
  0;
}

########################################################################

=head2 Logging

=over 4

=item DBILogging 

  $sqldb->DBILogging : $value
  $sqldb->DBILogging( $value )

Set this to a true value to turn on logging of DBI interactions. Can be called on the class to set a shared default for all instances, or on any instance to set the value for it alone.

=item log_connect

  $sqldb->log_connect ( $dsn )

Writes out connection logging message.

=item log_start

  $sqldb->log_start( $sql ) : $timer

Called at start of query execution.

=item log_stop

  $sqldb->log_stop( $timer ) : ()

Called at end of query execution.

=back

=cut

use Class::MakeMethods ( 'Standard::Inheritable:scalar' => 'DBILogging' );

# $self->log_connect( $dsn );
sub log_connect {
  my ($self, $dsn) = @_;
  my $class = ref($self) || $self;
  warn "DBI: Connecting to $dsn\n";
}

# $timer = $self->log_start( $sql );
sub log_start {
  my ($self, $sql, @params) = @_;
  my $class = ref($self) || $self;
  
  my $start_time = time;
  
  my $params = join( ', ', map { defined $_ ? "'" . printable($_) . "'" : 'undef' } @params );
  warn "DBI: $sql; $params\n";
  
  return $start_time;
}

# $self->log_stop( $timer );
# $self->log_stop( $timer, $row_count );
sub log_stop { 
  my ($self, $start_time, $rows) = @_;
  my $class = ref($self) || $self;
  
  my $count = ( ref( $rows->[0] ) eq 'ARRAY' ) ? @{ $rows->[0] } : undef;
  my $seconds = (time() - $start_time or 'less than one' );
  
  warn "DBI: Completed in $seconds seconds" . 
	(defined $count ? ", returning $count items" : '') . "\n";
  
  return;
}

########################################################################

use vars qw( %Printable );
%Printable = ( ( map { chr($_), unpack('H2', chr($_)) } (0..255) ),
	      "\\"=>'\\', "\r"=>'r', "\n"=>'n', "\t"=>'t', "\""=>'"' );

# $special_characters_escaped = printable( $source_string );
sub printable ($) {
  local $_ = ( defined $_[0] ? $_[0] : '' );
  s/([\r\n\t\"\\\x00-\x1f\x7F-\xFF])/\\$Printable{$1}/g;
  return $_;
}

########################################################################

=head2 Statement Handle Lifecycle 

These are internal methods for query operations

=over 4

=item execute_query

  $sqldb->execute_query($sql, \@params, $result_method, @result_args) : @results

=item prepare_execute

  $sqldb->prepare_execute ($sql, @params) : $sth

Prepare, bind, and execute a SQL statement.

=item done_with_query

  $sqldb->done_with_query ($sth) : ()

Called when we're done with the $sth.

=back

=cut

# $results = $self->execute_query($sql, \@params, $result_method, @result_args);
# @results = $self->execute_query($sql, \@params, $result_method, @result_args);
sub execute_query {
  my $self = shift;
  
  my ($sql, $params) = (shift, shift);
  my @query = ( $sql, ( $params ? @$params : () ) );

  my ($method, @args) = @_;
  $method ||= 'do_nothing';

  my $timer = $self->log_start( @query ) if $self->DBILogging;
    
  my $sth = $self->prepare_execute( @query );
  my @results;
  eval {
    local $SIG{__DIE__};
    @results = $self->$method( $sth, @args );
  };
  if ( $@ ) {
    if ( $sth ) { 
      $self->done_with_query($sth);
      die $@;
    }
  }
  $self->done_with_query($sth);
  
  $self->log_stop( $timer, \@results ) if $self->DBILogging;
  
  wantarray ? @results : ( @results < 2 ) ? $results[0] : 
    croak "This method returns a list, but was called in scalar context";
}

# $sth = $self->prepare_execute($sql);
# $sth = $self->prepare_execute($sql, @params);
sub prepare_execute {
  my ($self, $sql, @params) = @_;
  
  my $sth;
  $sth = $self->prepare_cached($sql);
  for my $param_no ( 0 .. $#params ) {
    my $param_v = $params[$param_no];
    my @param_v = ( ref($param_v) eq 'ARRAY' ) ? @$param_v : $param_v;
    $sth->bind_param( $param_no+1, @param_v );
  }
  $self->{_last_sth_execute} = $sth->execute();
  
  return $sth;
}

# $self->done_with_query( $sth );
sub done_with_query {
  my ($self, $sth) = @_;
  
  $sth->finish;
}

########################################################################

=head2 Retrieving Rows from a Statement

=over 4

=item do_nothing

  $sqldb->do_nothing ($sth) : ()

Does nothing. 

=item get_execute_rowcount

  $sqldb->get_execute_rowcount ($sth) : ()

Returns the row count reported by the last statement executed.

=item fetchall_arrayref

  $sqldb->fetchall_arrayref ($sth) : $array_of_arrays

Calls the STH's fetchall_arrayref method to retrieve all of the result rows into an array of arrayrefs.

=item fetchall_hashref

  $sqldb->fetchall_hashref ($sth) : $array_of_hashes

Calls the STH's fetchall_arrayref method with an empty hashref to retrieve all of the result rows into an array of hashrefs.

=item fetchall_hashref_columns

  $sqldb->fetchall_hashref ($sth) : $array_of_hashes, $column_info

Calls the STH's fetchall_arrayref method with an empty hashref, and also retrieves information about the columns used in the query result set.

=item visitall_hashref

  $sqldb->visitall_hashref ($sth, $coderef) : ()

Calls coderef on each row with values as hashref; does not return them.

=item visitall_array

  $sqldb->visitall_array ($sth, $coderef) : ()

Calls coderef on each row with values as list; does not return them.

=back

=cut

sub do_nothing {
  return;
}

sub get_execute_rowcount {
  my $self = shift;
  return $self->{_last_sth_execute};
}

sub fetchall_arrayref {
  my ($self, $sth) = @_;
  $sth->fetchall_arrayref();
}

sub fetchall_hashref {
  my ($self, $sth) = @_;
  $sth->fetchall_arrayref( {} );
}

sub fetchall_hashref_columns {
  my ($self, $sth) = @_;
  my $columns = wantarray ? $self->retrieve_columns( $sth ) : 0;
  my $rows = $sth->fetchall_arrayref( {} );
  return ( $rows, $columns );
}

# $self->visitall_hashref( $sth, $coderef );
  # Calls a codref for each row returned by the statement handle
sub visitall_hashref {
  my ($self, $sth, $coderef) = @_;
  my $rowhash;
  while ($rowhash = $sth->fetchrow_hashref) {
    &$coderef( $rowhash );
  }
}

# $self->visitall_array( $sth, $coderef );
  # Calls a codref for each row returned by the statement handle
sub visitall_array {
  my ($self, $sth, $coderef) = @_;
  my @row;
  while (@row = $sth->fetchrow_hashref) {
    &$coderef( @row );
  }
}


########################################################################

=head2 Retrieving Columns from a Statement

=over 4

=item retrieve_columns

  $sqldb->retrieve_columns ($sth) : $columnset

Obtains information about the columns used in the result set.

=item column_type_codes

  $sqldb->column_type_codes - Standard::Global:hash

Maps the ODBC numeric constants used by DBI to the names we want to use for simplified internal representation.

=back

To Do: this should probably be using DBI's type_info methods.

=cut

# %@$columns = $self->retrieve_columns($sth)
  #!# 'pri_key' => $sth->is_pri_key->[$i], 
  # is_pri_key causes the driver to fail with the following fatal error:
  #    relocation error: symbol not found: mysql_columnSeek
  # or at least that happens in the version we last tested it with. -S.
  
sub retrieve_columns {
  my ($self, $sth) = @_;
  
  my $type_defs = $self->column_type_codes();
  my $names = $sth->{'NAME_lc'};
  my $types = $sth->{'TYPE'};
  # warn "Types: " . join(', ', map "'$_'", @$types);
  my $type_codes = [ map { 
	my $typeinfo = scalar $self->type_info($_);
	# warn "Type $typeinfo";
	scalar $typeinfo->{'DATA_TYPE'} 
  } @$types ];
  my $sizes = []; # $sth->{PRECISION};
  my $nullable = $sth->{'NULLABLE'};
  [
    map {
      my $type = $type_defs->{ $type_codes->[$_] || 0 } || $type_codes->[$_];
      $type ||= 'text';
      # warn "New col: $names->[$_] ($type / $types->[$_] / $type_codes->[$_])";
      
      {
	'name' => $names->[$_],
	'type' => $type,
	'required' => ! $nullable->[$_],
	( $type eq 'text' ? ( 'length' => $sizes->[$_] ) : () ),
	
      }
    } (0 .. $#$names)
  ];
}

use Class::MakeMethods ( 'Standard::Global:hash' => 'column_type_codes' );

# $code_to_name_hash = $self->determine_column_type_codes();
__PACKAGE__->column_type_codes(
  DBI::SQL_CHAR() => 'text',		# char
  DBI::SQL_VARCHAR() => 'text',		# varchar
  DBI::SQL_LONGVARCHAR() => 'text',	# 
  253			  => 'text', 	# MySQL varchar
  252			  => 'text', 	# MySQL blob
  
  DBI::SQL_NUMERIC() => 'float',	# numeric (?)
  DBI::SQL_DECIMAL() => 'float',	# decimal
  DBI::SQL_FLOAT() => 'float',		# float
  DBI::SQL_REAL() => 'float',		# real
  DBI::SQL_DOUBLE() => 'float',		# double
  
  DBI::SQL_INTEGER() => 'int',		# integer
  DBI::SQL_SMALLINT() => 'int',		# smallint
  -6		=> 'int',		# MySQL tinyint
  
  DBI::SQL_DATE() => 'time',		# date
  DBI::SQL_TIME() => 'time',		# time
  DBI::SQL_TIMESTAMP() => 'time',	# datetime
);

########################################################################

=head1 INTERNAL SQL METHODS

The various sql_* methods below each accept a hash of arguments and combines then to return a SQL statement and corresponding parameters. Data for each clause of the statement is accepted in a variety of formats to facilitate query abstraction. 

Each method also supports passing arbitrary queries through.

=cut

########################################################################

=head2 Select

=over 4

=item sql_select

  $sqldb->sql_select ( %CLAUSES ) : $sql_stmt, @params

Generate a SQL select statement. If provided, the criteria are used to generate a where clause using sql_where. 

=back

The following argument clauses are supported: 

=over 4

=item sql

Optional; overrides all other arguments. May contain a plain SQL statement to be executed, or a reference to an array of a SQL statement followed by parameters for embedded placeholders.

=item table I<or> tables

Required. The name of the tables to select from.

=item columns

Optional; defaults to '*'. May contain a comma-separated string of column names, or an reference to an array of column names, or a reference to an object with a "column_names" method.

=item criteria

Optional. May contain a literal SQL where clause (everything after there word "where"), or a reference to an array of a SQL string with embedded placeholders followed by the values that should be bound to those placeholders. 

If the criteria argument is a reference to hash, it is treated as a set of field-name => value pairs, and a SQL expression is created that requires each one of the named fields to exactly match the value provided for it, or if the value is an array reference to match any one of the array's contents; see L<DBIx::SQLEngine::Criteria::HashGroup> for details.

Alternately, if the criteria is an object which supports a sql_where() method, the results of that method will be used; see L<DBIx::SQLEngine::Criteria> for classes with this behavior. 

=item order

Optional. May contain a comma-separated string of column names or experessions, optionally followed by "DESC", or an reference to an array of the same.

=item group

Optional. May contain a comma-separated string of column names or experessions, or an reference to an array of the same.

=back

=cut

sub sql_select {
  my $self = shift;
  my %clauses = @_;
  
  if ( my $explicit = $clauses{'sql'} ) {
    return ( ref($explicit) eq 'ARRAY' ) ? @$explicit : $explicit;
  }
  
  my ($sql, @params);
  
  my $columns = $clauses{'columns'};
  delete $clauses{'columns'};
  if ( ! $columns ) {
    $columns = '*';
  } elsif ( ! ref( $columns ) and length( $columns ) ) {
    # should be one or more comma-separated column names
  } elsif ( UNIVERSAL::can($columns, 'column_names') ) {
    $columns = join ', ', $columns->column_names;
  } elsif ( ref($columns) eq 'ARRAY' ) {
    $columns = join ', ', @$columns;
  } else {
    confess("Unsupported column spec '$columns'");
  }
  $sql = "select $columns";
  
  my $tables = $clauses{'table'} || $clauses{'tables'};
  delete $clauses{'table'};
  delete $clauses{'tables'};
  if ( ! $tables ) {
    confess("Table name is missing or empty");
  } elsif ( ! ref( $tables ) and length( $tables ) ) {
    # should be one or more comma-separated table names
  } elsif ( UNIVERSAL::can($tables, 'table_names') ) {
    $tables = $tables->table_names;
  } elsif ( ref($tables) eq 'ARRAY' ) {
    $tables = join ', ', @$tables;
  } else {
    confess("Unsupported table spec '$tables'");
  }
  $sql .= " from $tables";
  
  my $criteria = $clauses{'criteria'};
  delete $clauses{'criteria'};
  my @cp;
  if ( ! $criteria ) {
    # select all
  } elsif ( ! ref( $criteria ) and length( $criteria ) ) {
    # should be a SQL where expression
  } elsif ( UNIVERSAL::can($criteria, 'sql_where') ) {
    ($criteria, @cp) = $criteria->sql_where;
  } elsif ( ref($criteria) eq 'ARRAY' ) {
    ($criteria, @cp) = @$criteria;
  } elsif ( ref($criteria) eq 'HASH' ) {
    ($criteria, @cp) = DBIx::SQLEngine::Criteria::HashGroup->new( %$criteria )->sql_where;
  } else {
    confess("Unsupported criteria spec '$criteria'");
  }
  if ( $criteria ) {
    $sql .= " where $criteria";
    push @params, @cp;
  }
 
  my $order = $clauses{'order'};
  delete $clauses{'order'};
  if ( ! $order ) {
    $order = '';
  } elsif ( ! ref( $order ) and length( $order ) ) {
    # should be one or more comma-separated column names with optional 'desc'
  } elsif ( ref($order) eq 'ARRAY' ) {
    $order = join ', ', @$order;
  } else {
    confess("Unsupported order spec '$order'");
  }
  if ( $order ) {
    $sql .= " order by $order";
  }
  
  my $group = $clauses{'group'};
  delete $clauses{'group'};
  if ( ! $group ) {
    $group = '';
  } elsif ( ! ref( $group ) and length( $group ) ) {
    # should be one or more comma-separated column names or expressions
  } elsif ( ref($group) eq 'ARRAY' ) {
    $group = join ', ', @$group;
  } else {
    confess("Unsupported group spec '$group'");
  }
  if ( $group ) {
    $sql .= " group by $group";
  }
  
  if ( scalar keys %clauses ) {
    confess("Unsupported select clauses: " . 
      join ', ', map "$_ ('$clauses{$_}')", keys %clauses);
  }
  
  $self->log_sql( $sql, @params );
  
  return( $sql, @params );
}

########################################################################

=head2 Insert

=over 4

=item sql_insert

  $sqldb->sql_insert ( %CLAUSES ) : $sql_stmt

Generate a SQL insert statement.

=back

The following argument clauses are supported: 

=over 4

=item sql

Optional; overrides all other arguments. May contain a plain SQL statement to be executed, or a reference to an array of a SQL statement followed by parameters for embedded placeholders.

=item table 

Required. The name of the table to insert into.

=item columns

Optional; defaults to '*'. May contain a comma-separated string of column names, or an reference to an array of column names, or a reference to a hash whose keys contain the column names, or a reference to an object with a "column_names" method.

=item values

Required. May contain a string with one or more comma-separated quoted values or expressions in SQL format, or a reference to an array of values to insert in order, or a reference to a hash whose values are to be inserted.

=back

=cut

sub sql_insert {
  my $self = shift;
  my %clauses = @_;

  if ( my $explicit = $clauses{'sql'} ) {
    return $explicit;
  }

  my ($sql, @params);
  
  my $table = $clauses{'table'};
  delete $clauses{'table'};
  if ( ! $table ) {
    confess("Table name is missing or empty");
  } elsif ( ! ref( $table ) and length( $table ) ) {
    # should be a single table name
  } else {
    confess("Unsupported table spec '$table'");
  }
  $sql = "insert into $table";
  
  my $columns = $clauses{'columns'};
  delete $clauses{'columns'};
  if ( ! $columns and UNIVERSAL::isa( $clauses{'values'}, 'HASH' ) ) {
    $columns = $clauses{'values'}
  }
  if ( ! $columns or $columns eq '*' ) {
    $columns = '';
  } elsif ( ! ref( $columns ) and length( $columns ) ) {
    # should be one or more comma-separated column names
  } elsif ( UNIVERSAL::can($columns, 'column_names') ) {
    $columns = join ', ', $columns->column_names;
  } elsif ( ref($columns) eq 'HASH' ) {
    $columns = join ', ', sort keys %$columns;
  } elsif ( ref($columns) eq 'ARRAY' ) {
    $columns = join ', ', @$columns;
  } else {
    confess("Unsupported column spec '$columns'");
  }
  if ( $columns ) {
    $sql .= " ($columns)";
  }
  
  my $values = $clauses{'values'};
  delete $clauses{'values'};
  my @v_params;
  if ( ! $values ) {
    croak("Values are missing or empty");
  } elsif ( ! ref( $values ) and length( $values ) ) {
    # should be one or more comma-separated quoted values or expressions
  } elsif ( UNIVERSAL::isa( $values, 'HASH' ) ) {
    my @columns = split /,\s?/, $columns;
    @v_params = map $values->{$_}, @columns;
    $values = join ', ', ('?') x scalar @columns;
  } elsif ( ref($values) eq 'ARRAY' ) {
    @v_params = @$values;
    ( scalar @v_params ) or croak("Values are missing or empty");    
    $values = join ', ', ('?') x scalar @$values;
  } else {
    confess("Unsupported values spec '$values'");
  }
  $sql .= " values ($values)";
  push @params, @v_params;
  
  if ( scalar keys %clauses ) {
    confess("Unsupported insert clauses: " . 
      join ', ', map "$_ ('$clauses{$_}')", keys %clauses);
  }
  
  $self->log_sql( $sql, @params );
  
  return( $sql, @params );
}  

########################################################################

=head2 Update

=over 4

=item sql_update

  $sqldb->sql_update ( %CLAUSES ) : $sql_stmt

Generate a SQL update statement. The criteria are used to generate a where clause using sql_where.

=back

The following argument clauses are supported: 

=over 4

=item sql

Optional; overrides all other arguments. May contain a plain SQL statement to be executed, or a reference to an array of a SQL statement followed by parameters for embedded placeholders.

=item table 

Required. The name of the table to insert into.

=item columns

Optional; defaults to '*'. May contain a comma-separated string of column names, or an reference to an array of column names, or a reference to a hash whose keys contain the column names, or a reference to an object with a "column_names" method.

=item values

Required. May contain a string with one or more comma-separated quoted values or expressions in SQL format, or a reference to an array of values to insert in order, or a reference to a hash whose values are to be inserted.

=item criteria

Optional, but remember that ommitting this will cause all of your rows to be updated! May contain a literal SQL where clause (everything after there word "where"), or a reference to an array of a SQL string with embedded placeholders followed by the values that should be bound to those placeholders. 

If the criteria argument is a reference to hash, it is treated as a set of field-name => value pairs, and a SQL expression is created that requires each one of the named fields to exactly match the value provided for it, or if the value is an array reference to match any one of the array's contents; see L<DBIx::SQLEngine::Criteria::HashGroup> for details.

Alternately, if the criteria is an object which supports a sql_where() method, the results of that method will be used; see L<DBIx::SQLEngine::Criteria> for classes with this behavior. 


=back

=cut

sub sql_update {
  my $self = shift;
  my %clauses = @_;

  if ( my $explicit = $clauses{'sql'} ) {
    return $explicit;
  }

  my ($sql, @params);
    
  my $table = $clauses{'table'};
  delete $clauses{'table'};
  if ( ! $table ) {
    confess("Table name is missing or empty");
  } elsif ( ! ref( $table ) and length( $table ) ) {
    # should be a single table name
  } else {
    confess("Unsupported table spec '$table'");
  }
  $sql = "update $table";

  my $columns = $clauses{'columns'};
  delete $clauses{'columns'};
  if ( ! $columns and UNIVERSAL::isa( $clauses{'values'}, 'HASH' ) ) {
    $columns = $clauses{'values'}
  }
  my @columns;
  if ( ! $columns or $columns eq '*' ) {
    croak("Column names are missing or empty");
  } elsif ( ! ref( $columns ) and length( $columns ) ) {
    # should be one or more comma-separated column names
    @columns = split /,\s?/, $columns;
  } elsif ( UNIVERSAL::can($columns, 'column_names') ) {
    @columns = $columns->column_names;
  } elsif ( ref($columns) eq 'HASH' ) {
    @columns = sort keys %$columns;
  } elsif ( ref($columns) eq 'ARRAY' ) {
    @columns = @$columns;
  } else {
    confess("Unsupported column spec '$columns'");
  }
  
  my $values = $clauses{'values'};
  delete $clauses{'values'};
  my @v_params;
  if ( ! $values ) {
    croak("Values are missing or empty");
  } elsif ( ! ref( $values ) and length( $values ) ) {
    confess("Unsupported!");
  } elsif ( UNIVERSAL::isa( $values, 'HASH' ) ) {
    @v_params = map $values->{$_}, @columns;
    $values = join ', ', ('?') x scalar @columns;
  } elsif ( ref($values) eq 'ARRAY' ) {
    @v_params = @$values;
    $values = join ', ', ('?') x scalar @$values;
  } else {
    confess("Unsupported values spec '$values'");
  }
  
  $sql .= " set " . join ', ', map "$_ = ?", @columns;
  push @params, @v_params;
  
  my $criteria = ( $clauses{'criteria'} );
  delete $clauses{'criteria'};
  my @cp;
  if ( ! $criteria ) {
    # update all
  } elsif ( ! ref( $criteria ) and length( $criteria ) ) {
    # should be a SQL where expression
  } elsif ( UNIVERSAL::can($criteria, 'sql_where') ) {
    ($criteria, @cp) = $criteria->sql_where;
  } elsif ( ref($criteria) eq 'ARRAY' ) {
    ($criteria, @cp) = @$criteria;
  } elsif ( ref($criteria) eq 'HASH' ) {
    ($criteria, @cp) = DBIx::SQLEngine::Criteria::HashGroup->new( %$criteria )->sql_where;
  } else {
    confess("Unsupported criteria spec '$criteria'");
  }
  if ( $criteria ) {
    $sql .= " where $criteria";
    push @params, @cp;
  }
  
  if ( scalar keys %clauses ) {
    confess("Unsupported update clauses: " . 
      join ', ', map "$_ ('$clauses{$_}')", keys %clauses);
  }
  
  $self->log_sql( $sql, @params );
  
  return( $sql, @params );
}  

########################################################################

=head2 Delete

=over 4

=item sql_delete

  $sqldb->sql_delete ( %CLAUSES ) : $sql_stmt

Generate a SQL delete statement. The criteria are used to generate a where clause using sql_where.

=back

The following argument clauses are supported: 

=over 4

=item sql

Optional; overrides all other arguments. May contain a plain SQL statement to be executed, or a reference to an array of a SQL statement followed by parameters for embedded placeholders.

=item table 

Required (unless explicit "sql => ..." is used). The name of the table to delete from.

=item criteria

Optional, but remember that ommitting this will cause all of your rows to be deleted! May contain a literal SQL where clause (everything after there word "where"), or a reference to an array of a SQL string with embedded placeholders followed by the values that should be bound to those placeholders. 

If the criteria argument is a reference to hash, it is treated as a set of field-name => value pairs, and a SQL expression is created that requires each one of the named fields to exactly match the value provided for it, or if the value is an array reference to match any one of the array's contents; see L<DBIx::SQLEngine::Criteria::HashGroup> for details.

Alternately, if the criteria is an object which supports a sql_where() method, the results of that method will be used; see L<DBIx::SQLEngine::Criteria> for classes with this behavior.

=back

=cut

sub sql_delete {
  my $self = shift;
  my %clauses = @_;

  if ( my $explicit = $clauses{'sql'} ) {
    return $explicit;
  }

  my ($sql, @params);
    
  my $table = $clauses{'table'};
  delete $clauses{'table'};
  if ( ! $table ) {
    confess("Table name is missing or empty");
  } elsif ( ! ref( $table ) and length( $table ) ) {
    # should be a single table name
  } else {
    confess("Unsupported table spec '$table'");
  }
  $sql = "delete from $table";
  
  my $criteria = $clauses{'criteria'};
  delete $clauses{'criteria'};
  my @cp;
  if ( ! $criteria ) {
    # delete all
  } elsif ( ! ref( $criteria ) and length( $criteria ) ) {
    # should be a SQL where expression
  } elsif ( UNIVERSAL::can($criteria, 'sql_where') ) {
    ($criteria, @cp) = $criteria->sql_where;
  } elsif ( ref($criteria) eq 'ARRAY' ) {
    ($criteria, @cp) = @$criteria;
  } elsif ( ref($criteria) eq 'HASH' ) {
    ($criteria, @cp) = DBIx::SQLEngine::Criteria::HashGroup->new( %$criteria )->sql_where;
  } else {
    confess("Unsupported criteria spec '$criteria'");
  }
  if ( $criteria ) {
    $sql .= " where $criteria";
    push @params, @cp;
  }
  
  if ( scalar keys %clauses ) {
    confess("Unsupported delete clauses: " . 
      join ', ', map "$_ ('$clauses{$_}')", keys %clauses);
  }
  
  $self->log_sql( $sql, @params );
  
  return( $sql, @params );
}

########################################################################

=head2 Data Definition 

=over 4

=item sql_create_table

  $sqldb->sql_create_table ($tablename, $columns) : $sql_stmt

Generate a SQL create-table statement based on the column information. Text columns are checked with sql_create_column_text_length() to provide server-appropriate types.

=item sql_drop_table

  $sqldb->sql_drop_table ($tablename) : $sql_stmt

=back

=cut

sub sql_create_table {
  my($self, $table, $columns) = @_;
  
  my @sql_columns;
  my $column;
  foreach $column ( @$columns ) {
    push @sql_columns, $self->sql_create_columns($table, $column, \@sql_columns)
  }
  
  my $sql = "create table $table ( \n" . join(",\n", @sql_columns) . "\n)\n";
  
  $self->log_sql( $sql );
  return $sql;
}

sub sql_create_columns {
  my($self, $table, $column , $columns) = @_;
  my $name = $column->{name};
  my $type = $column->{type};
  if ( $type eq 'primary' ) {
    return "PRIMARY KEY ($name)";
  } else {
    if ( $type eq 'text' ) {
      my $length = $column->{length};
      $type = $self->sql_create_column_text_length( $length || 255 ) ;
    }
    my $required = $column->{required};
    $type .= " not null" if ( $required );
    return '  ' . $name . 
	    ' ' x ( ( length($name) > 31 ) ? ' ' : ( 32 - length($name) ) ) .
	    $type;
  }
}

sub sql_drop_table {
  my ($self, $table) = @_;
  my $sql = "drop table $table";
  $self->log_sql( $sql );
  return $sql;
}

########################################################################

=head2 Server-Specific SQL

=over 4

=item sql_create_column_text_length

  $sqldb->sql_create_column_text_length ( $length ) : $col_type_str

Returns varchar(length) for values under 256, otherwise calls sql_create_column_text_long_type.

=item sql_create_column_text_long_type

  $sqldb->sql_create_column_text_long_type () : $col_type_str

Fails with message "DBMS-Specific Function".

Subclasses should, based on the datasource's server_type, return the appropriate type of column for long text values, such as "BLOB", "TEXT", "LONGTEXT", or "MEMO".

=item sql_escape_text_for_like

  $sqldb->sql_escape_text_for_like ( $text ) : $escaped_expr

Fails with message "DBMS-Specific Function".

Subclasses should, based on the datasource's server_type, protect a literal value for use in a like expression.

=back

=cut

sub sql_create_column_text_length {
  my $self = shift;
  my $length = shift;

  return "varchar($length)" if ($length < 256);
  return $self->sql_create_column_text_long_type;
}

sub sql_create_column_text_long_type {
  confess "DBMS-Specific Function"
}

sub sql_escape_text_for_like {
  confess "DBMS-Specific Function"
}

########################################################################

=head2 Checking For Existence

To determine if the connection is working and whether a table exists.

=over 4

=item sql_detect_any

  $sqldb->sql_detect_any : %sql_select_clauses

Subclass hook. Retrieve something from the database that is guaranteed to exist. 
Defaults to SQL literal "select 1", which may not work on all platforms. Your subclass might prefer one of these: "select SYSDATE() from dual", (I'm unsure of the others)...

=item sql_detect_table

  $sqldb->sql_detect_table ( $tablename )  : %sql_select_clauses

Subclass hook. Retrieve something from the given table that is guaranteed to exist but does not return many rows, without knowning its table structure. 

Defaults to "select * from table where 1 = 0", which may not work on all platforms. Your subclass might prefer one of these: "select * from table limit 1", (I'm unsure of the others)...

=back

=cut

sub sql_detect_any {
  return ( sql => 'select 1' )
}

sub sql_detect_table {
  my ($self, $tablename) = @_;

  # Your subclass might prefer one of these...
  # return ( sql => "select * from $tablename limit 1" )
  # return ( sql => "select * from $tablename where 1 = 0" )
  
  return (
    table => $tablename,
    criteria => '1 = 0',
  )
}

########################################################################

=head2 SQL Logging

=over 4

=item SQLLogging

  $sqldb->SQLLogging () : $value 
  $sqldb->SQLLogging( $value )

Set this to a true value to turn on logging of internally-generated SQL statements (all queries except for those with complete SQL statements explicitly passed in by the caller). Can be called on the class to set a shared default for all instances, or on any instance to set the value for it alone.

=item log_sql

  $sqldb->log_sql( $sql ) : ()

Called when SQL is generated.

=back

=cut

use Class::MakeMethods ( 'Standard::Inheritable:scalar' => 'SQLLogging' );

# $self->log_sql( $sql );
sub log_sql {
  my ($self, $sql, @params) = @_;
  return unless $self->SQLLogging;
  my $class = ref($self) || $self;
  my $params = join( ', ', map { defined $_ ? "'$_'" : 'undef' } @params );
  warn "SQL: $sql; $params\n";
}

########################################################################

=head1 SEE ALSO

L<DBIx::SQLEngine>

=cut

1;
