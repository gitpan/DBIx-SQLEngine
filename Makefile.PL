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

sub MY::postamble { q{

everything:
	make again; make cleanmanifest; make docs; make testsuite

cleandist:
	make again; make cleanmanifest; make docs; make dist

again:
	make clean; perl Makefile.PL; make pm_to_blib

cleanmanifest:
	rm MANIFEST ; touch MANIFEST; make manifest

testsuite: pm_to_blib FORCE
	perl t/test_suite.pl

%.t: pm_to_blib FORCE
	perl -Iblib/lib $@

compile: pm_to_blib FORCE
	find blib -name '*.pm' -exec perl -Iblib/lib -wc {} \;

cover:
	cover -delete; HARNESS_PERL_SWITCHES=-MDevel::Cover make testsuite; cover

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
