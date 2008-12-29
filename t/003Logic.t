######################################################################
# Test suite for YAML::Logic
# by Mike Schilli <cpan@perlmeister.com>
######################################################################
use warnings;
use strict;
use YAML qw(Load Dump);
use YAML::Logic;
use Test::More qw(no_plan);
use Data::Dumper;
use Log::Log4perl qw(:easy);
#Log::Log4perl->easy_init($DEBUG);

  # Not equal
eval_test("rule:
  - foo
  - bar
", {}, 0);

  # Equal
eval_test("rule:
  - foo
  - foo
", {}, 1);

  # Equal with interpolation (left)
eval_test('rule:
  - $var
  - foo
', { var => "foo" }, 1);

  # Equal with interpolation (right)
eval_test('rule:
  - foo
  - $var
', { var => "foo" }, 1);


  # Equal with interpolation (both)
eval_test('rule:
  - $var1
  - $var2
', { var1 => "foo", var2 => "foo" }, 1);


###########################################
sub eval_test {
###########################################
    my($yml, $vars, $expected, $descr) = @_;

    my $logic = YAML::Logic->new();

    my $data = Load $yml;
    is( $logic->evaluate( $data->{rule}, $vars ), $expected, $descr );
}
