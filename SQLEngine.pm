=head1 NAME

DBIx::SQLEngine - Extends DBI with high-level operations

=head1 SYNOPSIS

  my $sqldb = DBIx::SQLEngine->new( @DBIConnectionArgs );
  
  $sqldb->do_insert(
    table => 'students', 
    values => { 'name'=>'Dave', 'age'=>'19', 'status'=>'minor' },
  );
  
  $hash_ary = $sqldb->fetch_select( 
    table => 'students' 
    criteria => { 'status'=>'minor' },
  );
  
  $sqldb->do_update( 
    table => 'students', 
    criteria => 'age > 20' 
    values => { 'status'=>'adult' },
  );
  
  $sqldb->do_delete(
    table => 'students', 
    criteria => { 'name'=>'Dave' },
  );

=head1 ABSTRACT

The DBIx::SQLEngine class provides an extended interface for the
DBI database framework. Each SQLEngine object is a wrapper around
a DBI database handle, adding methods that support ad-hoc SQL
generation and query execution in a single call. Dynamic subclassing
based on database server type enables cross-platform portability.


=head1 DESCRIPTION

DBIx::SQLEngine is the latest generation of a toolkit used by the
authors for several years to develop business data applications
and object-relational mapping toolkits. Its goal is to simplify
dynamic query execution with the following capabilities:

=over 4

=item *

Data-driven SQL: Ad-hoc generation of SQL statements from Perl data
structures in a variety of formats; simple hash and array references
are flexibly converted to form clauses in standard SQL query syntax.

=item *

High-Level Interface: Standard query operations are handled by a single
method call each. Error handling is standardized, and routine
annoyances like timed-out connections are retried automatically.

=item *

Full DBI Access: Accepts arbitrary SQL queries with placeholder
parameters to be passed through, and delegates all other method
calls to a wrapped database handle, allowing access to the entire
DBI API for cases when high-level interfaces are insufficient

=item *

Portability Subclasses: Uses dynamic subclassing (via DBIx::AnyDBD)
to allow platform-specific support for driver idiosyncrasies and
DBMS workarounds. This release includes subclasses for connections
to MySQL, PostgreSQL, Oracle, and Microsoft SQL servers, as well
as for the standalone SQLite, AnyData, and CSV packages.

=back

=head2 Data-driven SQL

Several methods are responsible for converting their arguments into
commands and placeholder parameters in SQL, the Structured Query
Language.

The various methods whose names being with sql_, like sql_select
and sql_insert, each accept a hash of arguments and combines then
to return a SQL statement and corresponding parameters. Data for
each clause of the statement is accepted in multiple formats to
facilitate query abstraction, often including various strings,
array refs, and hash refs. Each method also supports passing
arbitrary queries through using a C<sql> parameter.

=head2 High-Level Interface

The combined query interface provides a useful high-level idiom to
perform the typical cycle of SQL generation, query execution, and
results fetching, all through a single method call.

The various fetch_*, visit_* and do_* methods that don't end in
_sql, like fetch_select and do_insert, are wrappers that combine
a SQL-generation and a SQL-execution method to provide a simple
ways to perform a query in one call.

=head2 Full DBI Access

Each DBIx::SQLEngine object is implemented as a wrapper around a
database handle provided by DBI, the Perl Database Interface.

Arbitrary queries can be executed, bypassing the SQL generation
capabilities. The methods whose names end in _sql, like fetch_sql
and do_sql, each accept a SQL statement and parameters, pass it to
the DBI data source, and return information about the results of
the query.

=head2 Portability Subclasses

Behind the scenes, different subclasses of SQLEngine are instantiated
depending on the type of server to which you connect, thanks to
DBIx::AnyData. As a result, some range of SQL dialect ideosyncracies
can be compensated for. 

For example, the sql_limit method controls the syntax for select
statements with limit and offset clauses, and both MySQL and Oracle
override this method to use their local syntax.

The only method that's actually provided by the DBIx::SQLEngine
class itself is the new() constructor. All of the other methods
are defined in DBIx::SQLEngine::Driver::Default, or in one of its
automatically-loaded subclasses.

The public interface of DBIx::SQLEngine is shared by all of its
subclasses. The superclass methods aim to produce and perform
generic queries in an database-independent fashion, using standard
SQL syntax.  Subclasses may override these methods to compensate
for idiosyncrasies of their database server or mechanism.  To
facilitate cross-platform subclassing, many of these methods are
implemented by calling combinations of other methods, which may
individually be overridden by subclasses.

=cut

########################################################################

package DBIx::SQLEngine;

$VERSION = 0.017;

use strict;

use DBI;
use DBIx::AnyDBD;
use Class::MakeMethods;

########################################################################

########################################################################

=head1 ENGINE INSTANTIATION

=head2 SQLEngine Object Creation

Create one SQLEngine for each DBI datasource you will use.

=over 4

=item new()

  DBIx::SQLEngine->new( $dbh ) : $sqldb
  DBIx::SQLEngine->new( $dsn ) : $sqldb
  DBIx::SQLEngine->new( $dsn, $user, $pass ) : $sqldb
  DBIx::SQLEngine->new( $dsn, $user, $pass, $args ) : $sqldb

Based on the arguments supplied, invokes either new_with_connect() or new_with_dbh() and returns the resulting new object.

=item new_with_connect()

  DBIx::SQLEngine->new_with_connect( $dsn ) : $sqldb
  DBIx::SQLEngine->new_with_connect( $dsn, $user, $pass ) : $sqldb
  DBIx::SQLEngine->new_with_connect( $dsn, $user, $pass, $args ) : $sqldb

Accepts the same arguments as the standard DBI connect method. 

I<Note:> this method has recently been added and the interface is subject to change.

=item new_with_dbh()

  DBIx::SQLEngine->new_with_dbh( $dbh ) : $sqldb

Accepts an existing DBI database handle and creates a new SQLEngine object around it.

I<Note:> this method has recently been added and the interface is subject to change.

=back

B<Portability:> After setting up the DBI handle that it will use, the SQLEngine is reblessed into a matching subclass, if one is available. Thus, if you connect a DBIx::SQLEngine through DBD::mysql, by passing a DSN such as "dbi:mysql:test", your object will automatically shift to being an instance of the DBIx::SQLEngine::Driver::Mysql class. This allows the driver-specific subclasses to compensate for differences in the SQL dialect or execution ideosyncracies of that platform.

=cut

sub new {
  my $class = shift;
  ref($_[0]) ? $class->new_with_dbh( @_ ) : $class->new_with_connect( @_ )
}

sub new_with_connect {
  my ($class, $dsn, $user, $pass, $args) = @_;
  $args ||= { AutoCommit => 1, PrintError => 0, RaiseError => 1 };
  DBIx::SQLEngine::Driver::Default->log_connect( $dsn ) 
	if DBIx::SQLEngine::Driver::Default->DBILogging;
  my $self = DBIx::AnyDBD->connect($dsn, $user, $pass, $args, 
						'DBIx::SQLEngine::Driver');
  return undef unless $self;
  $self->{'reconnector'} = sub { DBI->connect($dsn, $user, $pass, $args) };
  return $self;
}

sub new_with_dbh {
  my ($class, $dbh) = @_;
  my $self = bless { 'package' => 'DBIx::SQLEngine::Driver', 'dbh' => $dbh }, 'DBIx::AnyDBD';
  $self->rebless;
  $self->_init if $self->can('_init');
  return $self;  
}

########################################################################

sub DBILogging { shift; DBIx::SQLEngine::Driver::Default->DBILogging( @_ ) }
sub SQLLogging { shift; DBIx::SQLEngine::Driver::Default->SQLLogging( @_ ) }

########################################################################

# Set up default driver package and ensure that we don't try to require it later
package DBIx::SQLEngine::Driver::Default;

BEGIN { $INC{'DBIx/SQLEngine/Driver.pm'} = __FILE__ }
BEGIN { $INC{'DBIx/SQLEngine/Driver/Default.pm'} = __FILE__ }

use strict;
use Carp;

########################################################################

=head1 FETCHING DATA (SQL DQL)

Information is obtained from a DBI database through the Data Query Language features of SQL.

=head2 Select to Retrieve Data

The following methods may be used to retrieve data using SQL select statements. They all accept a flexible set of key-value arguments describing the query to be run, as described in the "SQL Select Clauses" section below.

=over 4

=item fetch_select()

  $sqldb->fetch_select( %sql_clauses ) : $row_hashes
  $sqldb->fetch_select( %sql_clauses ) : ($row_hashes,$column_hashes)

Retrieve rows from the datasource as an array of hashrefs. If called in a list context, also returns an array of hashrefs containing information about the columns included in the result set.

=item fetch_select_rows()

  $sqldb->fetch_select_rows( %sql_clauses ) : $row_arrays
  $sqldb->fetch_select_rows( %sql_clauses ) : ($row_arrays,$column_hashes)

Retrieve rows from the datasource as an array of arrayrefs. If called in a list context, also returns an array of hashrefs containing information about the columns included in the result set.

=item fetch_one_row()

  $sqldb->fetch_one_row( %sql_clauses ) : $row_hash

Calls fetch_select, then returns only the first row of results.

=item fetch_one_value()

  $sqldb->fetch_one_value( %sql_clauses ) : $scalar

Calls fetch_select, then returns a single value from the first row of results.

=item visit_select()

  $sqldb->visit_select( $code_ref, %sql_clauses ) : @results
  $sqldb->visit_select( %sql_clauses, $code_ref ) : @results

Retrieve rows from the datasource as a series of hashrefs, and call the user provided function for each one. For your convenience, will accept a coderef as either the first or the last argument. Returns the results returned by each of those function calls. Processing with visit_select rather than fetch_select can be more efficient if you are looping over a large number of rows and do not need to keep them all in memory.

=item visit_select_rows()

  $sqldb->visit_select_rows( $code_ref, %sql_clauses ) : @results
  $sqldb->visit_select_rows( %sql_clauses, $code_ref ) : @results

Like visit_select, but for each row the code ref is called with the current row retrieved as a list of values, rather than a hash ref.

=item sql_select()

  $sqldb->sql_select ( %sql_clauses ) : $sql_stmt, @params

Generate a SQL select statement and returns it as a query string and a list of values to be bound as parameters. Internally, this sql_ method is used by the fetch_ and visit_ methods above.

=back

B<SQL Select Clauses>: The above select methods accept a hash describing the clauses of the SQL statement they are to generate, using the values provided for the keys defined below. 

=over 4

=item named_query 

Uses the named_query catalog to build the query. May contain a defined query name, or a reference to an array of a query name followed by parameters to be handled by interpret_named_query. See L</"NAMED QUERY CATALOG"> for details.

=item sql

Can not be used in combination with the table and columns arguments. May contain a plain SQL statement to be executed, or a reference to an array of a SQL statement followed by parameters for embedded placeholders.

=item table I<or> tables

Required unless sql is provided. The name of the tables to select from.

=item columns

Optional; defaults to '*'. May contain a comma-separated string of column names, or an reference to an array of column names, or a reference to an object with a "column_names" method.

=item criteria

Optional. May contain a literal SQL where clause, an array ref with a SQL clause and parameter list, a hash of field => value pairs, or an object that supports a sql_where() method. See the sql_where() method for details.

=item order

Optional. May contain a comma-separated string of column names or experessions, optionally followed by "DESC", or an reference to an array of the same.

=item group

Optional. May contain a comma-separated string of column names or experessions, or an reference to an array of the same.

=item limit

Optional. Maximum number of rows to be retrieved from the server. Relies on DBMS-specific behavior provided by sql_limit(). 

=item offset

Optional. Number of rows at the start of the result which should be skipped over. Relies on DBMS-specific behavior provided by sql_limit(). 

=back

B<Examples:>

=over 2

=item *

Each query can be written out explicitly or generated on demand using whichever syntax is most appropriate to your application:

  $hashes = $sqldb->fetch_select( 
    table => 'students', criteria => { 'status' => 'minor' } 
  );

  $hashes = $sqldb->fetch_select( 
    table => 'students', criteria => [ 'status = ?', 'minor' ]
  );

  $hashes = $sqldb->fetch_select( 
    sql => 'select * from students', criteria => { 'status' => 'minor' }
  );

  $hashes = $sqldb->fetch_select( 
    table => 'students', criteria => 
      DBIx::SQLEngine::Criteria->type_new('Equality','status'=>'minor')
  );

  $hashes = $sqldb->fetch_select( 
    sql => "select * from students where status = 'minor'"
  );

  $hashes = $sqldb->fetch_select( 
    sql => [ 'select * from students where status = ?', 'minor' ]
  );

  $sqldb->define_named_query(
    'minor_students' => "select * from students where status = 'minor'" 
  );
  $hashes = $sqldb->fetch_select( 
    named_query => 'minor_students' 
  );

=item *

Optional clauses limiting the columns returned, and specifying an order:

  $hashes = $sqldb->fetch_select( 
    table => 'students', columns => 'name, age', order => 'name'
  );

=item *

Here's a criteria clause that uses a function to find the youngest people; note the use of a backslash to indicate that "min(age)" is an expression to be evaluated by the database server, rather than a literal value:

  $hashes = $sqldb->fetch_select( 
    table => 'students', criteria => { 'age' => \"min(age)" } 
  );

=item *

Here's a join of two tables; note that we're using a backslash again to make it clear that we're looking for tuples where the students.id column matches that the grades.student_id column, rather than trying to match the literal string 'grades.student_id':

  $hashes = $sqldb->fetch_select( 
    tables => 'students, grades', 
    criteria => { 'students.id' = \'grades.student_id' } 
    order => 'students.name'
  );

=item *

If you know that only one row will match, you can use fetch_one_row:

  $joe = $sqldb->fetch_one_row( 
    table => 'student', criteria => { 'id' => 201 }
  );

All of the SQL select clauses are accepted, including explicit SQL statements with parameters:

  $joe = $sqldb->fetch_one_row( 
    sql => [ 'select * from students where id = ?', 201 ]
  );

=item *

And when you know that there will only be one row and one column in your result set, you can use fetch_one_value:

  $count = $sqldb->fetch_one_value( 
    table => 'student', columns => 'count(*)'
  );

All of the SQL select clauses are accepted, including explicit SQL statements with parameters:

  $maxid = $sqldb->fetch_one_value( 
    sql => [ 'select max(id) from students where status = ?', 'minor' ]
  );

=item *

You can use visit_select to make a traversal of all rows that match a query without retrieving them all at once:

  $sqldb->visit_select( 
    sub {
      my $student = shift;
      print $student->{id}, $student->{name}, $student->{age};
    }, 
    table => 'student'
  );

=item *

You can collect values along the way:

  my @firstnames = $sqldb->visit_select( 
    sub {
      my $student = shift;
      ( $student->{name} =~ /(\w+)\s/ ) ? $1 : $student->{name};
    }, 
    table => 'student'
  );

=item *

You can visit with any combination of the other clauses supported by fetch_select:

   $sqldb->visit_select( 
    sub {
      my $student = shift;
      print $student->{id}, $student->{name};
    }, 
    table => 'student', 
    columns => 'id, name', 
    order => 'name, id desc',
    criteria => 'age < 22',
  );

=back

=cut

# $rows = $self->fetch_select( %clauses );
sub fetch_select {
  my $self = shift;
  $self->fetch_sql( $self->sql_select( @_ ) );
}

# $rows = $self->fetch_select_rows( %clauses );
sub fetch_select_rows {
  my $self = shift;
  $self->fetch_sql_rows( $self->sql_select( @_ ) );
}

# $row = $self->fetch_one_row( %clauses );
sub fetch_one_row {
  my $self = shift;
  my $rows = $self->fetch_select( limit => 1, @_ ) or return;
  $rows->[0];
}

# $value = $self->fetch_one_value( %clauses );
sub fetch_one_value {
  my $self = shift;
  my $row = $self->fetch_one_row( @_ ) or return;
  (%$row)[1];
}

# $rows = $self->visit_select( %clauses, $coderef );
# $rows = $self->visit_select( $coderef, %clauses );
sub visit_select {
  my $self = shift;
  $self->visit_sql( ( ref($_[0]) ? shift : pop ), $self->sql_select( @_ ) )
}

# $rows = $self->visit_select_rows( %clauses, $coderef );
# $rows = $self->visit_select_rows( $coderef, %clauses );
sub visit_select_rows {
  my $self = shift;
  $self->visit_sql_rows( ( ref($_[0]) ? shift : pop ), $self->sql_select( @_ ) )
}

sub sql_select {
  my ( $self, %clauses ) = @_;

  my $keyword = 'select';
  my ($sql, @params);

  if ( my $named = delete $clauses{'named_query'} ) {
    my %named = $self->interpret_named_query( ref($named) ? @$named : $named );
    %clauses = ( %named, %clauses );
  }

  if ( my $action = delete $clauses{'action'} ) {
    confess("Action mismatch: expecting $keyword, not $action query") 
	unless ( $action eq $keyword );
  }

  if ( my $literal = delete $clauses{'sql'} ) {
    ($sql, @params) = ( ref($literal) eq 'ARRAY' ) ? @$literal : $literal;
    if ( my ( $conflict ) = grep $clauses{$_}, qw/ columns table tables / ) { 
      croak("Can't build a $keyword query using both sql and $conflict clauses")
    }
  
  } else {
  
    my $columns = delete $clauses{'columns'};
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
    
    my $tables = delete $clauses{'table'} || delete $clauses{'tables'};
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
  }
  
  if ( my $criteria = delete $clauses{'criteria'} || delete $clauses{'where'} ){
    ($sql, @params) = $self->sql_where($criteria, $sql, @params);
  }
  
  if ( my $group = delete $clauses{'group'} ) {
    if ( ! ref( $group ) and length( $group ) ) {
      # should be one or more comma-separated column names or expressions
    } elsif ( ref($group) eq 'ARRAY' ) {
      $group = join ', ', @$group;
    } else {
      confess("Unsupported group spec '$group'");
    }
    if ( $group ) {
      $sql .= " group by $group";
    }
  }
  
  if ( my $order = delete $clauses{'order'} ) {
    if ( ! ref( $order ) and length( $order ) ) {
      # should be one or more comma-separated column names with optional 'desc'
    } elsif ( ref($order) eq 'ARRAY' ) {
      $order = join ', ', @$order;
    } else {
      confess("Unsupported order spec '$order'");
    }
    if ( $order ) {
      $sql .= " order by $order";
    }
  }
  
  my $limit = delete $clauses{limit};
  my $offset = delete $clauses{offset};
  if ( $limit or $offset) {
    ($sql, @params) = $self->sql_limit($limit, $offset, $sql, @params);
  }
  
  if ( scalar keys %clauses ) {
    confess("Unsupported $keyword clauses: " . 
      join ', ', map "$_ ('$clauses{$_}')", keys %clauses);
  }
  
  $self->log_sql( $sql, @params );
  
  return( $sql, @params );
}

########################################################################

=pod

B<Portability:> Limit and offset clauses are handled differently by various DBMS platforms. For example, MySQL accepts "limit 20,10", Postgres "limit 10 offset 20", and Oracle requires a nested select with rowcount. The sql_limit method can be overridden by subclasses to adjust this behavior.

=over 4

=item sql_limit()

  $sqldb->sql_limit( $limit, $offset, $sql, @params ) : $sql, @params

Modifies the SQL statement and parameters list provided to apply the specified limit and offset requirements. Triggered by use of a limit or offset clause in a call to sql_select().

=item sql_where()

  $sqldb->sql_where( $criteria, $sql, @params ) : $sql, @params

Modifies the SQL statement and parameters list provided to append the specified criteria as a where clause. Triggered by use of criteria in a call to sql_select(), sql_update(), or sql_delete(). 

The criteria may be a literal SQL where clause (everything after the word "where"), or a reference to an array of a SQL string with embedded placeholders followed by the values that should be bound to those placeholders. 

If the criteria argument is a reference to hash, it is treated as a set of field-name => value pairs, and a SQL expression is created that requires each one of the named fields to exactly match the value provided for it, or if the value is an array reference to match any one of the array's contents; see L<DBIx::SQLEngine::Criteria::HashGroup> for details.

Alternately, if the criteria argument is a reference to an object which supports a sql_where() method, the results of that method will be used; see L<DBIx::SQLEngine::Criteria> for classes with this behavior. 

If no SQL statement or parameters are provided, this just returns the where clause and associated parameters. If a SQL statement is provided, the where clauses is appended to it; if the SQL statement already includes a where clause, the additional criteria are inserted into the existing statement and AND'ed together with the existing criteria.


=item sql_escape_text_for_like()

  $sqldb->sql_escape_text_for_like ( $text ) : $escaped_expr

Fails with message "DBMS-Specific Function".

Subclasses should, based on the datasource's server_type, protect a literal value for use in a like expression.

=back

=cut

use DBIx::SQLEngine::Criteria;

sub sql_where {
  my $self = shift;
  my ( $criteria, $sql, @params ) = @_;
  
  my ( $sql_crit, @cp ) = DBIx::SQLEngine::Criteria->auto_where( $criteria );
  if ( $sql_crit ) {
    if ( ! defined $sql ) { 
      $sql = "where $sql_crit";
    } elsif ( $sql =~ s{(\bwhere\b)(.*?)(\border by|\bgroup by|$)}
			{$1 ($2) AND $sql_crit $3}i ) {
    } else {
      $sql .= " where $sql_crit";
    }
    push @params, @cp;
  }
  
  return ($sql, @params);
}

sub sql_escape_text_for_like {
  confess("DBMS-Specific Function")
}

sub sql_limit {
  my $self = shift;
  my ( $limit, $offset, $sql, @params ) = @_;
  
  $sql .= " limit $limit" if $limit;
  $sql .= " offset $offset" if $offset;
  
  return ($sql, @params);
}

########################################################################

########################################################################

=head1 EDITING DATA (SQL DML)

Information is entered into a DBI database through the Data Manipulation Language features of SQL.

=head2 Insert to Add Data 

=over 4

=item do_insert()

  $sqldb->do_insert( %sql_clauses ) : $row_count

Insert a single row into a table in the datasource. Should return 1, unless there's an exception.

=item sql_insert()

  $sqldb->sql_insert ( %sql_clauses ) : $sql_stmt, @params

Generate a SQL insert statement and returns it as a query string and a list of values to be bound as parameters. Internally, this sql_ method is used by the do_ method above.

=back

B<SQL Insert Clauses>: The above insert methods accept a hash describing the clauses of the SQL statement they are to generate, and require a value for one or more of the following keys: 

=over 4

=item named_query 

Uses the named_query catalog to build the query. May contain a defined query name, or a reference to an array of a query name followed by parameters to be handled by interpret_named_query. See L</"NAMED QUERY CATALOG"> for details.

=item sql

Optional; overrides all other arguments. May contain a plain SQL statement to be executed, or a reference to an array of a SQL statement followed by parameters for embedded placeholders.

=item table 

Required. The name of the table to insert into.

=item columns

Optional; defaults to '*'. May contain a comma-separated string of column names, or an reference to an array of column names, or a reference to a hash whose keys contain the column names, or a reference to an object with a "column_names" method.

=item values

Required. May contain a string with one or more comma-separated quoted values or expressions in SQL format, or a reference to an array of values to insert in order, or a reference to a hash whose values are to be inserted. If an array or hash reference is used, each value may either be a scalar to be used as a literal value (passed via placeholder), or a reference to a scalar to be used directly (such as a sql function or other non-literal expression).

=item sequence

Optional. May contain a string with the name of a column in the target table which should receive an automatically incremented value. If present, triggers use of the DMBS-specific do_insert_with_sequence() method, described below.

=back

B<Examples:>

=over 2

=item *

Here's a simple insert using a hash of column-value pairs:

  $sqldb->do_insert( 
    table => 'students', 
    values => { 'name'=>'Dave', 'age'=>'19', 'status'=>'minor' } 
  );

=item *

Here's the same insert using separate arrays of column names and values to be inserted:

  $sqldb->do_insert( 
    table => 'students', 
    columns => [ 'name', 'age', 'status' ], 
    values => [ 'Dave', '19', 'minor' ]
  );

=item *

Of course you can also use your own arbitrary SQL and placeholder parameters.

  $sqldb->do_insert( 
    sql=>['insert into students (id, name) values (?, ?)', 201, 'Dave']
  );

=item *

And the named_query interface is supported as well:

  $sqldb->define_named_query(
    'insert_student' => 'insert into students (id, name) values (?, ?)'
  );
  $hashes = $sqldb->do_insert( 
    named_query => [ 'insert_student', 201, 'Dave' ]
  );

=back

=cut

# $rows = $self->do_insert( %clauses );
sub do_insert {
  my $self = shift;
  my %args = @_;
  
  if ( my $seq_name = delete $args{sequence} ) {
    $self->do_insert_with_sequence( $seq_name, %args );
  } else {
    $self->do_sql( $self->sql_insert( @_ ) );
  }
}

sub sql_insert {
  my ( $self, %clauses ) = @_;

  my $keyword = 'insert';
  my ($sql, @params);

  if ( my $named = delete $clauses{'named_query'} ) {
    my %named = $self->interpret_named_query( ref($named) ? @$named : $named );
    %clauses = ( %named, %clauses );
  }

  if ( my $action = delete $clauses{'action'} ) {
    confess("Action mismatch: expecting $keyword, not $action query") 
	unless ( $action eq $keyword );
  }

  if ( my $literal = delete $clauses{'sql'} ) {
    return ( ref($literal) eq 'ARRAY' ) ? @$literal : $literal;
  }
  
  my $table = delete $clauses{'table'};
  if ( ! $table ) {
    confess("Table name is missing or empty");
  } elsif ( ! ref( $table ) and length( $table ) ) {
    # should be a single table name
  } else {
    confess("Unsupported table spec '$table'");
  }
  $sql = "insert into $table";
  
  my $columns = delete $clauses{'columns'};
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
  
  my $values = delete $clauses{'values'};
  my @value_args;
  if ( ! defined $values or ! length $values ) {
    croak("Values are missing or empty");
  } elsif ( ! ref( $values ) and length( $values ) ) {
    # should be one or more comma-separated quoted values or expressions
    @value_args = \$values;
  } elsif ( UNIVERSAL::isa( $values, 'HASH' ) ) {
    @value_args = map $values->{$_}, split /,\s?/, $columns;
  } elsif ( ref($values) eq 'ARRAY' ) {
    @value_args = @$values;
  } else {
    confess("Unsupported values spec '$values'");
  }
  ( scalar @value_args ) or croak("Values are missing or empty");    
  my @v_literals;
  my @v_params;
  foreach my $v ( @value_args ) {
    if ( ! defined($v) ) {
      push @v_literals, 'NULL';
    } elsif ( ! ref($v) ) {
      push @v_literals, '?';
      push @v_params, $v;
    } elsif ( ref($v) eq 'SCALAR' ) {
      push @v_literals, $$v;
    } else {
      Carp::confess( "Can't use '$v' as part of a sql values clause" );
    }
  }
  $values = join ', ', @v_literals;
  $sql .= " values ($values)";
  push @params, @v_params;
  
  if ( scalar keys %clauses ) {
    confess("Unsupported $keyword clauses: " . 
      join ', ', map "$_ ('$clauses{$_}')", keys %clauses);
  }
  
  $self->log_sql( $sql, @params );
  
  return( $sql, @params );
}  

########################################################################

=pod

B<Portability:> Auto-incrementing sequences are handled differently by various DBMS platforms. For example, the MySQL and MSSQL subclasses use auto-incrementing fields, Oracle and Pg use server-specific sequence objects, and AnyData and CSV make their own ad-hoc table of incrementing values.  

To standardize their use, this package defines an interface with several typical methods which may or may not be supported by individual subclasses. You may need to consult the documentation for the SQLEngine subclass and DBMS platform you're using to confirm that the sequence functionality you need is available.

=over 4

=item do_insert_with_sequence()

  $sqldb->do_insert_with_sequence( $seq_name, %sql_clauses ) : $row_count

Insert a single row into a table in the datasource, using a sequence to fill in the values of the column named in the first argument. Should return 1, unless there's an exception.

Fails with message "DBMS-Specific Function". 

Subclasses will probably want to call either the _seq_do_insert_preinc() method or the _seq_do_insert_postfetch() method, and define the appropriate other seq_* methods to support them. These two methods are not part of the public interface but instead provide a template for the two most common types of insert-with-sequence behavior. The _seq_do_insert_preinc() method first obtaines a new number from the sequence using seq_increment(), and then performs a normal do_insert(). The _seq_do_insert_postfetch() method performs a normal do_insert() and then fetches the resulting value that was automatically incremented using seq_fetch_current().

=item seq_fetch_current()

  $sqldb->seq_fetch_current( $table, $field ) : $current_value

Fetches the current sequence value.

Fails with message "DBMS-Specific Function". 

=item seq_increment()

  $sqldb->seq_increment( $table, $field ) : $new_value

Increments the sequence, and returns the newly allocated value. 

Fails with message "DBMS-Specific Function". 

=back

=cut

# $self->do_insert_with_sequence( $seq_name, %args );
sub do_insert_with_sequence {
  confess("DBMS-Specific Function")
}

# $rows = $self->_seq_do_insert_preinc( $sequence, %clauses );
sub _seq_do_insert_preinc {
  my ($self, $seq_name, %args) = @_;
  
  unless ( UNIVERSAL::isa($args{values}, 'HASH') ) {
    croak ref($self) . " insert with sequence requires values to be hash-ref"
  }
  
  $args{values}->{$seq_name} = $self->seq_increment( $args{table}, $seq_name );
  
  $self->do_insert( %args );
}

# $rows = $self->_seq_do_insert_postfetch( $sequence, %clauses );
sub _seq_do_insert_postfetch {
  my ($self, $seq_name, %args) = @_;
  
  unless ( UNIVERSAL::isa($args{values}, 'HASH') ) {
    croak ref($self) . " insert with sequence requires values to be hash-ref"
  }
  
  my $rv = $self->do_insert( %args );
  $args{values}->{$seq_name} = $self->seq_fetch_current($args{table},$seq_name);
  return $rv;
}

# $current_id = $sqldb->seq_fetch_current( $table, $field );
sub seq_fetch_current {
  confess("DBMS-Specific Function")
}

# $nextid = $sqldb->seq_increment( $table, $field );
sub seq_increment {
  confess("DBMS-Specific Function")
}

########################################################################

=head2 Update to Change Data 

=over 4

=item do_update()

  $sqldb->do_update( %sql_clauses ) : $row_count

Modify one or more rows in a table in the datasource.

=item sql_update()

  $sqldb->sql_update ( %sql_clauses ) : $sql_stmt, @params

Generate a SQL update statement and returns it as a query string and a list of values to be bound as parameters. Internally, this sql_ method is used by the do_ method above.

=back

B<SQL Update Clauses>: The above update methods accept a hash describing the clauses of the SQL statement they are to generate, and require a value for one or more of the following keys: 

=over 4

=item named_query 

Uses the named_query catalog to build the query. May contain a defined query name, or a reference to an array of a query name followed by parameters to be handled by interpret_named_query. See L</"NAMED QUERY CATALOG"> for details.

=item sql

Optional; conflicts with table, columns and values arguments. May contain a plain SQL statement to be executed, or a reference to an array of a SQL statement followed by parameters for embedded placeholders.

=item table 

Required unless sql argument is used. The name of the table to update.

=item columns

Optional unless sql argument is used. Defaults to '*'. May contain a comma-separated string of column names, or an reference to an array of column names, or a reference to a hash whose keys contain the column names, or a reference to an object with a "column_names" method.

=item values

Required unless sql argument is used. May contain a string with one or more comma-separated quoted values or expressions in SQL format, or a reference to an array of values to insert in order, or a reference to a hash whose values are to be inserted. If an array or hash reference is used, each value may either be a scalar to be used as a literal value (passed via placeholder), or a reference to a scalar to be used directly (such as a sql function or other non-literal expression).

=item criteria

Optional, but remember that ommitting this will cause all of your rows to be updated! May contain a literal SQL where clause, an array ref with a SQL clause and parameter list, a hash of field => value pairs, or an object that supports a sql_where() method. See the sql_where() method for details.

=back

B<Examples:>

=over 2

=item *

Here's a basic update statement with a hash of columns-value pairs to change:

  $sqldb->do_update( 
    table => 'students', 
    criteria => 'age > 20', 
    values => { 'status'=>'adult' } 
  );

=item *

Here's an equivalent update statement using separate lists of columns and values:

  $sqldb->do_update( 
    table => 'students', 
    criteria => 'age > 20', 
    columns => [ 'status' ], 
    values => [ 'adult' ]
  );

=item *

You can also use your own arbitrary SQL statements and placeholders:

  $sqldb->do_update( 
    sql=>['update students set status = ? where age > ?', 'adult', 20]
  );

=item *

And the named_query interface is supported as well:

  $sqldb->define_named_query(
    'update_minors' => 
	[ 'update students set status = ? where age > ?', 'adult', 20 ]
  );
  $hashes = $sqldb->do_update( 
    named_query => 'update_minors'
  );

=back

=cut

# $rows = $self->do_update( %clauses );
sub do_update {
  my $self = shift;
  $self->do_sql( $self->sql_update( @_ ) );
}

sub sql_update {
  my ( $self, %clauses ) = @_;
  
  my $keyword = 'update';
  my ($sql, @params);

  if ( my $named = delete $clauses{'named_query'} ) {
    my %named = $self->interpret_named_query( ref($named) ? @$named : $named );
    %clauses = ( %named, %clauses );
  }

  if ( my $action = delete $clauses{'action'} ) {
    confess("Action mismatch: expecting $keyword, not $action query") 
	unless ( $action eq $keyword );
  }
  
  if ( my $literal = delete $clauses{'sql'} ) {
    ($sql, @params) = ( ref($literal) eq 'ARRAY' ) ? @$literal : $literal;
    if ( my ( $conflict ) = grep $clauses{$_}, qw/ table columns values / ) { 
      croak("Can't build a $keyword query using both sql and $conflict clauses")
    }
  
  } else {
    
    my $table = delete $clauses{'table'};
    if ( ! $table ) {
      confess("Table name is missing or empty");
    } elsif ( ! ref( $table ) and length( $table ) ) {
      # should be a single table name
    } else {
      confess("Unsupported table spec '$table'");
    }
    $sql = "update $table";
  
    my $columns = delete $clauses{'columns'};
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
    
    my $values = delete $clauses{'values'};
    my @value_args;
    if ( ! $values ) {
      croak("Values are missing or empty");
    } elsif ( ! ref( $values ) and length( $values ) ) {
      confess("Unsupported values clause!");
    } elsif ( UNIVERSAL::isa( $values, 'HASH' ) ) {
      @value_args = map $values->{$_}, @columns;
    } elsif ( ref($values) eq 'ARRAY' ) {
      @value_args = @$values;
    } else {
      confess("Unsupported values spec '$values'");
    }
    ( scalar @value_args ) or croak("Values are missing or empty");    
    my @values;
    my @v_params;
    foreach my $v ( @value_args ) {
      if ( ! defined($v) ) {
	push @values, 'NULL';
      } elsif ( ! ref($v) ) {
	push @values, '?';
	push @v_params, $v;
      } elsif ( ref($v) eq 'SCALAR' ) {
	push @values, $$v;
      } else {
	Carp::confess( "Can't use '$v' as part of a sql values clause" );
      }
    }
    $sql .= " set " . join ', ', map "$columns[$_] = $values[$_]", 0 .. $#columns;
    push @params, @v_params;
  }
    
  if ( my $criteria = delete $clauses{'criteria'} || delete $clauses{'where'} ){
    ($sql, @params) = $self->sql_where($criteria, $sql, @params);
  }
  
  if ( scalar keys %clauses ) {
    confess("Unsupported $keyword clauses: " . 
      join ', ', map "$_ ('$clauses{$_}')", keys %clauses);
  }
  
  $self->log_sql( $sql, @params );
  
  return( $sql, @params );
}  

########################################################################

=head2 Delete to Remove Data

=over 4

=item do_delete()

  $sqldb->do_delete( %sql_clauses ) : $row_count

Delete one or more rows in a table in the datasource.

=item sql_delete()

  $sqldb->sql_delete ( %sql_clauses ) : $sql_stmt, @params

Generate a SQL delete statement and returns it as a query string and a list of values to be bound as parameters. Internally, this sql_ method is used by the do_ method above.

=back

B<SQL Delete Clauses>: The above delete methods accept a hash describing the clauses of the SQL statement they are to generate, and require a value for one or more of the following keys: 

=over 4

=item named_query 

Uses the named_query catalog to build the query. May contain a defined query name, or a reference to an array of a query name followed by parameters to be handled by interpret_named_query. See L</"NAMED QUERY CATALOG"> for details.

=item sql

Optional; conflicts with 'table' argument. May contain a plain SQL statement to be executed, or a reference to an array of a SQL statement followed by parameters for embedded placeholders.

=item table 

Required unless explicit "sql => ..." is used. The name of the table to delete from.

=item criteria

Optional, but remember that ommitting this will cause all of your rows to be deleted! May contain a literal SQL where clause, an array ref with a SQL clause and parameter list, a hash of field => value pairs, or an object that supports a sql_where() method. See the sql_where() method for details.

=back

B<Examples:>

=over 2

=item *

Here's a basic delete with a table name and criteria.

  $sqldb->do_delete( 
    table => 'students', criteria => { 'name'=>'Dave' } 
  );

=item *

You can use your own arbitrary SQL and placeholders:

  $sqldb->do_delete( 
    sql => [ 'delete from students where name = ?', 'Dave' ]
  );

=item *

You can combine an explicit delete statement with dynamic criteria:

  $sqldb->do_delete( 
    sql => 'delete from students', criteria => { 'name'=>'Dave' } 
  );

=item *

And the named_query interface is supported as well:

  $sqldb->define_named_query(
    'delete_by_name' => 'delete from students where name = ?'
  );
  $hashes = $sqldb->do_delete( 
    named_query => [ 'delete_by_name', 'Dave' ]
  );

=back

=cut

# $rows = $self->do_delete( %clauses );
sub do_delete {
  my $self = shift;
  $self->do_sql( $self->sql_delete( @_ ) );
}

sub sql_delete {
  my ( $self, %clauses ) = @_;

  my $keyword = 'delete';
  my ($sql, @params);

  if ( my $named = delete $clauses{'named_query'} ) {
    my %named = $self->interpret_named_query( ref($named) ? @$named : $named );
    %clauses = ( %named, %clauses );
  }

  if ( my $action = delete $clauses{'action'} ) {
    confess("Action mismatch: expecting $keyword, not $action query") 
	unless ( $action eq $keyword );
  }
  
  if ( my $literal = delete $clauses{'sql'} ) {
    ($sql, @params) = ( ref($literal) eq 'ARRAY' ) ? @$literal : $literal;
    if ( my ( $conflict ) = grep $clauses{$_}, qw/ table / ) { 
      croak("Can't build a $keyword query using both sql and $conflict clauses")
    }
  
  } else {
    
    my $table = delete $clauses{'table'};
    if ( ! $table ) {
      confess("Table name is missing or empty");
    } elsif ( ! ref( $table ) and length( $table ) ) {
      # should be a single table name
    } else {
      confess("Unsupported table spec '$table'");
    }
    $sql = "delete from $table";
  }
    
  if ( my $criteria = delete $clauses{'criteria'} || delete $clauses{'where'} ){
    ($sql, @params) = $self->sql_where($criteria, $sql, @params);
  }
  
  if ( scalar keys %clauses ) {
    confess("Unsupported $keyword clauses: " . 
      join ', ', map "$_ ('$clauses{$_}')", keys %clauses);
  }
  
  $self->log_sql( $sql, @params );
  
  return( $sql, @params );
}

########################################################################

########################################################################

=head1 DEFINING STRUCTURES (SQL DDL)

The schema of a DBI database is controlled through the Data Definition Language features of SQL.

=head2 Detect Tables and Columns

=over 4

=item detect_table_names()

  $sqldb->detect_table_names () : @table_names

Attempts to collect a list of the available tables in the database we have connected to. Uses the DBI tables() method.

=item detect_table()

  $sqldb->detect_table ( $tablename ) : @columns_or_empty
  $sqldb->detect_table ( $tablename, 1 ) : @columns_or_empty

Attempts to query the given table without retrieving many (or any) rows. Uses a server-specific "trivial" or "guaranteed" query provided by sql_detect_any. 

If succssful, the columns contained in this table are returned as an array of hash references, as described in the Column Information section below.

Catches any exceptions; if the query fails for any reason we return an empty list. The reason for the failure is logged via warn() unless an additional argument with a true value is passed to surpress those error messages.

=item sql_detect_table()

  $sqldb->sql_detect_table ( $tablename )  : %sql_select_clauses

Subclass hook. Retrieve something from the given table that is guaranteed to exist but does not return many rows, without knowning its table structure. 

Defaults to "select * from table where 1 = 0", which may not work on all platforms. Your subclass might prefer "select * from table limit 1" or a local equivalent.

=back

=cut

sub detect_table_names {
  my $self = shift;
  $self->get_dbh()->tables();
}

sub detect_table {
  my $self = shift;
  my $tablename = shift;
  my $quietly = shift;
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
    warn "Unable to detect_table $tablename: $@" unless $quietly;
    return;
  }
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

=head2 Schema Objects

=over 4

=item table()

  $sqldb->table( $tablename ) : $table

Returns a new DBIx::SQLEngine::Schema::Table object with this SQLEngine and the given table name. See L<DBIx::SQLEngine::Schema::Table> for more information on this object's interface.

=item tables()

  $sqldb->tables() : $tableset

Returns a new DBIx::SQLEngine::Schema::TableSet object containing table objects with the names discovered by detect_table_names(). See L<DBIx::SQLEngine::Schema::TableSet> for more information on this object's interface.

=back

=cut



sub table {
  require DBIx::SQLEngine::Schema::Table;
  DBIx::SQLEngine::Schema::Table->new( sqlengine => (shift), name => (shift) )
}

sub tables {
  my $self = shift;
  require DBIx::SQLEngine::Schema::TableSet;
  DBIx::SQLEngine::Schema::TableSet->new( 
    map { $self->table( $_ ) } $self->detect_table_names 
  )
}

########################################################################

=head2 Create and Drop Tables

=over 4

=item create_table()

  $sqldb->create_table( $tablename, $column_hash_ary ) 

Create a table.

The columns to be created in this table are defined as an array of hash references, as described in the Column Information section below.

=item drop_table()

  $sqldb->drop_table( $tablename ) 

Delete the named table.

=back

=cut

# $rows = $self->create_table( $tablename, $columns );
sub create_table {
  my $self = shift;
  $self->do_sql( $self->sql_create_table( @_ ) );
}
sub do_create_table { &create_table }

# $rows = $self->drop_table( $tablename );
sub drop_table {
  my $self = shift;
  $self->do_sql( $self->sql_drop_table( @_ ) );
}
sub do_drop_table { &drop_table }

=pod

B<Column Information>: The information about columns is presented as an array of hash references, each containing the following keys:

=over 4

=item *

C<name =E<gt> $column_name_string>

Defines the name of the column. 

B<Portability:> No case or length restrictions are imposed on column names, but for incresased compatibility, you may wish to stick with single-case strings of moderate length.

=item *

C<type =E<gt> $column_type_constant_string>

Specifies the type of column to create. Discussed further below.

=item *

C<required =E<gt> $not_nullable_boolean>

Indicates whether a value for this column is required; if not, unspecified or undefined values will be stored as NULL values. Defaults to false.

=item *

C<length =E<gt> $max_chars_integer>

Only applicable to column of C<type =E<gt> 'text'>. 

Indicates the maximum number of ASCII characters that can be stored in this column.

=back

B<SQL Generation>: The above do_ methods use the following sql_ methods to generate SQL DDL statements.

=over 4

=item sql_create_table()

  $sqldb->sql_create_table ($tablename, $columns) : $sql_stmt

Generate a SQL create-table statement based on the column information. Text columns are checked with sql_create_column_text_length() to provide server-appropriate types.

=item sql_drop_table()

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

sub sql_drop_table {
  my ($self, $table) = @_;
  my $sql = "drop table $table";
  $self->log_sql( $sql );
  return $sql;
}

=pod

B<Column Type Info Methods>: The following methods are used by sql_create_table to specify column information in a DBMS-specific fashion.

=over 4

=item sql_create_column_type()

  $sqldb->sql_create_column_type ( $table, $column, $columns ) : $col_type_str

Returns an appropriate 

=item dbms_create_column_types()

  $sqldb->dbms_create_column_types () : %column_type_codes

Subclass hook. Defaults to empty. Should return a hash mapping column type codes to the specific strings used in a SQL create statement for such a column. 

Subclasses should provide at least two entries, for the symbolic types referenced elsewhere in this interface, "sequential" and "binary".

=item sql_create_column_text_length()

  $sqldb->sql_create_column_text_length ( $length ) : $col_type_str

Returns "varchar(length)" for values under 256, otherwise calls dbms_create_column_text_long_type.

=item dbms_create_column_text_long_type()

  $sqldb->dbms_create_column_text_long_type () : $col_type_str

Fails with message "DBMS-Specific Function".

Subclasses should, based on the datasource's server_type, return the appropriate type of column for long text values, such as "BLOB", "TEXT", "LONGTEXT", or "MEMO".

=back

=cut

sub sql_create_columns {
  my($self, $table, $column, $columns) = @_;
  my $name = $column->{name};
  my $type = $self->sql_create_column_type( $table, $column, $columns ) ;
  if ( $type eq 'primary' ) {
    return "PRIMARY KEY ($name)";
  } else {
    return '  ' . $name . 
	    ' ' x ( ( length($name) > 31 ) ? 1 : ( 32 - length($name) ) ) .
	    $type . 
	    ( $column->{required} ? " not null" : '' );
  }
}

sub sql_create_column_type {
  my($self, $table, $column, $columns) = @_;
  my $type = $column->{type};
  
  my %dbms_types = $self->dbms_create_column_types;
  if ( my $dbms_type = $dbms_types{ $type } ) {
    $type = $dbms_type;
  }
  
  if ( $type eq 'text' ) {
    $type = $self->sql_create_column_text_length( $column->{length} || 255 ) ;
  } elsif ( $type eq 'binary' ) {
    $type = $self->sql_create_column_text_length( $column->{length} || 65535 ) ;
  }
  
  return $type;
}

sub sql_create_column_text_length {
  my $self = shift;
  my $length = shift;

  return "varchar($length)" if ($length < 256);
  return $self->dbms_create_column_text_long_type;
}

sub dbms_create_column_text_long_type {
  confess("DBMS-Specific Function")
}

sub dbms_create_column_types {
  return ()
}

########################################################################

########################################################################

=head1 ADVANCED CAPABILITIES

Not all of these capabilities will be available on all database servers.

=head2 Database Capability Information

Note: this feature has been added recently, and the interface is subject to change.

The following methods all default to returning undef, but may be overridden by subclasses to return a true or false value, indicating whether their connection has this limitation.

=over 4

=item dbms_detect_tables_unsupported()

Can the database driver return a list of tables that currently exist? (True for some simple drivers like CSV.)

=item dbms_joins_unsupported()

Does the database driver support select statements with joins across multiple tables? (True for some simple drivers like CSV.)

=item dbms_drop_column_unsupported()

Does the database driver have a problem removing a column from an existing table? (True for Postgres.)

=item dbms_column_types_unsupported()

Does the database driver store column type information, or are all columns the same type? (True for some simple drivers like CSV.)

=item dbms_null_becomes_emptystring()

Does the database driver automatically convert null values in insert and update statements to empty strings? (True for some simple drivers like CSV.)

=item dbms_emptystring_becomes_null()

Does the database driver automatically convert empty strings in insert and update statements to null values? (True for Oracle.)

=item dbms_placeholders_unsupported()

Does the database driver support having ? placehoders or not? (This is a problem for Linux users of DBD::Sybase connecting to MS SQL Servers on Windows.)

=item dbms_transactions_unsupported()

Does the database driver support real transactions with rollback and commit or not? 

=item dbms_multi_sth_unsupported()

Does the database driver support having multiple statement handles active at once or not? (This is a problem for several types of drivers.)

=item dbms_indexes_unsupported()

Does the database driver support server-side indexes or not?

=item dbms_storedprocs_unsupported()

Does the database driver support server-side stored procedures or not?

=back

=cut

sub dbms_joins_unsupported { undef }
sub dbms_detect_tables_unsupported { undef }
sub dbms_drop_column_unsupported { undef }

sub dbms_column_types_unsupported { undef }
sub dbms_null_becomes_emptystring { undef }
sub dbms_emptystring_becomes_null { undef }

sub dbms_placeholders_unsupported { undef }
sub dbms_transactions_unsupported { undef }
sub dbms_multi_sth_unsupported { undef }
sub dbms_indexes_unsupported { undef }
sub dbms_storedprocs_unsupported { undef }

########################################################################

=head2 Transactions

Note: this feature has been added recently, and the interface is subject to change.

DBIx::SQLEngine assumes auto-commit is on by default, so unless otherwise specified, each query is executed as a separate transaction. To execute multiple queries within a single transaction, use the as_one_transaction method.

=over 4

=item are_transactions_supported()

  $boolean = $sqldb->are_transactions_supported( );

Checks to see if the database has transaction support.

=item as_one_transaction()

  @results = $sqldb->as_one_transaction( $sub_ref, @args );

Will fail if we don't have transaction support.

For example:

  my $sqldb = DBIx::SQLEngine->new( ... );
  $sqldb->as_one_transaction( sub { 
    $sqldb->do_insert( ... );
    $sqldb->do_update( ... );
    $sqldb->do_delete( ... );
  } );

Or using a reference to a predefined subroutine:

  sub do_stuff {
    my $sqldb = shift;
    $sqldb->do_insert( ... );
    $sqldb->do_update( ... );
    $sqldb->do_delete( ... );
  }
  my $sqldb = DBIx::SQLEngine->new( ... );
  $sqldb->as_one_transaction( \&do_stuff, $sqldb );

=item as_one_transaction_if_supported()

  @results = $sqldb->as_one_transaction_if_supported($sub_ref, @args)

If transaction support is available, this is equivalent to as_one_transaction. If transactions are not supported, simply performs the code in $sub_ref with no transaction protection.

=back

=cut

sub are_transactions_supported {
  my $self = shift;
  my $dbh = $self->dbh;
  eval {
    local $SIG{__DIE__};
    $dbh->begin_work;
    $dbh->rollback;
  };
  return ( $@ ) ? 0 : 1;
}

sub as_one_transaction {
  my $self = shift;
  my $code = shift;

  my $dbh = $self->dbh;
  my @results;
  $dbh->begin_work;
  my $wantarray = wantarray(); # Capture before eval which otherwise obscures it
  eval {
    local $SIG{__DIE__};
    @results = $wantarray ? &$code( @_ ) : scalar( &$code( @_ ) );
    $dbh->commit;  
  };
  if ($@) {
    warn "DBIx::SQLEngine Transaction Aborted: $@";
    $dbh->rollback;
  }
  $wantarray ? @results : $results[0]
}

sub as_one_transaction_if_supported {
  my $self = shift;
  my $code = shift;
  
  my $dbh = $self->dbh;
  my @results;
  my $in_transaction;
  my $wantarray = wantarray(); # Capture before eval which otherwise obscures it
  eval {
    local $SIG{__DIE__};
    $dbh->begin_work;
    $in_transaction = 1;
  };
  eval {
    local $SIG{__DIE__};
    @results = $wantarray ? &$code( @_ ) : scalar( &$code( @_ ) );
    $dbh->commit if ( $in_transaction );
  };
  if ($@) {
    warn "DBIx::SQLEngine Transaction Aborted: $@";
    $dbh->rollback if ( $in_transaction );
  }
  $wantarray ? @results : $results[0]
}

########################################################################

=head2 Create and Drop Indexes

Note: this feature has been added recently, and the interface is subject to change.

=over 4

=item create_index()

  $sqldb->create_index( %clauses )

=item sql_create_index()

  $sqldb->sql_create_index( %clauses ) : $sql, @params

=item drop_index()

  $sqldb->drop_index( %clauses )

=item sql_drop_index()

  $sqldb->sql_drop_index( %clauses ) : $sql, @params

=back

B<Example:>

=over 2

=item *

  $sqldb->create_index( 
    table => $table_name, columns => @columns
  );

  $sqldb->drop_index( 
    table => $table_name, columns => @columns
  );

=item *

  $sqldb->create_index( 
    name => $index_name, table => $table_name, columns => @columns
  );

  $sqldb->drop_index( 
    name => $index_name
  );

=back

=cut

sub create_index { 
  my $self = shift;
  $self->do_sql( $self->sql_create_index( @_ ) );
}

sub drop_index   { 
  my $self = shift;
  $self->do_sql( $self->sql_drop_index( @_ ) );
}

sub sql_create_index { 
  my ( $self, %clauses ) = @_;

  my $keyword = 'create';
  my $obj_type = 'index';
  
  my $table = delete $clauses{'table'};
  if ( ! $table ) {
    confess("Table name is missing or empty");
  } elsif ( ! ref( $table ) and length( $table ) ) {
    # should be a single table name
  } else {
    confess("Unsupported table spec '$table'");
  }

  my $columns = delete $clauses{'column'} || delete $clauses{'columns'};
  if ( ! $columns ) {
    confess("Column names is missing or empty");
  } elsif ( ! ref( $columns ) and length( $columns ) ) {
    # should be one or more comma-separated column names
  } elsif ( UNIVERSAL::can($columns, 'column_names') ) {
    $columns = join ', ', $columns->column_names;
  } elsif ( ref($columns) eq 'ARRAY' ) {
    $columns = join ', ', @$columns;
  } else {
    confess("Unsupported column spec '$columns'");
  }
  
  my $name = delete $clauses{'name'};
  if ( ! $name ) {
    $name = join('_', $table, split(/\,\s*/, $columns), 'idx');
  } elsif ( ! ref( $name ) and length( $name ) ) {
    # should be an index name
  } else {
    confess("Unsupported name spec '$name'");
  }
  
  if ( my $unique = delete $clauses{'unique'} ) {
    $obj_type = "unique index";
  }
  
  return "$keyword $obj_type $name on $table ( $columns )";
}

sub sql_drop_index   { 
  my ( $self, %clauses ) = @_;

  my $keyword = 'create';
  my $obj_type = 'index';
    
  my $name = delete $clauses{'name'};
  if ( ! $name ) {
    my $table = delete $clauses{'table'};
    if ( ! $table ) {
      confess("Table name is missing or empty");
    } elsif ( ! ref( $table ) and length( $table ) ) {
      # should be a single table name
    } else {
      confess("Unsupported table spec '$table'");
    }
  
    my $columns = delete $clauses{'column'} || delete $clauses{'columns'};
    if ( ! $columns ) {
      confess("Column names is missing or empty");
    } elsif ( ! ref( $columns ) and length( $columns ) ) {
      # should be one or more comma-separated column names
    } elsif ( UNIVERSAL::can($columns, 'column_names') ) {
      $columns = join ', ', $columns->column_names;
    } elsif ( ref($columns) eq 'ARRAY' ) {
      $columns = join ', ', @$columns;
    } else {
      confess("Unsupported column spec '$columns'");
    }

    $name = join('_', $table, split(/\,\s*/, $columns), 'idx');
  } elsif ( ! ref( $name ) and length( $name ) ) {
    # should be an index name
  } else {
    confess("Unsupported name spec '$name'");
  }

  return "$keyword $obj_type $name";
}

########################################################################

=head2 Create and Drop Databases

Note: this feature has been added recently, and the interface is subject to change.

These methods are all subclass hooks. Fail with message "DBMS-Specific Function".

Subclasses may 

=over 4

=item create_database()

  $sqldb->create_database( $db_name )

=item drop_database()

  $sqldb->drop_database( $db_name )

=back

=cut

sub create_database { confess("DBMS-Specific Function") }
sub drop_database   { confess("DBMS-Specific Function") }

sub sql_create_database { 
  my ( $self, $name ) = @_;
  return "create database $name"
}

sub sql_drop_database { 
  my ( $self, $name ) = @_;
  return "drop database $name"
}

########################################################################

=head2 Stored Procedures

Note: this feature has been added recently, and the interface is subject to change.

These methods are all subclass hooks. Fail with message "DBMS-Specific Function".

=over 4

=item fetch_storedproc()

  $sqldb->fetch_storedproc( $proc_name, @arguments ) : $rows

=item do_storedproc()

  $sqldb->do_storedproc( $proc_name, @arguments ) : $row_count

=item create_storedproc()

  $sqldb->create_storedproc( $proc_name, $definition )

=item drop_storedproc()

  $sqldb->drop_storedproc( $proc_name )

=back

=cut

sub fetch_storedproc  { confess("DBMS-Specific Function") }
sub do_storedproc     { confess("DBMS-Specific Function") }
sub create_storedproc { confess("DBMS-Specific Function") }
sub drop_storedproc   { confess("DBMS-Specific Function") }

########################################################################

########################################################################

=head1 NAMED QUERY CATALOG

The following methods manage a collection of named query definitions. 

Note: this feature has been added recently, and the interface is subject to change.

=head2 Defining Named Queries

=over 4

=item named_queries()

  $sqldb->named_queries() : %query_names_and_info
  $sqldb->named_queries( $query_name ) : $query_info
  $sqldb->named_queries( \@query_names ) : @query_info
  $sqldb->named_queries( $query_name, $query_info, ... )
  $sqldb->named_queries( \%query_names_and_info )

Accessor and mutator for a hash mappping query names to their definitions. Created with Class::MakeMethods::Standard::Inheritable, so if called as a class method, uses class-wide methods, and if called on an instance inherits from its class but is overrideable.

=item named_query()

  $sqldb->named_query( $query_name ) : $query_info

Retrieves the query definition matching the name provided, or croaks.

=item define_named_query()

  $sqldb->define_named_query( $query_name, $query_info )

Provides a new query definition for the name provided. The query definition 
must be in one of the following formats:

=over 4

=item *

A literal SQL string. May contain placeholders to be passed as arguments.

=item *

A reference to an array of a SQL string and placeholder parameters. Parameters which should be replaced by user-supplied arguments should be represented by references to the special Perl variables $1, $2, $3, and so forth, corresponding to the argument order. 

=item *

A reference to a hash of a clauses supported by one of the SQL generation methods. Parameters which should be replaced by user-supplied arguments should be represented by references to the special Perl variables $1, $2, $3, and so forth, corresponding to the argument order. 

=item *

A reference to a subroutine or code block which will process the user-supplied arguments and return either a SQL statement, a reference to an array of a SQL statement and associated parameters, or a list of key-value pairs to be used as clauses by the SQL generation methods.

=back

See the Examples section below for illustrations of these various options.

=item define_named_queries()

  $sqldb->define_named_queries( %query_names_and_info )

Defines one or more queries, using define_named_query. 

=item define_named_query_from_text()

  $sqldb->define_named_query_from_text($query_name, $query_info_text)

Defines a query, using some special processing to facilitate storing dynamic query definitions in an external source such as a text file or database table. Query definitions which begin with a [ or { character are presumed to contain an array or hash definition and are evaluated immediately. Definitions which begin with a " or ; character are presumed to contain a code definition and evaluated as the contents of an anonymous subroutine. All evaluations are done via a Safe compartment, which is required when this function is first used, so the code is extremely limited and can not call most other functions. 

=item define_named_queries_from_text()

  $sqldb->define_named_queries_from_text(%query_names_and_info_text)

Defines one or more queries, using define_named_query_from_text. 

=item interpret_named_query()

  $sqldb->interpret_named_query( $query_name, @params ) : %clauses

Combines the query definition matching the name provided with the following arguments and returns the resulting hash of query clauses.

=back

=cut

use Class::MakeMethods ( 'Standard::Inheritable:hash' => 'named_queries' );

# $query_def = $sqldb->named_query( $name )
sub named_query {
  my ( $self, $name ) = @_;
  $self->named_queries( $name ) or croak("No query named '$name'");
}

# $sqldb->define_named_query( $name, $string_hash_or_sub )
sub define_named_query {
  my ( $self, $name, $query_def ) = @_;
  $self->named_queries( $name => $query_def )
}

sub define_named_queries {
  my $self = shift;
  while ( scalar @_ ) {
    $self->define_named_query( splice( @_, 0, 2 ) )
  }
}

# $sqldb->define_named_query_from_text( $name, $string )
my $safe_eval;
sub define_named_query_from_text {
  my ( $self, $name, $text ) = @_;
  $safe_eval ||= do {
    require Safe;
    my $compartment = Safe->new();
    $compartment->share_from( 'main', [ map { '$' . $_ } ( 1 .. 9 ) ] );
    sub { $compartment->reval( shift ) };
  };
  my $query_def = do {
    if ( $text =~ /^\s*[\[|\{]/ ) {
      &$safe_eval( $text );
    } elsif ( $text =~ /^\s*[\"|\;]/ ) {
      &$safe_eval( "sub { $text }" );
    } else {
      $text
    }
  };
  $self->define_named_query( $name, $query_def );
}

sub define_named_queries_from_text {
  my $self = shift;
  while ( scalar @_ ) {
    $self->define_named_query_from_text( splice( @_, 0, 2 ) )
  }
}

# %clauses = $sqldb->interpret_named_query( $name, @args ) 
sub interpret_named_query {
  my ( $self, $name, @query_args ) = @_;
  my $query_def = $self->named_query( $name );
  if ( ! $query_def ) {
    croak("No definition was provided for named query '$name': $query_def")
  } elsif ( ! ref $query_def ) {
    return ( sql => [ $query_def, @query_args ] );
  } elsif ( ref($query_def) eq 'ARRAY' ) {
    return ( sql => _clone_with_parameters($query_def, @query_args) );
  } elsif ( ref($query_def) eq 'HASH' ) {
    return ( %{ _clone_with_parameters($query_def, @query_args) } );
  } elsif ( ref($query_def) eq 'CODE' ) {
    my @results = $query_def->( @query_args );
    unshift @results, 'sql' if scalar(@results) == 1;
    return @results;
  } else {
    croak("Unable to interpret definition of named query '$name': $query_def")
  }
}

########################################################################

# based on Class::MakeMethods::Utility::Ref::ref_clone()

my @num_refs = map { \$_ } ( $1, $2, $3, $4, $5, $6, $7, $8, $9 );
my %num_refs = map { $num_refs[ $_ -1 ] => $_ } ( 1 .. 9 );

use vars qw( %CopiedItems @Paramaters @ParamatersUsed );

# $deep_copy = _clone_with_parameters( $value_or_ref );
sub _clone_with_parameters {
  my $item = shift;
  local @Paramaters = @_;
  local %CopiedItems = ();
  local @ParamatersUsed = ();
  my $clone = __clone_with_parameters( $item );
  if ( scalar @ParamatersUsed < scalar @Paramaters ) { 
    confess( "Too many arguments:  " . scalar(@Paramaters) . 
		    " instead of " . scalar(@ParamatersUsed));
  }
  return $clone;
}

# $copy = __clone_with_parameters( $value_or_ref );
sub __clone_with_parameters {
  my $source = shift;

  if ( my $placeholder = $num_refs{ $source } ) {
    if ( $placeholder > scalar @Paramaters ) {
      confess( "Too few arguments:  " . scalar(@Paramaters) . 
		      " instead of $placeholder");
    }
    $ParamatersUsed[ $placeholder -1 ] ++;
    return $Paramaters[ $placeholder -1 ];
  }
  
  my $ref_type = ref $source;
  return $source if (! $ref_type);
  
  return $CopiedItems{ $source } if ( exists $CopiedItems{ $source } );
  
  my $class_name;
  if ( "$source" =~ /^\Q$ref_type\E\=([A-Z]+)\(0x[0-9a-f]+\)$/ ) {
    $class_name = $ref_type;
    $ref_type = $1;
  }
  
  my $copy;
  if ($ref_type eq 'SCALAR') {
    $copy = \( $$source );
  } elsif ($ref_type eq 'REF') {
    $copy = \( __clone_with_parameters($$source) );
  } elsif ($ref_type eq 'HASH') {
    $copy = { map { __clone_with_parameters($_) } %$source };
  } elsif ($ref_type eq 'ARRAY') {
    $copy = [ map { __clone_with_parameters($_) } @$source ];
  } else {
    $copy = $source;
  }
  
  bless $copy, $class_name if $class_name;
  
  $CopiedItems{ $source } = $copy;
  
  return $copy;
}

########################################################################

=head2 Executing Named Queries

=over 4

=item fetch_named_query()

  $sqldb->fetch_named_query( $query_name, @params ) : $rows
  $sqldb->fetch_named_query( $query_name, @params ) : ( $rows, $columns )

Calls fetch_select using the named query and arguments provided.

=item visit_named_query()

  $sqldb->visit_named_query($query_name, @params, $code) : @results
  $sqldb->visit_named_query($code, $query_name, @params) : @results

Calls visit_select using the named query and arguments provided.

=item do_named_query()

  $sqldb->do_named_query( $query_name, @params ) : $row_count

Calls do_query using the named query and arguments provided.

=back

B<Examples:>

=over 2

=item *

A simple named query can be defined in SQL or as generator clauses:

  $sqldb->define_named_query('all_students', 'select * from students');
  $sqldb->define_named_query('all_students', { table => 'students' });

The results of a named select query can be retrieved in several equivalent ways:

  $rows = $sqldb->fetch_named_query( 'all_students' );
  $rows = $sqldb->fetch_select( named_query => 'all_students' );
  @rows = $sqldb->visit_select( named_query => 'all_students', sub { $_[0] } );

=item *

There are numerous ways of defining a query which accepts parameters; any of the following are basically equivalent:

  $sqldb->define_named_query('student_by_id', 
			'select * from students where id = ?' );
  $sqldb->define_named_query('student_by_id', 
	      { sql=>['select * from students where id = ?', \$1 ] } );
  $sqldb->define_named_query('student_by_id', 
	      { table=>'students', criteria=>[ 'id = ?', \$1 ] } );
  $sqldb->define_named_query('student_by_id', 
	      { table=>'students', criteria=>{ 'id' => \$1 } } );
  $sqldb->define_named_query('student_by_id', 
    { action=>'select', table=>'students', criteria=>{ 'id'=>\$1 } } );

Using a named query with parameters requires that the arguments be passed after the name:

  $rows = $sqldb->fetch_named_query( 'student_by_id', $my_id );
  $rows = $sqldb->fetch_select(named_query=>['student_by_id', $my_id]);

If the query is defined using a plain string, as in the first line of the student_by_id example, no checking is done to ensure that the correct number of parameters have been passed; the result will depend on your database server, but will presumably be a fatal error. In contrast, the definitions that use the \$1 format will have their parameters counted and arranged before being executed.

=item *

Queries which insert, update, or delete can be defined in much the same way as select queries are; again, all of the following are roughly equivalent:

  $sqldb->define_named_query('delete_student', 
			    'delete from students where id = ?');
  $sqldb->define_named_query('delete_student', 
		    [ 'delete from students where id = ?', \$1 ]);
  $sqldb->define_named_query('delete_student', 
    { action=>'delete', table=>'students', criteria=>{ id=>\$1 } });

These modification queries can be invoked with one of the do_ methods:

  $sqldb->do_named_query( 'delete_student', 201 );
  $sqldb->do_query(  named_query => [ 'delete_student', 201 ] );
  $sqldb->do_delete( named_query => [ 'delete_student', 201 ] );

=item *

Queries can be defined using subroutines:

  $sqldb->define_named_query('name_search', sub {
    my $name = lc( shift );
    return "select * from students where name like '%$name%'"
  });

  $rows = $sqldb->fetch_named_query( 'name_search', 'DAV' );

=item *

Query definitions can be stored in external text files or database tables and then evaluated into data structures or code references.

  open( QUERIES, '/path/to/my/queries' );
  my %queries = map { split ':', $_, 2 } <QUERIES>;
  close QUERIES;

  $sqldb->define_named_queries_from_text( %queries );

Placing the following text in the target file will define all of the queries used above:

  all_students: select * from students
  student_by_id: [ 'select * from students where id = ?', \$1 ]
  delete_student: { action => 'delete', table => 'students', criteria => { id => \$1 } });
  name_search: "select * from students where name like '%\L$_[0]\E%'"

=back

=cut

# ( $row_hashes, $column_hashes ) = $sqldb->fetch_named_query( $name, @args )
sub fetch_named_query {
  (shift)->fetch_select( named_query => [ @_ ] );
}

# @results = $sqldb->visit_named_query( $name, @args, $code_ref )
sub visit_named_query {
  (shift)->visit_select( ( ref($_[0]) ? shift : pop ), named_query => [ @_ ] );
}

# $result = $sqldb->do_named_query( $name, @args )
sub do_named_query {
  (shift)->do_query( named_query => [ @_ ] );
}

########################################################################

# $row_count = $sqldb->do_query( %clauses );
sub do_query {
  my ( $self, %clauses ) = @_;

  if ( my $named = delete $clauses{'named_query'} ) {
    my %named = $self->interpret_named_query( ref($named) ? @$named : $named );
    %clauses = ( %named, %clauses );
  }

  my ($sql, @params);
  if ( my $action = delete $clauses{'action'} ) {
    my $method = "sql_$action";
    ($sql, @params) = $self->$method( %clauses );

  } elsif ( my $literal = delete $clauses{'sql'} ) {
    ($sql, @params) = ( ref($literal) eq 'ARRAY' ) ? @$literal : $literal;
  
  } else {
    croak( "Can't call do_query without either action or sql clauses" );
  }

  $self->do_sql( $sql, @params );
}

########################################################################

########################################################################

=head1 GENERIC QUERY EVALUTION

These methods allow arbitrary SQL statements to be executed.

B<Portability:> Note that no processing of the SQL query string is
performed, so if you call these low-level functions it is up to
you to ensure that the query is correct and will function as expected
when passed to whichever data source the SQLEngine is using.

=head2 SQL Query Methods

  $db->do_sql('insert into table values (?, ?)', 'A', 1);
  my $rows = $db->fetch_sql('select * from table where status = ?', 2);

Execute and fetch some kind of result from a given SQL statement.  Internally, these methods are used by the other do_, fetch_ and visit_ methods described above.

=over 4

=item do_sql()

  $sqldb->do_sql ($sql, @params) : $rowcount 

Execute a SQL query by sending it to the DBI connection, and returns the number of rows modified, or -1 if unknown.

=item fetch_sql()

  $sqldb->fetch_sql ($sql, @params) : $row_hash_ary
  $sqldb->fetch_sql ($sql, @params) : ( $row_hash_ary, $columnset )

Execute a SQL query by sending it to the DBI connection, and returns any rows that were produced, as an array of hashrefs, with the values in each entry keyed by column name. If called in a list context, also returns a reference to an array of information about the columns returned by the query.

=item fetch_sql_rows()

  $sqldb->fetch_sql_rows ($sql, @params) : $row_ary_ary

Execute a SQL query by sending it to the DBI connection, and returns any rows that were produced, as an array of arrays, with the values in each entry keyed by column order. If called in a list context, also returns a reference to an array of information about the columns returned by the query.

=item visit_sql()

  $sqldb->visit_sql ($coderef, $sql, @params) : @results
  $sqldb->visit_sql ($sql, @params, $coderef) : @results

Similar to fetch_sql, but calls your coderef on each row, passing it as a hashref, and returns the results of each of those calls. For your convenience, will accept a coderef as either the first or the last argument.

=item visit_sql_rows()

  $sqldb->visit_sql ($coderef, $sql, @params) : @results
  $sqldb->visit_sql ($sql, @params, $coderef) : @results

Similar to fetch_sql, but calls your coderef on each row, passing it as a list of values, and returns the results of each of those calls. For your convenience, will accept a coderef as either the first or the last argument.

=back

=cut

# $rowcount = $self->do_sql($sql);
# $rowcount = $self->do_sql($sql, @params);
sub do_sql {
  (shift)->try_query( (shift), [ @_ ], 'get_execute_rowcount' )  
}

# $array_of_hashes = $self->fetch_sql($sql);
# $array_of_hashes = $self->fetch_sql($sql, @params);
# ($array_of_hashes, $columns) = $self->fetch_sql($sql);
sub fetch_sql {
  (shift)->try_query( (shift), [ @_ ], 'fetchall_hashref_columns' )  
}

# $array_of_arrays = $self->fetch_sql_rows($sql);
# $array_of_arrays = $self->fetch_sql_rows($sql, @params);
# ($array_of_arrays, $columns) = $self->fetch_sql_rows($sql);
sub fetch_sql_rows {
  (shift)->try_query( (shift), [ @_ ], 'fetchall_arrayref' )  
}

# @results = $self->visit_sql($coderef, $sql, @params);
# @results = $self->visit_sql($sql, @params, $coderef);
sub visit_sql {
  my $self = shift;
  my $coderef = ( ref($_[0]) ? shift : pop );
  $self->try_query( (shift), [ @_ ], 'visitall_hashref', $coderef )
}

# @results = $self->visit_sql_rows($coderef, $sql, @params);
# @results = $self->visit_sql_rows($sql, @params, $coderef);
sub visit_sql_rows {
  my $self = shift;
  my $coderef = ( ref($_[0]) ? shift : pop );
  $self->try_query( (shift), [ @_ ], 'visitall_array', $coderef )
}

########################################################################

########################################################################

=head1 INTERNAL CONNECTION METHODS (DBI DBH)

The following methods manage the DBI database handle through which we communicate with the datasource.

=head2 Accessing the DBH

=over 4

=item get_dbh()

  $sqldb->get_dbh () : $dbh

Get the current DBH

=item dbh_func()

  $sqldb->dbh_func ( $func_name, @args ) : @results

Calls the DBI func() method on the database handle returned by get_dbh, passing the provided function name and arguments. See the documentation for your DBD driver to learn which functions it supports.

=back

=cut

sub get_dbh {
  # maybe add code here to check connection status.
  # or maybe add check once every 10 get_dbh's...
  my $self = shift;
  ( ref $self ) or ( confess("Not a class method") );
  return $self->{dbh};
}

sub dbh_func {
  my $self = shift;
  my $dbh = $self->get_dbh;
  my $func = shift;
  $dbh->func( $func, @_ );
}

########################################################################

=head2 Initialization and Reconnection

=over 4

=item _init()

  $sqldb->_init () 

Empty subclass hook. Called by DBIx::AnyDBD after connection is made and class hierarchy has been juggled.

=item reconnect()

  $sqldb->reconnect () 

Attempt to re-establish connection with original parameters

=item check_or_reconnect()

  $sqldb->check_or_reconnect () : $dbh

Confirms the current DBH is available with detect_any() or reconnect().

=back

=cut

sub _init {  }

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

sub check_or_reconnect {
  my $self = shift;
  $self->detect_any or $self->reconnect;
  $self->get_dbh or confess("Failed to get_dbh after check_or_reconnect")
}

########################################################################

=head2 Checking For Connection

To determine if the connection is working.

=over 4

=item detect_any()

  $sqldb->detect_any () : $boolean
  $sqldb->detect_any ( 1 ) : $boolean

Attempts to confirm that values can be retreived from the database,
allowing us to determine if the connection is working, using a
server-specific "trivial" or "guaranteed" query provided by
sql_detect_any.

Catches any exceptions; if the query fails for any reason we return
a false value. The reason for the failure is logged via warn()
unless an additional argument with a true value is passed to surpress
those error messages.

=back

=cut

sub detect_any {
  my $self = shift;
  my $quietly = shift;
  my $result = 0;
  eval {
    local $SIG{__DIE__};
    $self->fetch_one_value($self->sql_detect_any);
    $result = 1;
  };
  $result or warn "Unable to detect_any: $@" unless $quietly;
  return $result;
}

=pod 

B<SQL Generation>: The above detect_ method uses the following sql_ method to generate SQL statements.

=over 4

=item sql_detect_any()

  $sqldb->sql_detect_any : %sql_select_clauses

Subclass hook. Retrieve something from the database that is guaranteed to exist. 
Defaults to SQL literal "select 1", which may not work on all platforms. Your database driver might prefer something else, like Oracle's "select 1 from dual".

=back

=cut

sub sql_detect_any {
  return ( sql => 'select 1' )
}

########################################################################

########################################################################

=head1 INTERNAL STATEMENT METHODS (DBI STH)

The following methods manipulate DBI statement handles as part of processing queries and their results.

=cut

########################################################################

=head2 Statement Error Handling 

=over 4

=item try_query()

  $sqldb->try_query ( $sql, \@params, $result_method, @result_args ) : @results

Error handling wrapper around the internal execute_query method.

The $result_method should be the name of a method supported by that
SQLEngine instance, typically one of those shown in the "Retrieving
Rows from an Executed Statement" section below. The @result_args,
if any, are passed to the named method along with the active
statement handle.

=item catch_query_exception()

  $sqldb->catch_query_exception ( $exception, $sql, \@params, 
			$result_method, @result_args ) : $resolution

Exceptions are passed to catch_query_exception; if it returns "REDO"
the query will be retried up to five times. The superclass checks
the error message against the recoverable_query_exceptions; subclasses
may wish to override this to provide specialized handling.

=item recoverable_query_exceptions()

  $sqldb->recoverable_query_exceptions() : @common_error_messages

Subclass hook. Defaults to empty. Subclasses may provide a list of
error messages which represent common communication failures or
other incidental errors.

=back

=cut

# $results = $self->try_query($sql, \@params, $result_method, @result_args);
# @results = $self->try_query($sql, \@params, $result_method, @result_args);
sub try_query {
  my $self = shift;
  
  my $attempts = 0;
  my @results;
  my $wantarray = wantarray(); # Capture before eval which otherwise obscures it
  ATTEMPT: {
    $attempts ++;
    eval {
      local $SIG{__DIE__};

      @results = $wantarray ? $self->execute_query(@_)
		     : scalar $self->execute_query(@_);
    };
    if ( my $error = $@ ) {
      my $catch = $self->catch_query_exception($error, @_);
      if ( ! $catch ) {
	die "DBIx::SQLEngine Query failed: $_[0]\n$error\n";
      } elsif ( $catch eq 'OK' ) {
	return;
      } elsif ( $catch eq 'REDO' ) {
	if ( $attempts < 5 ) {
	  warn "DBIx::SQLEngine Retrying query after failure: $_[0]\n$error";
	  redo ATTEMPT;
	} else {
	  confess("DBIx::SQLEngine Query failed on $attempts consecutive attempts: $_[0]\n$error\n");
	}
      } else {
	confess("DBIx::SQLEngine Query failed: $_[0]\n$error" . 
		"Unknown return from exception handler '$catch'");
      }
    }
    $wantarray ? @results : $results[0]
  }
}

sub catch_query_exception {
  my $self = shift;
  my $error = shift;
  
  foreach my $pattern ( $self->recoverable_query_exceptions() ) {  
    if ( $error =~ /$pattern/i ) {
      $self->reconnect() and return 'REDO';
    }
  }
  
  return;
}

sub recoverable_query_exceptions {
  return ()
}

########################################################################

=head2 Statement Handle Lifecycle 

These are internal methods for query operations

=over 4

=item execute_query()

  $sqldb->execute_query($sql, \@params, $result_method, @result_args) : @results

This overall lifecycle method calls prepare_execute(), runs the $result_method, and then calls done_with_query().

The $result_method should be the name of a method supported by that SQLEngine instance, typically one of those shown in the "Retrieving Rows from an Executed Statement" section below. The @result_args, if any, are passed to the named method along with the active statement handle.

=item prepare_execute()

  $sqldb->prepare_execute ($sql, @params) : $sth

Prepare, bind, and execute a SQL statement to create a DBI statement handle.

Uses prepare_cached(), bind_param(), and execute(). 

If you need to pass type information with your parameters, pass a reference to an array of the parameter and the type information.

=item done_with_query()

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
    
  my ( $sth, @results );
  my $wantarray = wantarray(); # Capture before eval which otherwise obscures it
  eval {
    local $SIG{__DIE__};
    $sth = $self->prepare_execute( @query );
    @results = $wantarray ? ( $self->$method( $sth, @args ) )
		   : scalar ( $self->$method( $sth, @args ) );
  };
  if ( $@ ) {
    $self->done_with_query($sth) if $sth;
    $self->log_stop( $timer, "ERROR: $@" ) if $self->DBILogging;
    die $@;
  } else {
    $self->done_with_query($sth);
    
    $self->log_stop( $timer, \@results ) if $self->DBILogging;
    
    return ( $wantarray ? @results : $results[0] )
  }
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

=item do_nothing()

  $sqldb->do_nothing ($sth) : ()

Does nothing. 

=item get_execute_rowcount()

  $sqldb->get_execute_rowcount ($sth) : $row_count

Returns the row count reported by the last statement executed.

=item fetchall_arrayref()

  $sqldb->fetchall_arrayref ($sth) : $array_of_arrays

Calls the STH's fetchall_arrayref method to retrieve all of the result rows into an array of arrayrefs.

=item fetchall_hashref()

  $sqldb->fetchall_hashref ($sth) : $array_of_hashes

Calls the STH's fetchall_arrayref method with an empty hashref to retrieve all of the result rows into an array of hashrefs.

=item fetchall_hashref_columns()

  $sqldb->fetchall_hashref ($sth) : $array_of_hashes, $column_info

Calls the STH's fetchall_arrayref method with an empty hashref, and also retrieves information about the columns used in the query result set.

=item visitall_hashref()

  $sqldb->visitall_hashref ($sth, $coderef) : ()

Calls coderef on each row with values as hashref; does not return them.

=item visitall_array()

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
  wantarray ? ( $sth->fetchall_arrayref( {} ), $self->retrieve_columns( $sth ) )
	    :   $sth->fetchall_arrayref( {} );
}

# $self->visitall_hashref( $sth, $coderef );
  # Calls a codref for each row returned by the statement handle
sub visitall_hashref {
  my ($self, $sth, $coderef) = @_;
  my $rowhash;
  my @results;
  while ($rowhash = $sth->fetchrow_hashref) {
    push @results, &$coderef( $rowhash );
  }
  return @results;
}

# $self->visitall_array( $sth, $coderef );
  # Calls a codref for each row returned by the statement handle
sub visitall_array {
  my ($self, $sth, $coderef) = @_;
  my @row;
  my @results;
  while (@row = $sth->fetchrow_hashref) {
    push @results, &$coderef( @row );
  }
  return @results;
}


########################################################################

=head2 Retrieving Columns from a Statement

=over 4

=item retrieve_columns()

  $sqldb->retrieve_columns ($sth) : $columnset

Obtains information about the columns used in the result set.

=item column_type_codes()

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
  my $types = eval { $sth->{'TYPE'} || [] };
  # warn "Types: " . join(', ', map "'$_'", @$types);
  my $type_codes = [ map { 
	my $typeinfo = scalar $self->type_info($_);
	# warn "Type $typeinfo";
	scalar $typeinfo->{'DATA_TYPE'} 
  } @$types ];
  my $sizes = eval { $sth->{PRECISION} || [] };
  my $nullable = eval { $sth->{'NULLABLE'} || [] };
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

########################################################################

=head1 LOGGING

=over 4

=item DBILogging()

  $sqldb->DBILogging : $value
  $sqldb->DBILogging( $value )

Set this to a true value to turn on logging of DBI interactions. Can be called on the class to set a shared default for all instances, or on any instance to set the value for it alone.

=item log_connect()

  $sqldb->log_connect ( $dsn )

Writes out connection logging message.

=item log_start()

  $sqldb->log_start( $sql ) : $timer

Called at start of query execution.

=item log_stop()

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
# $self->log_stop( $timer, $error_message );
# $self->log_stop( $timer, @$return_values );
sub log_stop { 
  my ($self, $start_time, $results) = @_;
  my $class = ref($self) || $self;
  
  my $message;
  if ( ! ref $results ) {
    $message = "error: $results";
  } elsif ( ref($results) eq 'ARRAY' ) {
    # Successful return
    if ( ref( $results->[0] ) eq 'ARRAY' ) {
      $message = scalar(@{ $results->[0] }) . " items";
    }
  }
  my $seconds = (time() - $start_time or 'less than one' );
  
  warn "DBI: Completed in $seconds seconds" . 
	(defined $message ? ", returning $message" : '') . "\n";
  
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

=over 4

=item SQLLogging()

  $sqldb->SQLLogging () : $value 
  $sqldb->SQLLogging( $value )

Set this to a true value to turn on logging of internally-generated SQL statements (all queries except for those with complete SQL statements explicitly passed in by the caller). Can be called on the class to set a shared default for all instances, or on any instance to set the value for it alone.

=item log_sql()

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

########################################################################

=head1 EXAMPLE

This example, based on a writeup by Ron Savage, shows a connection being opened, a table created, several rows of data inserted, and then retrieved again:

  #!/usr/bin/perl
  
  use strict;
  use warnings;
  
  use DBIx::SQLEngine;
  
  eval {
    my $engine = DBIx::SQLEngine->new(
      'DBI:mysql:test:127.0.0.1', 'route', 'bier',
      {
	RaiseError => 1,
	ShowErrorStatement => 1,
      }
    );
    my $table_name = 'sqle';
    my $columns = [
      {
	name   => 'sqle_id',
	type   => 'sequential',
      },
      {
	name   => 'sqle_name',
	type   => 'text',
	length => 255,
      },
    ];
    $engine->drop_table($table_name);
    $engine->create_table($table_name, $columns);
  
    $engine->do_insert(table => $table_name, values => {sqle_name => 'One'});
    $engine->do_insert(table => $table_name, values => {sqle_name => 'Two'});
    $engine->do_insert(table => $table_name, values => {sqle_name => 'Three'});
  
    my $dataset = $engine->fetch_select(table => $table_name);
    my $count = 0;
    for my $data (@$dataset) {
      $count++;
      print "Row $count: ", map( {"\t$_ => " . 
	(defined $$data{$_} ? $$data{$_} : 'NULL')} sort keys %$data), "\n";
    }
  };
  if ( $@ ) {
    warn "Unable to build sample table: $@";
  }          

=head1 BUGS

Many types of database servers are not yet supported.

Database driver/server combinations that do not support placeholders
will fail.
(http://groups.google.com/groups?selm=dftza.3519%24ol.117790%40news.chello.at)

See L<DBIx::SQLEngine::ToDo> for additional bugs and missing
features.


=head1 SEE ALSO 

See L<DBIx::SQLEngine::ReadMe> for distribution and support information.

See L<DBI> and the various DBD modules for information about the underlying database interface.

See L<DBIx::AnyDBD> for details on the dynamic subclass selection mechanism.


=head1 CREDITS AND COPYRIGHT

=head2 Author

Developed by Matthew Simon Cavalletto at Evolution Softworks.

You may contact the author directly at C<evo@cpan.org> or
C<simonm@cavalletto.org>. More free Perl software is available at
C<www.evoscript.org>.

=head2 Contributors 

Many thanks to the kind people who have contributed code and other feedback:

  Eric Schneider, Evolution Online Systems
  E. J. Evans, Evolution Online Systems
  Matthew Sheahan, Evolution Online Systems
  Eduardo Iturrate, Evolution Online Systems
  Ron Savage
  Christian Glahn, Innsbruck University
  Michael Kroll, Innsbruck University

=head2 Source Material

Inspiration, tricks, and bits of useful code were taken from these CPAN modules:

  DBIx::AnyDBD
  DBIx::Compat
  DBIx::Datasource
  DBIx::Renderer

=head2 Copyright

Copyright 2001, 2002, 2003, 2004 Matthew Cavalletto. 

Portions copyright 1998, 1999, 2000, 2001 Evolution Online Systems, Inc.

Portions copyright 2002 ZID, Innsbruck University (Austria).

Portions of the documentation are copyright 2003 Ron Savage.

=head2 License

You may use, modify, and distribute this software under the same terms as Perl.

=cut

########################################################################

1;
