=head1 NAME

Tails::Persistence::Configuration - manage live-persistence.conf and presets

=cut

package Tails::Persistence::Configuration;
use Moo;
use MooX::late;
use MooX::HandlesVia;

use 5.10.1;
use strictures 2;
use autodie qw(:all);
use Carp;
use Carp::Assert::More;

use Function::Parameters;
use Tails::Persistence::Configuration::Atom;
use Tails::Persistence::Configuration::ConfigFile;
use Tails::Persistence::Configuration::Presets;
use Types::Path::Tiny qw{AbsPath};

use List::MoreUtils qw{none};
use Locale::gettext;
use POSIX;
setlocale(LC_MESSAGES, "");
textdomain("tails");

use namespace::clean;


=head1 ATTRIBUTES

=cut

has 'config_file_path' => (
    required  => 1,
    isa       => AbsPath,
    is        => 'rw',
    coerce    => AbsPath->coercion,
);

has 'file' => (
    lazy_build => 1,
    is         => 'rw',
    isa        => 'Tails::Persistence::Configuration::ConfigFile',
);
has 'presets' => (
    lazy_build => 1,
    is         => 'rw',
    isa        => 'Tails::Persistence::Configuration::Presets',
);
has 'force_enable_presets' => (
    is      => 'ro',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
);
has 'atoms' => (
    lazy_build => 1,
    is            => 'rw',
    isa           => 'ArrayRef[Tails::Persistence::Configuration::Atom]',
    handles_via   => 'Array',
    handles       => {
        all_atoms => 'elements',
        push_atom => 'push',
    },
);


=head1 CONSTRUCTORS

=cut

method _build_file () {
    my $file = Tails::Persistence::Configuration::ConfigFile->new(
        config_file_path => $self->config_file_path
    );
    return $file;
}

method _build_presets () {
    Tails::Persistence::Configuration::Presets->new();
}

method _build_atoms () {
    return $self->merge_file_with_presets();
}

=head1 METHODS

=cut

method lines_not_in_presets () {
    grep {
        my $line = $_;
        ! grep { $_->equals_line($line) } $self->presets->atoms
    } $self->file->all_lines;
}

method atoms_not_in_presets () {
    grep {
        my $atom = $_;
        none { $atom->equals_atom($_) } $self->presets->atoms
    } $self->all_atoms;
}

method merge_file_with_presets () {
    $self->presets->set_state_from_lines($self->file->all_lines);
    $self->presets->set_state_from_overrides($self->force_enable_presets);

    [
        $self->presets->atoms,
        map {
            Tails::Persistence::Configuration::Atom->new_from_line(
                $_,
                enabled => 1
            );
        } $self->lines_not_in_presets,
    ];
}

method all_enabled_atoms () {
    grep { $_->enabled } $self->all_atoms;
}

method all_enabled_lines () {
    map {
        Tails::Persistence::Configuration::Line->new(
            destination => $_->destination,
            options     => $_->options,
        )
    } $self->all_enabled_atoms;
}

method save () {
    $self->file->lines([ $self->all_enabled_lines ]);
    $self->file->save;
}

no Moo;
1;
