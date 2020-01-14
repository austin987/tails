=head1 NAME

Tails::Role::HasEncoding - role to provide an Encode::Encoding objet for the codeset being used

=head1 SYNOPSIS

    package Tails::Daemon;
    use Moo;
    with 'Tails::Role::HasEncoding';
    sub foo {
       my $self = shift;
       $self->encoding->decode('bla');
    }

=cut

package Tails::Role::HasEncoding;

use 5.10.1;
use strictures 2;
use autodie qw(:all);

use Encode qw{find_encoding};
use Function::Parameters;

no Moo::sification;
use Moo::Role; # Moo::Role exports all methods declared after it's "use"'d
use MooX::late;

with 'Tails::Role::HasCodeset';

use namespace::clean;

has 'encoding' => (
    isa        => 'Encode::Encoding|Encode::XS',
    is         => 'ro',
    lazy_build => 1,
);

method _build_encoding () {
    find_encoding($self->codeset);
}

no Moo::Role;
1; # End of Tails::Role::HasEncoding
