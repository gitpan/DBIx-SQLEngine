use ExtUtils::MakeMaker;

########################################################################

WriteMakefile(
    'NAME'		=> 'DBIx::SQLEngine',
    'VERSION_FROM'	=> 'SQLEngine.pm', 
    'PREREQ_PM'		=> {
	DBI				=> 1.0,
	DBIx::AnyDBD			=> 2.0,
	Class::MakeMethods		=> 1.006,
    }, 
    ($] >= 5.005 ? (
      ABSTRACT_FROM => 'SQLEngine.pm', 
      AUTHOR     => 'Matthew Simon Cavalletto <simonm@cavalletto.org>',
    ) : ()),
);

########################################################################


if ( open( CNXNS, 'test.config' ) ) {
  @dsns = <CNXNS>;
  chomp @dsns;
  close( CNXNS ) or die $!;
}

if ( scalar @dsns ) {
  print "I see that you have definitions in test.config for local driver testing.\nYou can edit these by running perl make_extras/test.config.pl\n";
} else {
print <<".";

About SQLEngine Driver Tests
  DBIx::SQLEngine includes a number of tests which can be run against your local
  database drivers. You can specify one or more connections to test, each with 
  its own DSN and optionally also a user name, password, and DBI attributes.
  
  Using the connections listed in the test.config file, the driver test scripts
  will create various tables, run various queries against those tables, and 
  then drop the tables. 
  
  All of the tables used have names begining with "sqle_test", and in theory
  this should not affect other applications, but for safety's sake, please use
  a test account or temporary data space, and avoid testing this on any
  mission-critical production systems.

.
  print "You haven't defined any connections in test.config for local driver testing.\n";
  $yn = prompt("Do you want to define a list of DSNs to test against?", "N");

  unless ( $yn !~ /\S/ or $yn =~ /n/i ) {
    do "make_extras/test.config.pl" or die $@;
  }
}
  
########################################################################

sub MY::postamble { q{

everything: FORCE
	make again; make cleanmanifest; make docs; make compile; make testsuite

cleandist: FORCE
	make again; make cleanmanifest; make docs; make dist

again: FORCE
	make clean; perl Makefile.PL; make pm_to_blib

cleanmanifest: FORCE
	rm MANIFEST ; touch MANIFEST; make manifest

testsuite: pm_to_blib FORCE
	perl make_extras/testsuite.pl

%.t: pm_to_blib FORCE
	perl -Iblib/lib -w $@

compile: pm_to_blib FORCE
	perl make_extras/compile.pl $(MAN3PODS)

htmldoc: pm_to_blib FORCE
	perl make_extras/htmldoc.pl $(MAN3PODS)

cover: FORCE
	cover -delete; HARNESS_PERL_SWITCHES="-MDevel::Cover=+inc,test_core,test_drivers" make test; cover

docs : README CHANGES TODO

README: SQLEngine/Docs/ReadMe.pod
	pod2text SQLEngine/Docs/ReadMe.pod > README

CHANGES: SQLEngine/Docs/Changes.pod
	pod2text SQLEngine/Docs/Changes.pod > CHANGES

TODO: SQLEngine/Docs/ToDo.pod
	pod2text SQLEngine/Docs/ToDo.pod > TODO

} }

########################################################################
1;
