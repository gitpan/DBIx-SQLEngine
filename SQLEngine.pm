package DBIx::SQLEngine;

$VERSION = 0.005;

use strict;
use Carp;

use DBI;
use DBIx::AnyDBD;
use Class::MakeMethods;

use DBIx::SQLEngine::Default;

sub new { &DBIx::SQLEngine::Default::new_connection }

1;

__END__

########################################################################


=head1 NAME

DBIx::SQLEngine - Extends DBI with high-level operations


=head1 SYNOPSIS

  my $sqldb = DBIx::SQLEngine->new( $DBIConnectionString );
  
  $sqldb->do_insert( 
    table => 'students', 
    values => { 'name'=>'Dave', 'age'=>'19', 'status'=>'minor' } 
  );
  
  $hashes = $sqldb->fetch_select( 
    table => 'students', criteria => { 'status'=>'minor' } 
  );
  
  $sqldb->do_update( 
    table => 'students', criteria => 'age > 20', 
    values => { 'status'=>'adult' } 
  );
  
  $sqldb->do_delete( 
    table => 'students', criteria => { 'name'=>'Dave' } 
  );


=head1 DESCRIPTION

The DBIx::SQLEngine class provides an extended interface for the DBI database interface, adding methods that support ad-hoc SQL generation and query execution in a single call.

Behind the scenes, different subclasses are instantiated depending on the type of server to which you connect, thanks to DBIx::AnyData. As a result, SQL dialect ideosyncracies can be compensated for; this release includes subclasses supporting the MySQL, Pg, AnyData, and CSV drivers.


=head1 INTERFACE

=head2 Connection Setup

Create one SQLEngine for each DBI datasource you will use.

=over 4

=item new

  DBIx::SQLEngine->new( $dsn ) : $sqldb
  DBIx::SQLEngine->new( $dsn, $user, $pass ) : $sqldb
  DBIx::SQLEngine->new( $dsn, $user, $pass, $args ) : $sqldb

Accepts the same arguments as the standard DBI connect method. 

=back

=head2 Retrieving Data

The following methods retrive data from the datasource using SQL select statements.

=over 4

=item fetch_select

  $sqldb->fetch_select( %sql_clauses ) : $row_hashes
  $sqldb->fetch_select( %sql_clauses ) : ( $row_hashes, $column_hashes )

Retrieve rows from the datasource as an array of hashrefs. If called in a list context, also returns an array of hashrefs containing information about the columns included in the result set.

I<Argument Pairs:>

=over 4

=item sql

Optional; overrides all other arguments. May contain a plain SQL statement to be executed, or a reference to an array of a SQL statement followed by parameters for embedded placeholders.

=item table I<or> tables

Required (unless explicit "sql => ..." is used). The name of the tables to select from.

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

I<Examples:>

=over 2

=item *

  $hashes = $sqldb->fetch_select( 
    sql => 'select * from students where id > 200'
  );

=item *

  $hashes = $sqldb->fetch_select( 
    sql => [ 'select * from students where id > ?', 200 ]
  );

=item *

  $hashes = $sqldb->fetch_select( 
    table => 'students', criteria => { 'status'=>'minor' } 
  );

=item *

  $hashes = $sqldb->fetch_select( 
    table => 'students', columns => 'name, age', order => 'name'
  );

=item *

  $hashes = $sqldb->fetch_select( 
    tables => 'students, grades', 
    criteria => 'students.id = grades.student_id',
    order => 'students.name'
  );

=back

=item visit_select

  $sqldb->visit_select( $code_ref, %sql_clauses ) : @results

Takes the same arguments as fetch_select. Retrieve rows from the datasource as a series of hashrefs, and call the user provided function for each one. Returns the results returned by each of those function calls. This can allow for more efficient processing if you are processing a large number of rows and do not need to keep them all in memory.

I<Examples:>

=over 2

=item *

  $sqldb->visit_select( 
    sub {
      my $student = shift;
      ... do something with %$student ...
    }, 
    table => 'student'
  );

=item *

   $sqldb->visit_select( 
    sub {
      my $student = shift;
      ... do something with $student->{id} and $student->{name} ...
    }, 
    table => 'student', columns => 'id, name', order => 'name, id desc'
  );

=back

=item fetch_one_row

  $sqldb->fetch_one_row( %sql_clauses ) : $row_hash

Calls fetch_select, then returns only the first row of results.

I<Examples:>

=over 2

=item *

  $joe = $sqldb->fetch_one_row( 
    table => 'student', criteria => { 'id' => 201 }
  );

=item *

  $joe = $sqldb->fetch_one_row( 
    sql => [ 'select * from students where id = ?', 201 ]
  );

=back

=item fetch_one_value

  $sqldb->fetch_one_value( %sql_clauses ) : $scalar

Calls fetch_select, then returns a single value from the first row of results.

I<Examples:>

=over 2

=item *

  $maxid = $sqldb->fetch_one_value( 
    sql => 'select max(id) from students where status = ?'
  );

=item *

  $count = $sqldb->fetch_one_value( 
    table => 'student', columns => 'count(*)'
  );

=back

=back

=head2 Modifying Data

=over 4

=item do_insert( %sql_clauses ) 

  $sqldb->do_insert( %sql_clauses ) 

Insert a single row into a table in the datasource.

I<Argument Pairs:>

=over 4

=item sql

Optional; overrides all other arguments. May contain a plain SQL statement to be executed, or a reference to an array of a SQL statement followed by parameters for embedded placeholders.

=item table 

Required (unless explicit "sql => ..." is used). The name of the table to insert into.

=item columns

Optional; defaults to '*'. May contain a comma-separated string of column names, or an reference to an array of column names, or a reference to a hash whose keys contain the column names, or a reference to an object with a "column_names" method.

=item values

Required. May contain a string with one or more comma-separated quoted values or expressions in SQL format, or a reference to an array of values to insert in order, or a reference to a hash whose values are to be inserted.

=back

I<Examples:>

=over 2

=item *

  $sqldb->do_insert( 
    table => 'students', 
    values => { 'name'=>'Dave', 'age'=>'19', 'status'=>'minor' } 
  );

=item *

  $sqldb->do_insert( 
    table => 'students', 
    columns => [ 'name', 'age', 'status' ], 
    values => [ 'Dave', '19', 'minor' ]
  );

=item *

  $sqldb->fetch_one_row( 
    sql => [ 'insert into students (id, name) values (?, ?)', 201, 'Dave' ]
  );

=back


=item do_update ( %sql_clauses ) 

Modify one or more rows in a table in the datasource.

I<Argument Pairs:>

=over 4

=item sql

Optional; overrides all other arguments. May contain a plain SQL statement to be executed, or a reference to an array of a SQL statement followed by parameters for embedded placeholders.

=item table 

Required (unless explicit "sql => ..." is used). The name of the table to insert into.

=item columns

Optional; defaults to '*'. May contain a comma-separated string of column names, or an reference to an array of column names, or a reference to a hash whose keys contain the column names, or a reference to an object with a "column_names" method.

=item values

Required. May contain a string with one or more comma-separated quoted values or expressions in SQL format, or a reference to an array of values to insert in order, or a reference to a hash whose values are to be inserted.

=item criteria

Optional, but remember that ommitting this will cause all of your rows to be updated! May contain a literal SQL where clause (everything after there word "where"), or a reference to an array of a SQL string with embedded placeholders followed by the values that should be bound to those placeholders. 

If the criteria argument is a reference to hash, it is treated as a set of field-name => value pairs, and a SQL expression is created that requires each one of the named fields to exactly match the value provided for it, or if the value is an array reference to match any one of the array's contents; see L<DBIx::SQLEngine::Criteria::HashGroup> for details.

Alternately, if the criteria is an object which supports a sql_where() method, the results of that method will be used; see L<DBIx::SQLEngine::Criteria> for classes with this behavior.

=back

I<Examples:>

=over 2

=item *

  $sqldb->do_update( 
    table => 'students', 
    criteria => 'age > 20', 
    values => { 'status'=>'adult' } 
  );

=item *

  $sqldb->do_update( 
    table => 'students', 
    criteria => 'age > 20', 
    columns => [ 'status' ], 
    values => [ 'adult' ]
  );

=item *

  $sqldb->fetch_one_row( 
    sql => [ 'update students set status = ? where age > ?', 'adult', 20 ]
  );

=back

=item do_delete ( %sql_clauses ) 

Delete one or more rows in a table in the datasource.

I<Argument Pairs:>

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

I<Examples:>

=over 2

=item *

  $sqldb->do_delete( 
    table => 'students', criteria => { 'name'=>'Dave' } 
  );

=item *

  $sqldb->fetch_one_row( 
    sql => [ 'delete from students where name = ?', 'Dave' ]
  );

=back

=back

=head2 Checking For Existence

To determine if the connection is working and whether a table exists.

=over 4

=item detect_any

  $sqldb->detect_any () : $boolean

Attempts to confirm that values can be retreived from the database, using a server-specific "trivial" or "guaranteed" query provided by the subclass.
Catches any exceptions; if the query fails for any reason we return nothing.

=item detect_table

  $sqldb->detect_table ( $tablename ) : @columns_or_empty

Attempts to query the given table without retrieving many (or any) rows. Uses a server-specific "trivial" or "guaranteed" query provided by the subclass. 
Catches any exceptions; if the query fails for any reason we return nothing.

=back

=head2 Create and Drop Tables

=over 4

=item do_create_table  

  $sqldb->do_create_table( $tablename, $column_hash_ary ) 

Create a table.

=item do_drop_table  

  $sqldb->do_drop_table( $tablename ) 

Delete a table.

=back

=head2 Logging

=over 4

=item DBILogging 

  $sqldb->DBILogging : $value
  $sqldb->DBILogging( $value )

Set this to a true value to turn on logging. Can be called on the class to set a shared default for all instances, or on any instance to set the value for it alone.

=item SQLLogging

  $sqldb->SQLLogging () : $value 
  $sqldb->SQLLogging( $value )

Set this to a true value to turn on logging of internally-generated SQL statements (all queries except for those with complete SQL statements explicitly passed in by the caller). Can be called on the class to set a shared default for all instances, or on any instance to set the value for it alone.

=back


=head1 SEE ALSO 

See L<DBIx::SQLEngine::Default> for implementation details.

See L<DBIx::SQLEngine::ReadMe> for distribution information.

See L<DBI> and the various DBD modules for information about the underlying database interface.

See L<DBIx::AnyDBD> for details on the dynamic subclass selection mechanism.


=head1 CREDITS AND COPYRIGHT

=head2 Developed By

  M. Simon Cavalletto, simonm@cavalletto.org
  Evolution Softworks, www.evoscript.org

=head2 Contributors 

  Eric Schneider, roark@evolution.com
  E. J. Evans, piglet@piglet.org

=head2 Copyright

Copyright 2002 Matthew Cavalletto. 

Portions copyright 1998, 1999, 2000, 2001 Evolution Online Systems, Inc.

=head2 License

You may use, modify, and distribute this software under the same terms as Perl.

=cut
