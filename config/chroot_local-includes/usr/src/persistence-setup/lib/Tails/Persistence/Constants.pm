package Tails::Persistence::Constants;
use 5.10.1;
use strictures 2;
use Moo;
use MooX::late;
use Types::Path::Tiny qw{AbsPath};

use autodie qw(:all);
use Function::Parameters;

use namespace::clean;


=head1 Attributes

=cut
for (qw{partition_label partition_guid filesystem_type filesystem_label}) {
    has "persistence_$_" => (
        lazy_build => 1,
        is         => 'ro',
        isa        => 'Str',
    );
}

has "persistence_minimum_size"       => (
    lazy_build => 1,
    is         => 'ro',
    isa        => 'Int',
);

has 'persistence_filesystem_options' => (
    lazy_build => 1,
    is         => 'ro',
    isa        => 'HashRef[Str]',
);

has 'persistence_state_file'         => (
    isa        => AbsPath,
    is         => 'ro',
    lazy_build => 1,
    coerce     => AbsPath->coercion,
    documentation => q{File where tails-greeter writes persistence state.},
);


=head1 Constructors

=cut
method _build_persistence_partition_label () {
    'TailsData'
}
method _build_persistence_minimum_size () {
    64 * 2 ** 20
}
method _build_persistence_filesystem_type () {
    'ext4'
}
method _build_persistence_filesystem_label () {
    'TailsData'
}

method _build_persistence_filesystem_options () {
    {
        label => $self->persistence_filesystem_label,
    };
}

method _build_persistence_partition_guid () {
    '8DA63339-0007-60C0-C436-083AC8230908' # Linux reserved
}

method _build_persistence_state_file () {
    '/var/lib/live/config/tails.persistence'
}

no Moo;
1; # End of Tails::Persistence::Constants
