######################################################################
# Makefile.PL for YAML::Logic
# 2008, Mike Schilli <cpan@perlmeister.com>
######################################################################
use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'         => 'YAML::Logic',
    'VERSION_FROM' => 'Logic.pm', # finds $VERSION
    'PREREQ_PM'    => {
        YAML::Syck => 0.97,
        Safe       => 2.11,
    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'Logic.pm',
       AUTHOR     => 'Mike Schilli <cpan@perlmeister.com>') : ()),
);
