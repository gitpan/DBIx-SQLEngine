package DBIx::SQLEngine;

$VERSION = 0.002;

use strict;
use Carp;

use Class::MakeMethods;
use DBI;
use DBIx::AnyDBD;
require DBIx::SQLEngine::Default;

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

Required. The name of the tables to select from.

=item columns

Optional; defaults to '*'. May contain a comma-separated string of column names, or an reference to an array of column names, or a reference to an object with a "column_names" method.

=item criteria

Optional. If the criteria is one of the DBO::Criteria objects, its sql() expression will be used. Criteria are blessed hashes of { 'key'=> word, 'match'=> text, 'value'=> ref_val }; see DBO::Criteria for details.

=item order

Optional. May contain a comma-separated string of column names or experessions, optionally followed by "DESC", or an reference to an array of the same.

=item group

Optional. May contain a comma-separated string of column names or experessions, or an reference to an array of the same.

=back

I<Examples:>

=over 4

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

=item fetch_one_row

  $sqldb->fetch_one_row( %sql_clauses ) : $row_hash

Calls fetch_select, then returns only the first row of results.

I<Examples:>

=over 4

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

=over 4

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

=head2 Updating Data

=over 4

=item do_insert( %sql_clauses ) 

  $sqldb->do_insert( %sql_clauses ) 

Insert a single row into a table in the datasource.

I<Argument Pairs:>

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

I<Examples:>

=over 4

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

Required. The name of the table to insert into.

=item columns

Optional; defaults to '*'. May contain a comma-separated string of column names, or an reference to an array of column names, or a reference to a hash whose keys contain the column names, or a reference to an object with a "column_names" method.

=item values

Required. May contain a string with one or more comma-separated quoted values or expressions in SQL format, or a reference to an array of values to insert in order, or a reference to a hash whose values are to be inserted.

=item criteria

Optional, but remember that ommitting this will cause all of your rows to be updated! If the criteria is one of the DBO::Criteria objects, its sql() expression will be used. Criteria are blessed hashes of { 'key'=> word, 'match'=> text, 'value'=> ref_val }; see DBO::Criteria for details.

=back

I<Examples:>

=over 4

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

Required. The name of the table to insert into.

=item criteria

Optional, but remember that ommitting this will cause all of your rows to be updated! If the criteria is one of the DBO::Criteria objects, its sql() expression will be used. Criteria are blessed hashes of { 'key'=> word, 'match'=> text, 'value'=> ref_val }; see DBO::Criteria for details.

=back

I<Examples:>

=over 4

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


=head1 SEE ALSO 

See L<DBI> and the various DBD modules for information about the underlying database interface.

See L<DBIx::SQLEngine::Default> for implementation details.

See L<DBIx::SQLEngine::ReadMe> for distribution information.


=head1 COPYRIGHT AND LICENSE 

Copyright 2002 Matthew Cavalletto. Portions originally copyright 1998, 1999, 2000, 2001 Evolution Online Systems, Inc.

You may use, modify, and distribute this software under the same terms as Perl.

Developed by Matthew Simon Cavalletto E<lt>simonm@cavalletto.orgE<gt>.

Contributors: Eric Schneider E<lt>roark@evolution.comE<gt>, E. J. Evans E<lt>piglet@piglet.org<gt>.

=cut
