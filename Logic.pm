###########################################
package YAML::Logic;
###########################################

use strict;
use warnings;

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

1;

__END__

=head1 NAME

YAML::Logic - blah blah blah

=head1 SYNOPSIS

    use YAML::Logic;

=head1 DESCRIPTION

=over 4

=item *

The variable is set to "foo".

=for test "yaml" begin

    expr:
      - '$var'
      - foo

=for test "yaml" end

=item *

The variable is I<not> set to "foo".

=for test "yaml" begin

    expr:
      - '!$var'
      - foo

=for test "yaml" end

=item *

The variable is I<not> set to "foo" and I<not> set to "bar".

=for test "yaml" begin

    expr:
      - '!$var'
      - foo
      - '!$var'
      - bar

=for test "yaml" end

=item *

The variable is set to "foo" I<or> set to "bar".

=for test "yaml" begin

    expr:
      - or
        - '$var'
        - foo
        - '$var'
        - bar

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
