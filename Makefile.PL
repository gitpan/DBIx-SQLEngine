use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'		=> 'DBIx::SQLEngine',
    'VERSION_FROM'	=> 'SQLEngine.pm', 
    'PREREQ_PM'		=> {
	DBI				=> 1.0,
	DBIx::AnyDBD			=> 2.0,
	Class::MakeMethods		=> 1.003,
	Class::MakeMethods::Template	=> 1.003,
    }, 
    ($] >= 5.005 ? (
      ABSTRACT_FROM => 'SQLEngine.pm', 
      AUTHOR     => 'Matthew Simon Cavalletto <simonm@cavalletto.org>',
    ) : ()),
);

sub MY::postamble { q{

docs : README CHANGES TODO

README: SQLEngine/ReadMe.pod
	pod2text SQLEngine/ReadMe.pod > README

CHANGES: SQLEngine/Changes.pod
	pod2text SQLEngine/Changes.pod > CHANGES

TODO: SQLEngine/ToDo.pod
	pod2text SQLEngine/ToDo.pod > TODO

cleanmanifest:
	rm MANIFEST ; touch MANIFEST; make manifest

}; }

print $ENV{DBI_DSN} ? <<"." : <<'.';

  Some tests will use the DBI_DSN from your environment variables, currently: 
    $ENV{DBI_DSN}
  
.

  Note: By default, DBIx::SQLEngine will perform only limited tests, using
  generic drivers such as DBD::ExampleP, and DBD::AnyData (if installed).

  In order to test DBIx::SQLEngine against your local database, set the DBI_DSN 
  environment variable to your connection string before running the tests, and 
  if needed, also set the DBI_USER and DBI_PASS variables. (A table named
  sqle_test will be created in this database, tested, and then dropped.)

.
