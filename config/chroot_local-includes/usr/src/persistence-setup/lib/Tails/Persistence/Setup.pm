=head1 NAME

Tails::Persistence::Setup - main application class

=cut

package Tails::Persistence::Setup;

use 5.10.1;
use strictures 2;

use autodie qw(:all);
use Carp::Assert::More;
use English qw{-no_match_vars};
use Function::Parameters;
use Glib qw{TRUE FALSE};
use Gtk3 qw{-init};
use Net::DBus qw(:typing);
use Net::DBus::Annotation qw(:call);
use List::Util qw{first min max};
use Number::Format qw(:subs);
use Path::Tiny;
use Types::Standard qw(Str HashRef);
use Try::Tiny;
use Types::Path::Tiny qw{Dir};

use Tails::RunningSystem;
use Tails::UDisks;
use Tails::Persistence::Configuration;
use Tails::Persistence::Constants;
use Tails::Persistence::Step::Bootstrap;
use Tails::Persistence::Step::Configure;
use Tails::Persistence::Step::Delete;
use Tails::Persistence::Utils qw{align_up_at_2MiB align_down_at_2MiB step_name_to_class_name get_variable_from_file check_config_file_permissions};

use Locale::gettext;
use POSIX;
setlocale(LC_MESSAGES, "");
textdomain("tails");

no Moo::sification;
use Moo;
use MooX::late;
use MooX::HandlesVia;

with 'Tails::Role::DisplayError::Gtk3';
with 'Tails::Role::HasDBus::System';
with 'Tails::Role::HasEncoding';

use namespace::clean;

use MooX::Options;


=head1 ATTRIBUTES

=cut

option 'verbose' => (
    is            => 'ro',
    isa           => 'Bool',
    documentation => q{Get more output.},
    default       => sub {
        exists $ENV{DEBUG} && defined $ENV{DEBUG} && $ENV{DEBUG}
    },
);

option 'force' => (
    lazy_build    => 1,
    is            => 'ro',
    isa           => 'Bool',
    documentation => q{Make some sanity checks non-fatal.},
);

has 'udisks' => (
    lazy_build => 1,
    is         => 'ro',
    isa        => 'Tails::UDisks',
    handles    => [
        qw{bytes_array_to_string device_has_partition_with_label
           drive_is_optical drive_is_connected_via_a_supported_interface
           device_partition_with_label get_block_device_property
           get_filesystem_property get_partition_property luks_holder
           mountpoints partitions udisks_service}
    ],
);

has 'running_system' => (
    lazy_build => 1,
    is         => 'ro',
    isa        => 'Tails::RunningSystem',
    handles    => [
        qw{boot_drive boot_block_device boot_device_file boot_drive_model boot_drive_vendor
           boot_drive_size
           started_from_device_installed_with_tails_installer}
    ],
);

has 'persistence_constants' => (
    lazy_build => 1,
    is         => 'ro',
    isa        => 'Tails::Persistence::Constants',
    handles    => [
        map {
            "persistence_$_"
        } qw{partition_label partition_guid filesystem_type filesystem_label
             minimum_size filesystem_options state_file}
    ],
);

has 'main_window' => (
    lazy_build => 1,
    is         => 'ro',
    isa        => 'Gtk3::Window',
);

option "$_" => (
    is         => 'ro',
    format     => 's',
    isa        => 'Str',
    predicate  => 1,
) for (qw{override_liveos_mountpoint override_boot_drive
          override_system_partition});

has 'persistence_partition_device_file' => (
    lazy_build => 1,
    is         => 'ro',
    isa        => 'Str',
);
has 'persistence_partition_size' => (
    lazy_build => 1,
    is         => 'ro',
    isa        => 'Int',
);
has 'persistence_is_enabled' => (
    lazy_build => 1,
    is         => 'ro',
    isa        => 'Bool',
);

has 'persistence_partition_mountpoint' => (
    isa        => Dir,
    is         => 'rw',
    lazy_build => 1,
    coerce     => Dir->coercion,
);

foreach (qw{beginning_of_free_space size_of_free_space}) {
    has $_ => (
        lazy_build => 1,
        is         => 'ro',
        isa        => 'Int',
    );
}

has 'current_step' => (
    is        => 'rw',
    isa       => 'Object',
    predicate => 'has_current_step',
);

option 'steps' => (
    lazy_build    => 1,
    required      => 1,
    repeatable    => 1,
    format        => 's@',
    is            => 'rw',
    isa           => 'ArrayRef[Str]',
    handles_via   => ['Array'],
    handles       => {
        number_of_steps => 'count',
        shift_steps     => 'shift',
        next_step       => 'first',
    },
    documentation => q{Specify once per wizard step to run. Supported steps are: bootstrap, configure, delete.},
);

has 'configuration' => (
    lazy_build => 1,
    is         => 'rw',
    isa        => 'Tails::Persistence::Configuration',
    handles    => { save_configuration => 'save' },
);

option 'force_enable_presets' => (
    is            => 'ro',
    repeatable    => 1,
    format        => 's@',
    isa           => 'ArrayRef[Str]',
    handles_via   => ['Array'],
    documentation => q{Specify once per additional preset to forcibly enable.},
    default       => sub { [] },
);

option 'display_finished_message' => (
    is            => 'ro',
    isa           => 'Bool',
    documentation => q{Display an explanatory message once done.},
    default       => sub { 1 },
    negativable   => 1,
);

option 'gui' => (
    is            => 'ro',
    isa           => 'Bool',
    documentation => q{Display the GUI. Only a few operations are available under --no-gui.},
    default       => sub { 1 },
    negativable   => 1,
);


=head1 CONSTRUCTORS AND BUILDERS

=cut

method BUILD (@args) {
    if (! $self->gui) {
        assert_is($self->number_of_steps, 1,
                  "Exactly one step is enabled under --no-gui");
        assert_is($self->steps->[0], 'configure',
                  "The requested step is 'configure' under --no-gui");
    }
}

method _build_force () { 0; }

method _build_persistence_constants () { Tails::Persistence::Constants->new(); }
method _build_udisks () { Tails::UDisks->new(); }

method _build_running_system () {

    my @args;
    for (qw{liveos_mountpoint boot_drive system_partition}) {
        my $attribute = "override_$_";
        my $predicate = "has_$attribute";
        if ($self->$predicate) {
            push @args, ($_ => $self->$attribute)
        }
    }

    Tails::RunningSystem->new(main_window => $self->main_window, @args);
}

method _build_persistence_is_enabled () {
    -e $self->persistence_state_file || return 0;
    -r $self->persistence_state_file || return 0;

    my $value = $self->get_variable_from_persistence_state_file(
        'TAILS_PERSISTENCE_ENABLED'
    );
    defined($value) && $value eq 'true';
}

method _build_steps () {
    if ($self->device_has_persistent_volume) {
        return [ qw{configure} ];
    }
    else {
        return [ qw{bootstrap configure} ]
    }
}

method _build_main_window () {
    my $win = Gtk3::Window->new('toplevel');
    $win->set_title($self->encoding->decode(gettext('Setup Tails persistent volume')));

    $win->set_border_width(10);

    $win->add($self->current_step->main_widget) if $self->has_current_step;
    $win->signal_connect('destroy' => sub { Gtk3->main_quit; });
    $win->signal_connect('key-press-event' => sub {
        my $twin = shift;
        my $event = shift;
        $win->destroy if $event->key->{keyval} == Gtk3::Gdk::keyval_from_name('Escape');
    });
    $win->set_default($self->current_step->go_button) if $self->has_current_step;

    return $win;
}

method _build_persistence_partition_mountpoint () {
    first {
           $_ eq '/live/persistence/TailsData_unlocked'
        or $_ eq '/media/'.getpwuid($UID).'/TailsData'
    } $self->mountpoints($self->persistence_partition);
}

method _build_beginning_of_free_space () {
    align_up_at_2MiB(
        max(
            map {
                $self->get_partition_property($_, 'Offset')
              + $self->get_partition_property($_, 'Size')
            } $self->partitions($self->boot_block_device)
        )
    );
}

method _build_size_of_free_space () {
    align_down_at_2MiB(
        $self->get_block_device_property($self->boot_block_device, 'Size')
      - $self->beginning_of_free_space
  );
}

method _build_persistence_partition_device_file () {
    return $self->bytes_array_to_string($self->get_block_device_property(
        $self->persistence_partition, 'PreferredDevice'
    ));
}

method _build_persistence_partition_size () {
    $self->get_block_device_property($self->persistence_partition, 'Size');
}

method _build_configuration () {
    my $config_file_path = path($self->persistence_partition_mountpoint, 'persistence.conf');
    if (-e $config_file_path) {
        # In Tails, tails-persistence-setup runs as the tails-persistence-setup
        # user and the configuration file must be owned by
        # tails-persistence-setup:tails-persistence-setup.
        # When developing outside of Tails, the configuration file is also owned
        # by the user:group that runs tails-persistence-setup.
        # So in all cases, we effectively want the configuration file
        # to be owned by the user:group that runs tails-persistence-setup.
        my $expected_uid = getuid();
        my $expected_gid = getgid();
        $self->debug("Expected ownership: ${expected_uid}:${expected_gid}");
        try {
            check_config_file_permissions(
                $config_file_path,
                {
                    uid  => $expected_uid,
                    gid  => $expected_gid,
                    mode => oct(600),
                    acl  => '',
                }
            );
        }
        catch {
            $self->display_error(
                $self->main_window,
                $self->encoding->decode(gettext('Error')),
                $self->encoding->decode(gettext(
                    $_,
                )));
            exit 4;
        };
    }

    Tails::Persistence::Configuration->new(
        config_file_path     => $config_file_path,
        force_enable_presets => $self->force_enable_presets,
    );
}


=head1 METHODS

=cut

method debug (Str $mesg) {
    say STDERR $self->encoding->encode($mesg) if $self->verbose;
}

method check_sanity (Str $step_name) {
    my %step_checks = (
        'bootstrap' => [
            {
                method  => 'device_has_persistent_volume',
                message => $self->encoding->decode(gettext(
                    "Device %s already has a persistent volume.")),
                must_be_false    => 1,
                can_be_forced    => 1,
                needs_device_arg => 1,
            },
            {
                method  => 'device_has_enough_free_space',
                message => $self->encoding->decode(gettext(
                    "Device %s has not enough unallocated space.")),
            },
        ],
        'delete' => [
            {
                method  => 'device_has_persistent_volume',
                message => $self->encoding->decode(gettext(
                    "Device %s has no persistent volume.")),
                needs_device_arg => 1,
            },
            {
                method  => 'persistence_is_enabled',
                message => $self->encoding->decode(gettext(
                    "Cannot delete the persistent volume on %s while in use. You should restart Tails without persistence.")),
                must_be_false => 1,
            },
        ],
        'configure' => [
            {
                method  => 'device_has_persistent_volume',
                message => $self->encoding->decode(gettext(
                    "Device %s has no persistent volume.")),
                needs_device_arg => 1,
            },
            {
                method  => 'persistence_partition_is_unlocked',
                message => $self->encoding->decode(gettext(
                    "Persistence volume on %s is not unlocked.")),
            },
            {
                method  => 'persistence_filesystem_is_mounted',
                message => $self->encoding->decode(gettext(
                    "Persistence volume on %s is not mounted.")),
            },
            {
                method  => 'persistence_filesystem_is_readable',
                message => $self->encoding->decode(gettext(
                    "Persistence volume on %s is not readable. Permissions or ownership problems?")),
            },
            {
                method  => 'persistence_filesystem_is_writable',
                message => $self->encoding->decode(gettext(
                    "Persistence volume on %s is not writable.")),
            },
        ],
    );

    my @checks = (
        {
            method  => 'drive_is_connected_via_a_supported_interface',
            message => $self->encoding->decode(gettext(
                "Tails is running from non-USB / non-SDIO device %s.")),
            needs_drive_arg => 1,
        },
        {
            method  => 'drive_is_optical',
            message => $self->encoding->decode(gettext(
                "Device %s is optical.")),
            must_be_false    => 1,
            needs_drive_arg => 1,
        },
        {
            method  => 'started_from_device_installed_with_tails_installer',
            message => $self->encoding->decode(gettext(
                "Device %s was not created using a USB image or Tails Installer.")),
            must_be_false => 0,
        },
    );
    if ($step_name
        && exists  $step_checks{$step_name}
        && defined $step_checks{$step_name}
    ) {
        push @checks, @{$step_checks{$step_name}};
    }

    foreach my $check (@checks) {
        my $check_method = $self->can($check->{method});
        assert_defined($check_method);
        my $res;
        my @args = ($self);
        if (exists($check->{needs_device_arg}) && $check->{needs_device_arg}) {
            push @args, $self->boot_block_device;
        }
        elsif (exists($check->{needs_drive_arg}) && $check->{needs_drive_arg}) {
            push @args, $self->boot_drive;
        }
        $res = $check_method->(@args);
        if (exists($check->{must_be_false}) && $check->{must_be_false}) {
            $res = ! $res;
        }
        if (! $res) {
            my $message = $self->encoding->decode(sprintf(
                gettext($check->{message}),
                $self->boot_device_file));
            if ($self->force && exists($check->{can_be_forced}) && $check->{can_be_forced}) {
                say STDERR "$message",
                     "... but --force is enabled, ignoring results of this sanity check.";
            }
            else {
                $self->display_error(
                    $self->main_window,
                    $self->encoding->decode(gettext('Error')),
                    $message
                );
                return;
            }
        }
    }

    return 1;
}

method run () {
    $self->debug("Entering Tails::Persistence::Setup::run");
    $self->debug(sprintf("Working on device %s", $self->boot_device_file));

    $self->main_window->set_visible(FALSE);
    $self->goto_next_step;
    if ($self->gui) {
        $self->debug("Entering main Gtk3 loop.");
        Gtk3->main;
    }
}

method device_has_persistent_volume ($device = undef) {
    $device ||= $self->boot_block_device;
    $self->debug("Entering device_has_persistent_volume");
    return $self->device_has_partition_with_label($device, $self->persistence_partition_label);
}

method device_has_enough_free_space () {
    $self->size_of_free_space >= $self->persistence_minimum_size;
}

method persistence_partition () {
    $self->debug("Entering persistence_partition");
    $self->device_partition_with_label(
        $self->boot_block_device,
        $self->persistence_partition_label
    );
}

method create_persistence_partition (HashRef $opts) {
    $opts->{end_cb}    ||= sub { say STDERR "finished." };

    $self->debug("Entering create_persistence_partition");

    my $offset    = $self->beginning_of_free_space;
    my $size      = $self->size_of_free_space;
    my $type      = $self->persistence_partition_guid;
    my $label     = $self->persistence_partition_label;
    my $options   = {};

    $self->debug(sprintf(
        "Creating partition of size %s at offset %s on device %s",
        format_bytes($size, mode => "iec"), $offset, $self->boot_device_file
    ));

    $self->udisks_service->get_object($self->boot_block_device)
         ->as_interface('org.freedesktop.UDisks2.PartitionTable')
         ->CreatePartition(dbus_call_async, $offset, $size, $type, $label, $options)
         ->set_notify(sub {
             $self->create_persistent_encrypted_filesystem($opts, @_);
         });

    $self->debug("waiting...");
}

method create_persistent_encrypted_filesystem (
    HashRef $opts,
    $create_partition_reply
) {
    $opts->{end_cb}    ||= sub { say STDERR "finished." };
    my ($created_device, $create_partition_error);

    $self->debug("Entering create_persistent_encrypted_filesystem");

    # For some reason, we cannot get the exception when Try::Tiny is used,
    # so let's do it by hand.
    {
        local $@;
        eval { $created_device = $create_partition_reply->get_result };
        $create_partition_error = $@;
    }
    if ($create_partition_error) {
        return $opts->{end_cb}->({
            create_partition_error => $create_partition_error,
        });
    }

    my $fstype    = $self->persistence_filesystem_type;
    my $fsoptions = {
        %{$self->persistence_filesystem_options},
        'encrypt.passphrase' => $opts->{passphrase},
    };

    $self->udisks_service->get_object($self->persistence_partition)
         ->as_interface('org.freedesktop.UDisks2.Block')
         ->Format(
             dbus_call_async, dbus_call_timeout, 3600 * 1000,
             $fstype, $fsoptions)
         ->set_notify(sub { $opts->{end_cb}->({
             created_device => $created_device,
             format_reply   => @_,
         })});

    $self->debug("waiting...");
}

method delete_persistence_partition (HashRef $opts = {}) {
    $opts->{end_cb}    ||= sub { say STDERR "finished." };

    $self->debug(sprintf("Deleting partition %s", $self->persistence_partition_device_file));

    my $obj = $self->udisks_service->get_object($self->persistence_partition);

    # lock the device if it is unlocked
    my $luksholder = $self->luks_holder($self->persistence_partition);
    if ($luksholder) {
        if ($self->persistence_filesystem_is_mounted) {
            $self->udisks_service
                ->get_object($luksholder)
                ->as_interface("org.freedesktop.UDisks2.Filesystem")
                ->Unmount({})
        }
        $obj->as_interface('org.freedesktop.UDisks2.Encrypted')->Lock({});
    }

    # TODO: wipe the LUKS header (#8436)

    my $iface = $obj->as_interface("org.freedesktop.UDisks2.Partition");
    $iface->Delete(dbus_call_async, {})->set_notify($opts->{end_cb});
    $self->debug("waiting...");
}

method mount_persistence_partition () {
    $self->debug(sprintf("Mounting partition %s", $self->persistence_partition_device_file));

    my $luks_holder = $self->luks_holder($self->persistence_partition);

    return $self->udisks_service
         ->get_object($luks_holder)
         ->as_interface("org.freedesktop.UDisks2.Filesystem")
         ->Mount(dbus_call_sync, {});
}

method empty_main_window () {
    my $child = $self->main_window->get_child;
    $self->main_window->remove($child) if defined($child);
}

method run_current_step () {
    my ($width, $height) = $self->main_window->get_size();

    $self->debug("Running step " . $self->current_step->name);

    if ($self->gui) {
        $self->current_step->working(0);
        $self->empty_main_window;
        $self->main_window->add($self->current_step->main_widget);
        $self->main_window->set_default($self->current_step->go_button);
        $self->main_window->show_all;
        $self->current_step->working(0);
        $self->main_window->set_visible(TRUE);

        if($self->current_step->name eq 'configure') {
            $self->main_window->resize(
                $width,
                max(
                    900,
                    min(450, $self->main_window->get_screen()->get_height()),
                )
            );
        }
        else {
            $self->main_window->resize($width, $height);
        }
    } else {
        $self->debug("run_current_step: starting go_button_pressed...");
        $self->current_step->go_button_pressed;
        $self->debug("run_current_step: go_button_pressed exited.");
    }
}

method goto_next_step () {
    my $next_step;

    if ($next_step = $self->shift_steps) {
        if ($self->check_sanity($next_step)) {
            $self->current_step($self->step_object_from_name($next_step));
            $self->run_current_step;
        }
        else {
            # check_sanity already has displayed an error dialog,
            # that the user already closed.
            exit 2;
        }
    }
    else {
        $self->debug("No more steps.");
        if (! $self->display_finished_message) {
            if ($self->gui) {
                Gtk3->main_quit;
            } else {
                return;
            }
        }
        $self->current_step->title->set_text($self->encoding->decode(gettext(
            q{Persistence wizard - Finished}
        )));
        $self->current_step->subtitle->set_text($self->encoding->decode(gettext(
            q{Any changes you have made will only take effect after restarting Tails.

You may now close this application.}
        )));
        $self->current_step->description->set_text(' ');
        $self->current_step->go_button->hide;
        $self->current_step->status_area->hide;
    }
}

method step_object_from_name (Str $name) {
    my $class_name = step_name_to_class_name($name);

    my %init_args;

    if ($name eq 'bootstrap') {
        %init_args = (
            go_callback => sub {
                $self->create_persistence_partition({ @_ })
            },
            size_of_free_space          => $self->size_of_free_space,
            mount_persistence_partition_cb => sub {
                $self->mount_persistence_partition
            },
            create_configuration_cb        => sub {
                $self->save_configuration;
                my $asp_config_file = path(
                    $self->persistence_partition_mountpoint,
                    'live-additional-software.conf'
                );
                $asp_config_file->touch;
                $asp_config_file->chmod(0644);
            },
        );
    }
    elsif ($name eq 'delete') {
        %init_args = (
            go_callback => sub {
                $self->delete_persistence_partition({ @_ })
            },
            persistence_partition      => $self->persistence_partition,
            persistence_partition_device_file => $self->persistence_partition_device_file,
            persistence_partition_size => $self->persistence_partition_size,
        );
    }
    elsif ($name eq 'configure') {
        %init_args = (
            go_callback                => sub { $self->save_configuration },
            configuration              => $self->configuration,
            persistence_partition      => $self->persistence_partition,
            persistence_partition_device_file => $self->persistence_partition_device_file,
            persistence_partition_size => $self->persistence_partition_size,
        );
    }

    return $class_name->new(
        name             => $name,
        encoding         => $self->encoding,
        success_callback => sub { $self->goto_next_step },
        drive_vendor     => $self->boot_drive_vendor,
        drive_model      => $self->boot_drive_model,
        %init_args
    );

}

method get_variable_from_persistence_state_file (Str $variable) {
    get_variable_from_file($self->persistence_state_file->stringify, $variable);
}

method persistence_filesystem_is_mounted () {
    return scalar($self->mountpoints($self->persistence_partition));
}

method persistence_partition_is_unlocked () {
    my $luks_holder = $self->luks_holder($self->persistence_partition) || return;

    return 1;
}

method persistence_filesystem_is_readable () {
    return unless my $mountpoint = $self->persistence_partition_mountpoint;
    my $ret;
    {
        use filetest 'access'; # take ACLs into account
        $ret = -r $self->persistence_partition_mountpoint;
    }
    return $ret;
}

method persistence_filesystem_is_writable () {
    return unless my $mountpoint = $self->persistence_partition_mountpoint;
    my $ret;
    {
        use filetest 'access'; # take ACLs into account
        $ret = -w $self->persistence_partition_mountpoint;
    }
    return $ret;
}

no Moo;
1;
