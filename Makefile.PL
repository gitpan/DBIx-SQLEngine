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
