###########################################
package YAML::Logic;
###########################################

use strict;
use warnings;
use Log::Log4perl qw(:easy);
use Template;

our $VERSION = "0.01";

###########################################
sub new {
###########################################
    my($class, %options) = @_;

    my $self = {
        %options,
    };

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

    if( YAML::Logic::eval( $data->{expr}, { var => "foo" }) ) {
        print "True!\n";
    }

=head1 DESCRIPTION

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

=back

YAML::Logic blah blah blah.

=head1 EXAMPLES

  $ perl -MYAML::Logic -le 'print $foo'

=head1 LEGALESE

Copyright 2008 by Mike Schilli, all rights reserved.
This program is free software, you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AUTHOR

2008, Mike Schilli <cpan@perlmeister.com>
