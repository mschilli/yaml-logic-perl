######################################################################
# Test suite for YAML::Logic
# by Mike Schilli <cpan@perlmeister.com>
######################################################################
use warnings;
use strict;
use YAML qw(Load Dump);
use Test::More qw(no_plan);
use Data::Dumper;

my $path = "Logic.pm";
$path = "../$path" if ! -f $path;

SKIP: {
    eval "require Pod::Snippets";
    skip "Pod::Snippets not installed", 5 if $@;

    my $snippets = Pod::Snippets->load($path, -markup => "test");

    for my $snip ( $snippets->named("yaml")->as_data() ) {
        eval { Load $snip; };
        is($@, "", "snip") or die $snip;
    }
}
