### Standard test sequence for DBIx::SQLEngine.

use Test;
BEGIN { plan tests => 26 }

scalar @ConnectArgs or die "Test script failed to set up connection arguments!";

use DBIx::SQLEngine;
BEGIN { ok( 1 ) }

########################################################################

my $sqldb;
ok( $sqldb = DBIx::SQLEngine->new( @ConnectArgs ) );

# $sqldb->DBILogging(1);  # Uncomment this line to show all queries as they run

ok( ref($sqldb) =~ /DBIx::SQLEngine::(.+)/ );
warn "  (Testing DBIx::SQLEngine::$1)\n";

ok( $sqldb->detect_any );

########################################################################

my $table = 'sqle_test';

$sqldb->do_drop_table( $table ) if $sqldb->detect_table($table, 'quietly');
$sqldb->do_create_table( $table, [
  { name => 'id', type => 'sequential' },
  { name => 'name', type => 'text', length => 16 },
  { name => 'color', type => 'text', length => 8 },
]);
ok( 1 );

###

my @cols = $sqldb->detect_table( $table );
ok( scalar( @cols ) == 3 );
@cols = $sqldb->detect_table( 'area_51_secrets', 'quietly' );
ok( scalar( @cols ) == 0 );

###

$sqldb->do_insert( table => $table, values => { name=>'Sam', color=>'green' }, sequence => 'id' );
$sqldb->do_insert( table => $table, values => { name=>'Ellen', color=>'orange' }, sequence => 'id' );
$sqldb->do_insert( table => $table, values => { name=>'Sue', color=>'purple' }, sequence => 'id' );
ok( 1 );

my $rows = $sqldb->fetch_select( table => $table, order => 'id' );
ok( ref $rows and scalar @$rows == 3 );
ok( $rows->[0]->{'name'} eq 'Sam' and $rows->[0]->{'color'} eq 'green' );

$sqldb->do_insert( table => $table, values => { name=>'Dave', color=>'blue' }, sequence => 'id' );
ok( 1 );

my $rows = $sqldb->fetch_select( table => $table );
ok( ref $rows and scalar @$rows == 4 );

###

my $rows = $sqldb->fetch_select( table => $table, criteria => { name=>'Dave' } );
ok( ref $rows and scalar @$rows == 1 and $rows->[0]->{'name'} eq 'Dave' );

my $rows = $sqldb->fetch_select( table => $table, criteria => "name = 'Dave'" );
ok( ref $rows and scalar @$rows == 1 and $rows->[0]->{'name'} eq 'Dave' );

my $rows = $sqldb->fetch_select( sql => "select * from $table where name = 'Dave'" );
ok( ref $rows and scalar @$rows == 1 and $rows->[0]->{'name'} eq 'Dave' );

my $rows = $sqldb->fetch_select( sql => [ "select * from $table where name = ?", 'Dave' ] );
ok( ref $rows and scalar @$rows == 1 and $rows->[0]->{'name'} eq 'Dave' );

###

$sqldb->do_update( table => $table, criteria => { name=>'Dave' }, values => { color=>'yellow' } );
ok( 1 );

my $rows = $sqldb->fetch_select( table => $table, criteria => { name=>'Dave' } );
ok( ref $rows and scalar @$rows == 1 and $rows->[0]->{'color'} eq 'yellow' );

### Now do the same thing using literal expressions

$sqldb->do_update( table => $table, criteria => { name=>\"'Dave'" }, values => { color=>\"'mauve'" } );
ok( 1 );

my $rows = $sqldb->fetch_select( table=>$table, criteria=>{ name=>\"'Dave'" } );
ok( ref $rows and scalar @$rows == 1 and $rows->[0]->{'color'} eq 'mauve' );

### Delete

$sqldb->do_delete( table => $table, criteria => { name=>'Sam' } );
ok( 1 );

my $rows = $sqldb->fetch_select( table => $table );
ok( ref $rows and scalar @$rows == 3 );

### Basic Use of NULL Values

my $rows = $sqldb->fetch_select( table=>$table, criteria=>{ name=>undef } );
ok( ref $rows and scalar @$rows == 0 );

$sqldb->do_update( table => $table, criteria => { name=>\"'Dave'" }, values => { name=>undef } );
ok( 1 );

my $rows = $sqldb->fetch_select( table=>$table, criteria=>{ name=>undef } );
ok( ref $rows and scalar @$rows == 1 and $rows->[0]->{'color'} eq 'mauve' );

### Drop Table

$sqldb->do_sql("drop table $table");
ok( 1 );

########################################################################

1;
