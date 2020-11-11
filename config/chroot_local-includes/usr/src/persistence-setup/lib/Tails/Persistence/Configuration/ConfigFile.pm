=head1 NAME

Tails::Persistence::Configuration::ConfigFile - read, parse and write live-persistence.conf

=cut

package Tails::Persistence::Configuration::ConfigFile;
use 5.10.1;
use strictures 2;
use Moo;
use MooX::late;
use MooX::HandlesVia;

use autodie qw(:all);
use Carp;
use Function::Parameters;
use IPC::System::Simple qw{systemx};
use Tails::Persistence::Configuration::Line;
use Types::Path::Tiny qw{AbsPath};

use namespace::clean;


=head1 ATTRIBUTES

=cut

has 'config_file_path' => (
    isa      => AbsPath,
    is       => 'ro',
    coerce   => AbsPath->coercion,
    required => 1,
);

has 'backup_config_file_path' => (
    lazy_build => 1,
    isa        => AbsPath,
    is         => 'ro',
    coerce     => AbsPath->coercion,
);

has 'lines' => (
    lazy_build    => 1,
    is            => 'rw',
    isa           => 'ArrayRef[Tails::Persistence::Configuration::Line]',
    handles_via   => [ 'Array' ],
    handles       => {
        all_lines => 'elements',
    },
);


=head1 CONSTRUCTORS

=cut

method BUILD (@args) {
    $self->config_file_path->exists || $self->config_file_path->touch;
}

method _build_lines () {
    return [
        grep { defined $_ } map {
            Tails::Persistence::Configuration::Line->new_from_string($_)
        } $self->config_file_path->lines({chomp => 1})
    ];
}

method _build_backup_config_file_path () {
    $self->config_file_path . '.bak';
}

=head1 METHODS

=cut

=head2 output

Returns the in-memory configuration, as a string in the live-persistence.conf format.

=cut
method output () {
    my $out = "";
    foreach ($self->all_lines) {
        $out .= $_->stringify . "\n";
    }
    return $out;
}

=head2 backup

Copy the on-disk configuration file to a backup file.

=cut

method backup () {
    $self->config_file_path->copy($self->backup_config_file_path);
    $self->backup_config_file_path->chmod(0600);
    # Ensure our changes land on the disk
    systemx('sync', $self->backup_config_file_path->stringify);
    systemx('sync', $self->backup_config_file_path->parent->stringify);
    # Ensure changes made elsewhere are written synchronously on the disk
    # (in case something else ever needs to modify this file)
    systemx('chattr', '+S', $self->backup_config_file_path->stringify)
        # chattr is not supported on overlayfs (GitLab CI in Docker,
        # running the test suite from inside Tails)
        unless $ENV{AUTOMATED_TESTING};
}

=head2 save

Save the in-memory configuration to disk.
Throw exception on error.

=cut
method save () {
    my $config_file_was_empty = ! -s $self->config_file_path;
    $self->backup unless $config_file_was_empty;
    $self->config_file_path->spew($self->output);
    $self->config_file_path->chmod(0600);
    # Ensure our changes land on the disk
    systemx('sync', $self->config_file_path->stringify);
    systemx('sync', $self->config_file_path->parent->stringify);
    # Ensure changes made by other code (e.g. live-persist) are written
    # synchronously on the disk
    systemx('chattr', '+S', $self->config_file_path->stringify)
        # chattr is not supported on overlayfs (GitLab CI in Docker,
        # running the test suite from inside Tails)
        unless $ENV{AUTOMATED_TESTING};
    # When persistence.conf was initially empty (for example, when
    # we're initializing a new persistent volume), let's backup the
    # (probably non-empty) version of it that we've just saved.
    $self->backup if $config_file_was_empty;
}

no Moo;
1;
