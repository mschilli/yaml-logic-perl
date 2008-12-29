###########################################
package YAML::Logic;
###########################################

use strict;
use warnings;
use Log::Log4perl qw(:easy);
use Template;
use Safe;

our $VERSION = "0.01";
our %OPS = map { $_ => 1 }
    qw(eq ne lt gt < > == =~ like);

###########################################
sub new {
###########################################
    my($class, %options) = @_;

    my $self = {
        safe => Safe->new(),
        %options,
    };

    $self->{safe}->permit();

    bless $self, $class;
}

###########################################
sub interpolate {
###########################################
    my($self, $input, $vars) = @_;

    return $input if $input !~ /^\$/;

    my $out;
    my $template = Template->new();

    $input =~ s/\$(\S+)/[%- $1 %]/g;

    $template->process( \$input, $vars, \$out ) or
        LOGDIE $template->error();

    return $out;
}

###########################################
sub equal {
###########################################
    my($self, $field, $value) = @_;

    $field = $self->interpolate( $field );
    return $field eq $value;
}

###########################################
sub evaluate {
###########################################
    my($self, $data, $vars, $not_glob, $boolean_or) = @_;

    if( ref($data) eq "ARRAY" ) {
        my @data = @$data; # make a copy, so splice() doesn't destroy 
                           # the original.
        while( my($field, $value) = splice @data, 0, 2 ) {
            my $res;

            my $not;

            if($field =~ s/^!//) {
                $not = !$not_glob;
            }

            if($field eq "or") {
                return $self->evaluate($value, $vars, $not, 1);
            } elsif( $field eq "and") {
                return $self->evaluate($value, $vars, $not);
            } else {
                $field = $self->interpolate($field, $vars);
                $value = $self->interpolate($value, $vars);

                if(ref($value) eq "") {
                    $res = $self->evaluate_single( $field, $value, "eq", $not );
                } elsif(ref($value) eq "HASH") {
                    my($op)  = keys   %$value;
                    ($value) = values %$value;
                    $res = $self->evaluate_single( $field, $value, $op, $not );
                }
                if($boolean_or and $res) {
                    # It's a boolean OR, so all it takes is one true result 
                    return 1;
                } elsif(!$boolean_or and !$res) {
                    # It's a boolean AND, so all it takes is one false result 
                    return 0;
                }
            }
        }
    } else {
        LOGDIE "Unknown type: $data";
    }

      # Return 1 if all ANDed conditions succeeded, and 0 if all
      # ORed conditions failed.
    return ($boolean_or ? 0 : 1);
}

###########################################
sub evaluate_single {
###########################################
    my($self, $field, $value, $op, $not) = @_;

    $op = lc $op ;
    $op = '=~' if $op eq "like";

    if(! exists $OPS{ $op }) {
        LOGDIE "Unknown op: $op";
    }

    $field = '"' . esc($field, '"') . '"';

    if($op eq "=~") {
        if($value =~ /\?\{/) {
            LOGDIE "Trapped ?{ in regex.";
        }
        #DEBUG "Match against (before): $value";
        $value = qr($value);
        DEBUG "Match against: $value";
        my $res = ($field =~ $value);
        return ($not ? (!$res) : $res);
    }

    $value = '"' . esc($value, '"') . '"';
    my $cmd = "$field $op $value";
    DEBUG "Compare: $cmd";
    my $res = $self->{safe}->reval($cmd);
    if($@) {
        LOGDIE "$@";
    }
    return ($not ? (!$res) : $res);
}

###############################################
sub esc {
###############################################
    my($str, $metas) = @_;

    $str =~ s/([\\"])/\\$1/g;

    if(defined $metas) {
        $metas =~ s/\]/\\]/g;
        $str =~ s/([$metas])/\\$1/g;
    }

    return $str;
}

1;

__END__

=head1 NAME

YAML::Logic - Simple boolean logic in YAML

=head1 SYNOPSIS

    use YAML qw(Load);
    use YAML::Logic;

    my $logic = YAML::Logic->new();

      ### Tests defined somewhere in a YAML file ...
    my $data = Load(q{
      # is $var equal to "foo"?
    rule:
      - $var
      - foo
    });

      ### Tests performed in application code:
    if( $logic->evaluate( $data->{rule}, 
                          { var => "foo" }) ) {
        print "True!\n";
    }

=head1 DESCRIPTION

YAML::Logic allows users to define simple boolean logic in a 
configuration file, without permitting them to run arbitrary code.

While Perl code can be controlled with the C<Safe> module, C<Safe> can't 
prevent the user from defining infinite loops, exhausting all available 
memory or crashing the interpreter by exploiting well-known perl bugs.
YAML::Logic isn't perfect in this regard either, but it makes it reasonably 
hard to define harmful code.

The syntax for the boolean logic within a YAML file was inspired by 
John Siracusa's C<Rose::DB::Object::QueryBuilder> module, which provides 
data structures to define logic that is then transformed into SQL. 
YAML::Logic takes the data structure instead and transforms it into Perl
code.

For example, the data structure to check whether a variable C<$var> is
equal to a value "foo", looks like this:

    [$var, "foo"]

It's a reference to an array containing both the value of the variable and
the value to compare it with. In YAML, this looks like

=for test "yaml" begin

    rule: 
      - $var
      - foo

=for test "yaml" end

and this is exactly the syntax that YAML::Logic accepts. Note that after
parsing the YAML configuration above, you need to pass I<only> the 
array ref inside the C<rule> entry to YAML::Logic's C<evaluate()> method:

    $logic->evaluate( $yaml_data->{rule},  ...

Passing the entire YAML data would cause an error with YAML::Logic, as
it expects to receive an array ref.

Several comparisons
can be combined by lining them up in the array. The lineup

    [$var1, "foo", $var2, "bar"]

returns true if $var1 is equal to "foo" I<and> $var2 is equal to "bar".
In YAML::Logic syntax, these two ANDed comparisons are written as

=for test "yaml" begin

    rule: 
      - $var1
      - foo
      - $var2
      - bar

=for test "yaml" end

in a YAML file.

=head2 Variable Interpolation

If a field starts with the '$' character, the value of the
following variable is substituted by YAML::Logic before running the check.

So if you have

    rule:
      - $var
      - foo

and run

    my $data = YAML::Load( $yaml );
    my $rc = $logic->evaluate( $data->{rule}, { var => "bar" } );

then YAML::Logic will substitute C<$var> by the string "bar", and then
run the test

    ["bar", "foo"]

which checks if "bar" equals "foo". Since this is false, C<evaluate> 
returns false. Note how C<evaluate> takes a ref to a hash as its 
second argument, which maps all variables you want to have replaced 
to their respective values.

Interpolation is done on every field, so

    rule:
      - $var1
      - $var2

with

    my $data = YAML::Load( $yaml );
    my $rc = $logic->evaluate( $data->{rule}, 
                               { var1 => "foo", var2 => "foo" } );

will test if "foo" equals "foo" and hence return a true value. 

Note that (for now) only variables at the beginning of the string are
interpolated, so "abc$foo" won't be.

Interpolation is done by the C<Template> module, so all the magic it does
for arrays and hashes applies:

    rule:
      - $hash.somekey
      - foo

with

    my $data = YAML::Load( $yaml );
    my $rc = $logic->evaluate( $data->{rule}, 
                               { hash => { somekey => "foo" } } );

will test if "foo" equals "foo" and hence return a true value. 

Likewise,

    rule:
      - $array.1
      - el2

with

    my $data = YAML::Load( $yaml );
    my $rc = $logic->evaluate( $data->{rule}, 
                               { array => [ 'el1', 'el2' ] } );

will test if "el2" equals "el2" and return a true value. Check 
C<perldoc Template> or read the O'Reilly Template Toolkit book for a more
detailed explanation of Template's variable interpolation magic.

=head2 Other Comparators

Not only equality can be tested. In addition, these Perl operators are 
supported:

    eq 
    ne 
    lt 
    gt 
    < 
    > 
    == 
    =~ like

The way to specify a different operator is to put it as key into a hash:

    [ $var, { $op, $value } ]

So, the previous rule comparing $var to "foo" can be written as

=for test "yaml" begin

    rule:
      - $var
      - eq: foo

=for test "yaml" end

which is essentially running 

    $var eq "foo"

in Perl. To perform a numerical comparison, use the C<==> operator,

=for test "yaml" begin

    rule:
      - $var
      - ==: 123

=for test "yaml" end

which runs a test of C<$var == 123> instead.

=head2 Regular Expressions

Regular expression matching is supported as well, so to verify if $var matches
the regular expression C</^foo/>, use

=for test "yaml" begin

    rule:
      - $var
      - like: "^foo"

=for test "yaml" end

or

=for test "yaml" begin

    rule:
      - $var1
      - =~: "^foo"

=for test "yaml" end

Both are equivalent.

Regular expressions are given without delimiters, e.g. if you want to
match against /abc/, simply use

    rule:
      - '$var'
      - abc

To add regex modifiers like C</i> or C</ms>, use the C<(?...)> syntax. The
setting

    rule:
      - '$var'
      - (?i)abc

will match like C<$var =~ /abc/i>.

=head2 Logical NOT

A logical NOT is expressed by putting an exclamation mark in front of
the variable, so

    ["!$var1", "foo"]

will return true if $var1 is NOT equal to "foo". The YAML notation is

=for test "yaml" begin

    rule: 
      - "!$var1"
      - foo

=for test "yaml" end

for this logical expression. Note that YAML requires putting a string
starting with an exclatmation mark in quotes.

By default, additional rules are chained up with a logical AND operator,
so to check if a variable is not set to "foo" and not set to "bar", use:

=for test "yaml" begin

    rule:
      - '!$var'
      - foo
      - '!$var'
      - bar

=for test "yaml" end

And to verify that the variable matches neither /^foo.*/ nor /^bar.*/, use:

=for test "yaml" begin

    rule:
        - '!$var'
        -
          - like: "^foo.*"
          - like: "^bar.*"

=for test "yaml" end

Also note that "^foo.*" requires quotes in YAML.

=head2 Logical OR

To specify a rule that is satisfied if I<any> of a series of tests
succeeds, use the 'or' keyword in place of a variable:

    [ "or", [ $var, "foo", $var, "bar" ] ]

This data structure indicates that the entire test is supposed to return
true if either C<$var eq "foo"> or C<$var eq "bar"> holds true. It looks
like this in YAML:

=for test "yaml" begin

    rule: 
      - or
      -
        - $var
        - foo
        - $var
        - bar

=for test "yaml" end

Pay close attention to the indentation: After the C<- or> follows a 
line with a dash at the same indentation level, followed by a sub-array
which has its elements indented to the next level.

=head2 Logical AND

By default, YAML::Logic chains up clauses by logical ANDs, i.e.

    rule:
      - $var1
      - foo
      - $var2
      - bar

checks if $var1 is equal to "foo" I<and> $var2 is equal to "bar". 
Alternatively, the "and" keyword can be used similar to the "or"
keyword explained in the previous section:

=for test "yaml" begin

    rule: 
      - and
      -
        - $var
        - foo
        - $var
        - bar

=for test "yaml" end

With the above, you can't have variables named "and" or "or". If you do,
use a hash key, as explained below.

=head2 Logical Set Operations

(not yet implemented)

=for test "yaml" begin

    rule: 
      - $var1
      -
        - element1
        - element2

=for test "yaml" end

(not yet implemented)

=for test "yaml" begin

    rule: 
      - $var1
      - like:
          - element1
          - element2

=for test "yaml" end

=head1 YAML Traps

The original YAML implementation has a number of nasty bugs (e.g. RT42015), 
so using YAML::Syck is recommended, which is a both faster and more 
reliable parser.

Also, YAML as a configuration format can be tricky at times. For example 
if you type in

    my $data = Load(q{
      # is $var equal to "foo"?
    rule:
      - $var
      - foo
    });

literally (like in the SYNOPSIS section of this document), keeping the 
indentation intact, YAML will complain that it's not happy about the final 
blank line, which contains whitespace characters:

    Code: YAML_PARSE_ERR_NO_FINAL_NEWLINE

To avoid this, either use a YAML file, in which not using unnecessary
indentation will feel natural, make sure there's no last line containing
just whitespace, before feeding it to the YAML parser:

    my $yaml_string = q{
          # is $var equal to "foo"?
        rule:
          - $var
          - foo
    };
    $yaml_string =~ s/^\s+\Z//m;
    my $data = Load($yaml_string);

Also, certain characters have a special meaning in YAML, so you can't write

    # WRONG
    rule:
      - $var
      - !blah!

because YAML will parse that to

    [$var, undef]

within the C<rule> hash entry. Why?
Lines starting with an exclamation mark are I<tags> in YAML. To 
avoid getting tripped up by this, use quotes:

    # CORRECT
    rule:
      - $var
      - "!blah!"

which correctly parses to 

    [$var, "!blah!"]

within the C<rule> hash entry instead.

=head1 LEGALESE

Copyright 2008 by Mike Schilli, all rights reserved.
This program is free software, you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AUTHOR

2008, Mike Schilli <cpan@perlmeister.com>
