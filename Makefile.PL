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

cleanmanifest:
	rm MANIFEST ; touch MANIFEST; make manifest

again:
	make clean; perl Makefile.PL; make

docs : README CHANGES TODO

README: SQLEngine/Docs/ReadMe.pod
	pod2text SQLEngine/Docs/ReadMe.pod > README

CHANGES: SQLEngine/Docs/Changes.pod
	pod2text SQLEngine/Docs/Changes.pod > CHANGES

TODO: SQLEngine/Docs/ToDo.pod
	pod2text SQLEngine/Docs/ToDo.pod > TODO

}; }
