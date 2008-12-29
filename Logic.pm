###########################################
package YAML::Logic;
###########################################

use strict;
use warnings;
use Log::Log4perl qw(:easy);
use Template;
use Sysadm::Install qw( qquote );
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
    my($self, $data, $vars) = @_;

    if( ref($data) eq "ARRAY" ) {
        while( my($field, $value) = splice @$data, 0, 2 ) {
            my $res;

            $field = $self->interpolate($field, $vars);
            $value = $self->interpolate($value, $vars);

            if(ref($value) eq "") {
                $res = $self->evaluate_single( $field, $value, "eq" );
            } elsif(ref($value) eq "HASH") {
                my($op)  = keys   %$value;
                ($value) = values %$value;
                $res = $self->evaluate_single( $field, $value, $op );
            }
            if(!$res) {
                  # It's a boolean AND, so all it takes is one false result 
                return 0;
            }
        }
    } else {
        LOGDIE "Unknown type: $data";
    }

    return 1;
}

###########################################
sub evaluate_single {
###########################################
    my($self, $field, $value, $op) = @_;

    my $not;

    if($field =~ s/^!//) {
        $not = 1;
    }

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

    my $data = Load(q{
      # is $var equal to "foo"?
    expr:
      - $var
      - foo
    };

    if( YAML::Logic::evaluate( $data->{expr}, { var => "foo" }) ) {
        print "True!\n";
    }

=head1 DESCRIPTION

YAML::Logic allows users to define simple boolean logic in a 
configuration file, albeit without permitting arbitrary code.

While Perl code can be controlled with the C<Safe> module, C<Safe> can't 
prevent the user from defining infinite loops, exhausting all available 
memory or crashing the interpreter by exploiting well-known perl bugs.

YAML::Logic isn't perfect in this regard either, but it makes it reasonably 
hard to define harmful code.

The syntax for the boolean logic within a YAML file has been inspired by 
John Siracusa's C<Rose::DB::Object::QueryBuilder> module, which provides 
data structures to defined logic that is then transformed into SQL. 
YAML::Logic takes the data structure instead and transforms it into Perl
code.

For example, the data structure to check whether a variable C<$var> is
equal to a value "foo", looks like

    [$var, "foo"]

(a reference to an array containing both the value of the variable and
the value to compare it against). In YAML, this looks like

    rule: 
      - $var
      - foo

and this is exactly the syntax that YAML::Logic accepts. Several comparisons
can be combined by lining them up in the array:

    [$var1, "foo", $var2, "bar"]

returns true if $var1 is equal to "foo" I<and> $var2 is equal to "bar".
In YAML logical AND between two comparisons is written as

    rule: 
      - $var1
      - foo
      - $var2
      - bar

A logical NOT is expressed by putting an exclamation mark in front of
the variable, so

    ["!$var1", "foo"]

will return true if $var1 is NOT equal to "foo". The YAML notation is

    rule: 
      - "!$var1"
      - foo

for this logical expression. Note that YAML requires putting a string
starting with an exclatmation mark in quotes.

TODO

=over 4

=item *

The variable is set to "foo".

=for test "yaml" begin

    expr:
      - $var
      - foo

=for test "yaml" end

=item *

The variable is not set to "foo".

=for test "yaml" begin

    expr:
      - '!$var'
      - foo

=for test "yaml" end

=item *

The variable is not set to "foo" and not set to "bar".

=for test "yaml" begin

    expr:
      - '!$var'
      - foo
      - '!$var'
      - bar

=for test "yaml" end

=item *

The variable is set to "foo" or set to "bar".

=for test "yaml" begin

    expr:
      - or
      -
        - '$var'
        - foo
        - '$var'
        - bar

=for test "yaml" end

=item *

The variable is set to "foo" and not set to "bar".

=for test "yaml" begin

    expr:
        - '$var'
        - foo
        - '!$var'
        - bar

=for test "yaml" end

=item *

The variable matches the regular expression /^foo.*/

=for test "yaml" begin

    expr:
        - '$var'
        - like: "^foo.*"

=for test "yaml" end

=item *

The variable matches both regular expressions, /^foo.*/ and /^bar.*/.

=for test "yaml" begin

    expr:
        - '$var'
        -
          - like: "^foo.*"
          - like: "^bar.*"

=for test "yaml" end

=item *

The variable matches neither /^foo.*/ nor /^bar.*/.

=for test "yaml" begin

    expr:
        - '!$var'
        -
          - like: "^foo.*"
          - like: "^bar.*"

=for test "yaml" end

=item *

The value of the variable is less than 5.

=for test "yaml" begin

    expr:
        - '$var'
        - lt: 5

=for test "yaml" end

=back


Regular expressions are given without delimiters, e.g. if you want to
match against /abc/, simply use

    expr:
      - '$var'
      - abc

To add regex modifiers like C</i> or C</ms>, use the C<(?...)> syntax. The
setting

    expr:
      - '$var'
      - (?i)abc

will match like C<$var =~ /abc/i>.

=head1 SYNTAX

=over 4

=item *

    A: S1, S2

    return S1 eq S2

=item *

    A: !S1, S2

    return ! (S1 eq S2)

=item *

    A: S1 [S2, S3, ...]

    return (S1 eq S2 or S1 eq S3);

=item *

    A: !S1 [S2, S3, ...]

    return ! (S1 eq S2 or S1 eq S3);

=item *

    A: S1 {OP => S3}

    return OP(S1, S3);

=item *

    A1, A2

    return A1 and A2;
    
=item *

    return OP(S1, S3);

=back

=head1 EXAMPLES

  $ perl -MYAML::Logic -le 'print $foo'

=head1 LEGALESE

Copyright 2008 by Mike Schilli, all rights reserved.
This program is free software, you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AUTHOR

2008, Mike Schilli <cpan@perlmeister.com>
