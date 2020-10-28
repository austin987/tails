=head1 NAME

Tails::Persistence::Configuration::Presets - available configuration snippets

=cut

package Tails::Persistence::Configuration::Presets;
use 5.10.1;
use strictures 2;
use Moo;
use MooX::HandlesVia;
use MooX::late;

with 'Tails::Role::HasEncoding';

use autodie qw(:all);
use Carp;
use Function::Parameters;
use List::MoreUtils qw{all};
use POSIX;
use Tails::Persistence::Configuration::Atom;
use Types::Standard qw(ArrayRef Str);

use Locale::TextDomain 'tails';

use namespace::clean;


=head1 ATTRIBUTES

=cut

has '_presets' => (
    lazy_build  => 1,
    is          => 'rw',
    isa         => 'ArrayRef',
    handles_via => 'Array',
    handles     => {
        count   => 'count',
        all     => 'elements',
    },
);


=head1 CONSTRUCTORS

=cut

method _build__presets () {
    my @presets = (
        {
            id          => 'PersonalData',
            name        => __(q{Personal Data}),
            description => __(
                q{Keep files stored in the `Persistent' directory}
            ),
            icon_name   => 'stock_folder',
            enabled     => 1,
            atoms_args  => [
                {
                    destination => '/home/amnesia/Persistent',
                    options     => [ 'source=Persistent' ],
                },
            ]
        },
        {
            id          => 'GreeterSettings',
            name        => __(q{Welcome Screen}),
            description => __(
                q{Language, administration password, and additional settings}
            ),
            icon_name   => 'preferences-system',
            enabled     => 0,
            atoms_args  => [
                {
                    destination => '/var/lib/gdm3/settings/persistent',
                    options     => [ 'source=greeter-settings' ],
                },
            ]
        },
        {
            id          => 'BrowserBookmarks',
            name        => __(q{Browser Bookmarks}),
            description => __(
                q{Bookmarks saved in the Tor Browser}
            ),
            icon_name   => 'user-bookmarks',
            enabled     => 0,
            atoms_args  => [
                {
                    destination => '/home/amnesia/.mozilla/firefox/bookmarks',
                    options     => [ 'source=bookmarks' ],
                },
            ],
        },
        {
            id          => 'NetworkConnections',
            name        => __(q{Network Connections}),
            description => __(
                q{Configuration of network devices and connections}
            ),
            icon_name   => 'network-wired',
            enabled     => 0,
            atoms_args  => [
                {
                    destination => '/etc/NetworkManager/system-connections',
                    options     => [ 'source=nm-system-connections' ],
                },
            ],
        },
        {
            id                  => 'AdditionalSoftware',
            name                => __(q{Additional Software}),
            description         => __(
                q{Software installed when starting Tails}
            ),
            icon_name           => 'package-x-generic',
            enabled             => 0,
            configuration_app_desktop_id => 'org.boum.tails.additional-software-config.desktop',
            atoms_args          => [
                {
                    destination => '/var/cache/apt/archives',
                    options     => [ 'source=apt/cache' ],
                },
                {
                    destination => '/var/lib/apt/lists',
                    options     => [ 'source=apt/lists' ],
                },
            ],
        },
        {
            id          => 'Printers',
            name        => __(q{Printers}),
            description => __(
                q{Printers configuration}
            ),
            icon_name   => 'printer',
            enabled     => 0,
            atoms_args  => [
                {
                    destination => '/etc/cups',
                    options     => [ 'source=cups-configuration' ],
                },
            ],
        },
        {
            id          => 'Thunderbird',
            name        => __(q{Thunderbird}),
            description => __(
                q{Thunderbird emails, feeds, and OpenPGP keys}
            ),
            icon_name   => 'thunderbird',
            enabled     => 0,
            atoms_args  => [
                {
                    destination => '/home/amnesia/.thunderbird',
                    options     => [ 'source=thunderbird' ],
                },
            ],
        },
        {
            id          => 'GnuPG',
            name        => __(q{GnuPG}),
            description => __(
                q{OpenPGP keys outside of Thunderbird}
            ),
            icon_name   => 'seahorse-key',
            enabled     => 0,
            atoms_args  => [
                {
                    destination => '/home/amnesia/.gnupg',
                    options     => [ 'source=gnupg' ],
                },
            ],
        },
        {
            id          => 'BitcoinClient',
            name        => __(q{Bitcoin Client}),
            description => __(
                q{Electrum's bitcoin wallet and configuration}
            ),
            icon_name   => 'electrum',
            enabled     => 0,
            atoms_args  => [
                {
                    destination => '/home/amnesia/.electrum',
                    options     => [ 'source=electrum' ],
                },
            ],
        },
        {
            id          => 'Pidgin',
            name        => __(q{Pidgin}),
            description => __(
                q{Pidgin profiles and OTR keyring}
            ),
            icon_name   => 'pidgin',
            enabled     => 0,
            atoms_args  => [
                {
                    destination => '/home/amnesia/.purple',
                    options     => [ 'source=pidgin' ],
                },
            ],
        },
        {
            id          => 'SSHClient',
            name        => __(q{SSH Client}),
            description => __(
                q{SSH keys, configuration and known hosts}
            ),
            icon_name   => 'seahorse-key-ssh',
            enabled     => 0,
            atoms_args  => [
                {
                    destination => '/home/amnesia/.ssh',
                    options     => [ 'source=openssh-client'],
                },
            ],
        },
        {
            id          => 'Dotfiles',
            name        => __(q{Dotfiles}),
            description => __(
                q{Symlink into $HOME every file or directory found in the `dotfiles' directory}
            ),
            icon_name   => 'preferences-desktop',
            enabled     => 0,
            atoms_args  => [
                {
                    destination => '/home/amnesia',
                    options     => [ 'source=dotfiles', 'link' ],
                },
            ],
        },
    );

    foreach my $preset (@presets) {
        my @atoms;
        foreach my $atom_init_args (@{$preset->{atoms_args}}) {
            push @atoms, Tails::Persistence::Configuration::Atom->new(
                id          => $preset->{id},
                name        => $preset->{name},
                description => $preset->{description},
                enabled     => $preset->{enabled},
                %{$atom_init_args}
            );
        }
        $preset->{atoms} = \@atoms;
        delete $preset->{atom_args};
    }

    return \@presets;
}

method atoms () {
    my @atoms;
    foreach my $preset ($self->all) {
        push @atoms, @{$preset->{atoms}};
    }
    return @atoms;
}


=head1 METHODS

=cut

method set_state_from_lines (@lines) {
    foreach my $atom ($self->atoms) {
        $atom->enabled(1) if grep { $atom->equals_line($_) } @lines;
    }
    foreach my $preset ($self->all) {
        $self->{enabled} = all { $_->enabled } @{$preset->{atoms}};
    }
}

method set_state_from_overrides (ArrayRef[Str] $overrides) {
    foreach my $atom ($self->atoms) {
        $atom->enabled(1) if grep { $atom->id eq $_ } @$overrides;
    }
}

no Moo;
1;
