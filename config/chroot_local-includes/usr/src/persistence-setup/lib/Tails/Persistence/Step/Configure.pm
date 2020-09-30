=head1 NAME

Tails::Persistence::Step::Configure - configure which bits are persistent

=cut

package Tails::Persistence::Step::Configure;

use 5.10.1;
use strictures 2;

use Carp::Assert::More;
use Function::Parameters;
use Glib qw{TRUE FALSE};
use Number::Format qw(:subs);
use POSIX;
use Tails::Persistence::Configuration;
use Tails::Persistence::Configuration::Setting;
use Try::Tiny;

use Locale::TextDomain 'tails';

use Moo;
use MooX::late;
use MooX::HandlesVia;
use namespace::clean;


=head1 ATTRIBUTES

=cut

has 'configuration' => (
    required => 1,
    is       => 'ro',
    isa      => 'Tails::Persistence::Configuration',
);

has 'persistence_partition_device_file' => (
    required => 1,
    is       => 'ro',
    isa      => 'Str',
);
has 'persistence_partition_size' => (
    required => 1,
    is       => 'ro',
    isa      => 'Int',
);

has 'list_box' => (
    lazy_build => 1,
    is         => 'ro',
    isa        => 'Gtk3::ListBox',
);

has 'settings_container' => (
    lazy_build => 1,
    is         => 'ro',
    isa        => 'Gtk3::ScrolledWindow',
);

has 'settings' => (
    lazy_build  => 1,
    is          => 'ro',
    isa         => 'ArrayRef[Tails::Persistence::Configuration::Setting]',
    handles_via => [ 'Array' ],
    handles     => {
        all_settings  => 'elements',
        push_settings => 'push',
    },
);


=head1 CONSTRUCTORS

=cut

method BUILD (@args) {
    # Force initialization in the right order
    assert_defined($self->configuration);
    assert_defined($self->settings);
    assert_defined($self->list_box);
    assert_defined($self->settings_container);

    $self->title->set_text(__(
        q{Persistence wizard - Persistent volume configuration}
    ));
    $self->subtitle->set_text(__(
        q{Specify the files that will be saved in the persistent volume}
    ));
    $self->description->set_markup(__x(
        q{The selected files will be stored in the encrypted partition {partition} ({size}), on the <b>{vendor} {model}</b> device.},
        partition => $self->persistence_partition_device_file,
        size      => format_bytes($self->persistence_partition_size, mode => "iec"),
        vendor    => $self->drive_vendor,
        model     => $self->drive_model,
    ));
    $self->go_button->set_label(__(q{Save}));
    $self->go_button->set_sensitive(TRUE);
}

method _build_settings_container () {
    my $viewport = Gtk3::Viewport->new;
    $viewport->set_shadow_type('GTK_SHADOW_NONE');
    $viewport->add($self->list_box);

    my $scrolled_win = Gtk3::ScrolledWindow->new;
    $scrolled_win->set_policy('automatic', 'automatic');
    $scrolled_win->set_overlay_scrolling(FALSE);
    $scrolled_win->add($viewport);

    return $scrolled_win;
}

method _build_main_widget () {
    my $box = Gtk3::VBox->new();
    $box->set_spacing(6);
    $box->pack_start($self->title, FALSE, FALSE, 0);
    $box->pack_start($self->subtitle, FALSE, FALSE, 0);
    $box->pack_start($self->description, FALSE, FALSE, 0);
    $box->pack_start($self->settings_container, TRUE, TRUE, 0);
    $box->pack_start($self->status_area, FALSE, FALSE, 0);

    my $button_alignment = Gtk3::Alignment->new(1.0, 0, 0.2, 1.0);
    $button_alignment->set_padding(0, 0, 10, 10);
    $button_alignment->add($self->go_button);
    $box->pack_start($button_alignment, FALSE, FALSE, 0);

    return $box;
}

method _build_settings () {
    my @settings;
    foreach my $preset ($self->configuration->presets->all) {
        my %init_args;
        if (exists($preset->{configuration_app_desktop_id})
                && defined($preset->{configuration_app_desktop_id})) {
            $init_args{configuration_app_desktop_id} = $preset->{configuration_app_desktop_id};
        }
        push @settings,
            Tails::Persistence::Configuration::Setting->new(
                id          => $preset->{id},
                atoms       => $preset->{atoms},
                name        => $preset->{name},
                description => $preset->{description},
                icon_name   => $preset->{icon_name},
                enabled     => $preset->{enabled},
                %init_args,
            );
    }
    foreach my $atom ($self->configuration->atoms_not_in_presets) {
        push @settings,
            Tails::Persistence::Configuration::Setting->new(atoms => [$atom]);
    }
    return \@settings;
}

method _build_list_box () {
    my $list_box = Gtk3::ListBox->new();
    $list_box->set_selection_mode('GTK_SELECTION_NONE');
    foreach my $setting ($self->all_settings) {
        $list_box->insert($setting->main_widget, -1);
        $list_box->insert(Gtk3::Separator->new('GTK_ORIENTATION_HORIZONTAL'), -1);
    }

    return $list_box;
}


=head1 METHODS

=cut

method operation_finished ($error = undef) {
    if ($error) {
        $self->working(0);
        say STDERR "$error";
        $self->subtitle->set_text(__(q{Failed}));
        $self->description->set_text($error);
    }
    else {
        say STDERR "done.";
        $self->working(0);
        $self->success_callback->();
    }
}

method go_button_pressed () {
    $self->settings_container->hide;
    $self->working(1);
    $self->subtitle->set_text(__(q{Saving...}));
    $self->description->set_text(
        __(q{Saving persistence configuration...}),
    );

    my $error;
    try {
        $self->go_callback->();
    } catch {
        $error = $@;
    };
    $self->operation_finished($error);
}

with 'Tails::Persistence::Role::StatusArea';
with 'Tails::Persistence::Role::SetupStep';

no Moo;
1;
