=head1 NAME

Tails::Persistence::Configuration::Atom - a GUI-friendly configuration line

=cut

package Tails::Persistence::Configuration::Atom;
use 5.10.1;
use strictures 2;
use Moo;
use MooX::late;

with 'Tails::Persistence::Role::ConfigurationLine';

use autodie qw(:all);

use Function::Parameters;
use List::MoreUtils qw{all pairwise};
use Types::Standard qw(ClassName InstanceOf);

use namespace::clean;


=head1 ATTRIBUTES

=cut

has 'enabled' => (
    required => 1,
    is       => 'rw',
    isa      => 'Bool',
);

has 'id' => (
    lazy_build => 1,
    is         => 'rw',
    isa        => 'Str',
);


=head1 CONSTRUCTORS

=cut

method new_from_line (
    ClassName $class:
    (InstanceOf['Tails::Persistence::Configuration::Line']) $line,
    %args
) {
    Tails::Persistence::Configuration::Atom->new(
        destination => $line->destination,
        options     => $line->options,
        %args,
    );
}

method _build_id () {
    'Custom';
}


=head1 METHODS

=cut

method equals_atom (
    (InstanceOf['Tails::Persistence::Configuration::Atom']) $other_atom
) {
    $self->destination eq $other_atom->destination
        and
    $self->options_are(@{$other_atom->options});
}

method equals_line (
    (InstanceOf['Tails::Persistence::Configuration::Line']) $line
) {
    $self->destination eq $line->destination
        and
    $self->options_are($line->all_options);
}

method options_are (@expected_options) {
    my @expected = sort(@expected_options);
    my @options  = sort($self->all_options);

    return unless @expected == @options;

    all { $_ } pairwise {
        defined($a) and defined($b) and $a eq $b
    } @expected, @options;
}

no Moo;
1;
