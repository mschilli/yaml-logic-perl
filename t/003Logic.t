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
use Log::Log4perl qw(:easy);
#Log::Log4perl->easy_init($DEBUG);

  # Not equal
eval_test("rule:
  - foo
  - bar
", {}, 0, "equal");

  # Equal
eval_test("rule:
  - foo
  - foo
", {}, 1, "equal");

  # Equal with interpolation (left)
eval_test('rule:
  - $var
  - foo
', { var => "foo" }, 1, "interpolation");

  # Equal with interpolation (right)
eval_test('rule:
  - foo
  - $var
', { var => "foo" }, 1, "interpolation");


  # Equal with interpolation (both)
eval_test('rule:
  - $var1
  - $var2
', { var1 => "foo", var2 => "foo" }, 1, "interpolation");

  # op: eq
eval_test('rule:
  - foo
  - eq: bar
', {}, 0, "eq op");

  # op: ==
eval_test('rule:
  - 5
  - ==: 13
', {}, 0, "== op");

  # op: ==
eval_test('rule:
  - 13
  - ==: 13
', {}, 1, "== op");

  # op: ne
eval_test('rule:
  - foo
  - ne: bar
', {}, 1, "ne op");

  # op: lt
eval_test('rule:
  - abc
  - lt: def
', {}, 1, "lt op");

  # op: gt
eval_test('rule:
  - abc
  - gt: def
', {}, 0, "gt op");

  # op: gt
eval_test('rule:
  - 123
  - gt: 456
', {}, 0, "gt op");

  # op: gt
eval_test('rule:
  - 456
  - gt: 123
', {}, 1, "gt op");

  # op: <
eval_test(q{rule:
  - 456
  - '>': 123
}, {}, 1, "> op");

  # op: <
eval_test(q{rule:
  - 123
  - '>': 456
}, {}, 0, "> op");

  # op: <
eval_test(q{rule:
  - 456
  - '<=': 123
}, {}, 0, "<= op");

  # op: <=
eval_test(q{rule:
  - 45
  - '<=': 123
}, {}, 1, "<= op");

  # op: <
eval_test(q{rule:
  - 456
  - '<': 123
}, {}, 0, "< op");

  # op: <
eval_test(q{rule:
  - 123
  - '<': 456
}, {}, 1, "< op");

  # op: regex
eval_test('rule:
  - 456
  - like: "\d+"
', {}, 1, "regex");

  # op: regex
eval_test('rule:
  - 456
  - =~: "\d+"
', {}, 1, "regex");

  # op: regex
eval_test('rule:
  - 456
  - =~: "\d+"
', {}, 1, "regex");

eval_test('rule:
  - aBc
  - like: "(?i)abc"
', {}, 1, "regex /i");

eval_test('rule:
  - aBc
  - like: (?i)abc
', {}, 1, "regex /i");

eval {
eval_test(q#rule:
  - aBc
  - like: "?{ unlink '/tmp/foo' }"
#, {}, 1, "regex code trap");
};

like $@, qr/Trapped \?{ in regex/, "trap code";

  # Not
eval_test(q{rule:
  - '!foo'
  - bar
}, {}, 1, "not");

  # Not with variable
eval_test(q{rule:
  - '!$var'
  - bar
}, {var => "bar"}, 0, "not with var");

  # Neither match
eval_test(q{rule:
  - '!$var'
  - like: "foo"
  - '!$var'
  - like: "bar"
}, {var => "abc"}, 1, "neither of two matches");

  # Neither match
eval_test(q{rule:
  - '!$var'
  - like: "foo"
  - '!$var'
  - like: "bar"
}, {var => "foo"}, 0, "neither of two matches, false");

  # Both sides interpolated
eval_test(q{rule:
  - $var1
  - '$var2'
}, {var1 => "foo", var2 => "foo"}, 1, "both sides interpolated");

  # Hash interpolation
eval_test(q{rule:
  - $var.somekey
  - foo
}, {var => { somekey => 'foo' }}, 1, "hash interpolation");

  # Array interpolation
eval_test(q{rule:
  - $var.1
  - el2
}, {var => [ 'el1', 'el2' ] }, 1, "array interpolation");

  # Logical or
eval_test(q{rule:
  - or
  -
    - $var
    - foo
    - $var
    - bar
}, {var => "bar"}, 1, "logical or");

  # Logical or
eval_test(q{rule:
  - or
  -
    - $var
    - foo
    - $var
    - bar
}, {var => "foo"}, 1, "logical or");

  # Logical or
eval_test(q{rule:
  - or
  -
    - $var
    - foo
    - $var
    - bar
}, {var => "abc"}, 0, "logical or");

  # Logical or
eval_test(q{rule:
  - or
  -
    - "!$var"
    - foo
    - $var
    - bar
}, {var => "abc"}, 1, "logical or");

  # Undef
eval_test(q{rule:
    - "$var.defined"
    - ""
}, { var => undef }, 1, "undef");

eval_test(q{rule:
    - "!$var.defined"
    - 1
}, { var => undef }, 1, "undef");

eval_test(q{rule:
    - $var.defined
    - 1
}, { var => 0 }, 1, "undef");

eval_test(q{rule:
    - "!$var.defined"
    - 1
}, { var => 0 }, 0, "undef");

eval_test(q{rule:
    - "!${var.defined}"
    - 1
}, { var => 0 }, 0, "undef");

eval_test(q{rule:
    - "foo$var"
    - "bar$var"
}, { var => 0 }, 0, "double interpolation");

eval_test(q{rule:
    - "foo$var"
    - "foo$var"
}, { var => 1 }, 1, "double interpolation");

###########################################
sub eval_test {
###########################################
    my($yml, $vars, $expected, $descr) = @_;

    my $logic = YAML::Logic->new();

    my $data = Load $yml;
    is( $logic->evaluate( $data->{rule}, $vars ), $expected, $descr );
}
