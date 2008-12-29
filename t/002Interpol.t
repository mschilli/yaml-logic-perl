######################################################################
# Test suite for YAML::Logic
# by Mike Schilli <cpan@perlmeister.com>
######################################################################
use warnings;
use strict;
use YAML::Syck qw(Load Dump);
use YAML::Logic;
use Test::More qw(no_plan);
use Data::Dumper;

my $logic = YAML::Logic->new();

my $out = $logic->interpolate( '$var', { var => "foo" } );
is($out, "foo", "simple variable interpolation");

$out = $logic->interpolate( '$var.field', { var => { field => "foo" } } );
is($out, "foo", "hash entry");
