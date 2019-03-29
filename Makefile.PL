######################################################################
# Makefile.PL for YAML::Logic
# 2008, Mike Schilli <cpan@perlmeister.com>
######################################################################
use ExtUtils::MakeMaker;

my $meta_merge = {
    META_MERGE => {
        resources => {
            repository  => 'http://github.com/mschilli/yaml-logic-perl',
        },
    }
};

my %WriteMakefileArgs = (
    'NAME'         => 'YAML::Logic',
    'VERSION_FROM' => 'Logic.pm', # finds $VERSION
    'PREREQ_PM'    => {
        Safe           => 2.11,
        Template       => 2.15,
        Log::Log4perl  => 1.00,
    }, # e.g., Module::Name => 1.1
    'TEST_REQUIRES' => {
        YAML::Syck     => 0.97,
    },
    $ExtUtils::MakeMaker::VERSION >= 6.50 ? (%$meta_merge) : (),
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'Logic.pm',
       AUTHOR     => 'Mike Schilli <cpan@perlmeister.com>') : ()),
);

unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  my $test_requires = delete $WriteMakefileArgs{TEST_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = {
    %{$WriteMakefileArgs{PREREQ_PM}},
    %$test_requires,
  };
}

WriteMakefile(%WriteMakefileArgs);
