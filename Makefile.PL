use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Date::Formatter',
    'VERSION_FROM'	=> 'lib/Date/Formatter.pm', # finds $VERSION
    'PREREQ_PM'		=> {
		'Test::More' => 0.47,
		'Test::Exception' => 0.15
		}, # e.g., Module::Name => 1.1
);
