=head1 NAME

Tails::Persistence::Step::Bootstrap - bootstrap persistent storage

=cut

package Tails::Persistence::Step::Bootstrap;

use 5.10.1;
use strictures 2;

use Function::Parameters;
use Glib qw{TRUE FALSE};

use IPC::System::Simple qw{systemx};
use Number::Format qw(:subs);
use Types::Standard qw(HashRef);

use Locale::gettext;
use POSIX;
setlocale(LC_MESSAGES, "");
textdomain("tails");

use Moo;
use MooX::late;
use namespace::clean;


=head1 ATTRIBUTES

=cut

foreach (qw{intro label verify_label warning_label}) {
    has $_ => (
        lazy_build => 1,
        is         => 'rw',
        isa        => 'Gtk3::Label',
    );
}

foreach (qw{passphrase_entry verify_passphrase_entry}) {
    has $_ => (
        lazy_build => 1,
        is         => 'rw',
        isa        => 'Gtk3::Entry',
        builder    => '_build_passphrase_entry',
    );
}

has 'table_alignment' => (
    lazy_build => 1,
    is         => 'rw',
    isa        => 'Gtk3::Alignment',
);
has 'table' => (
    lazy_build => 1,
    is         => 'rw',
    isa        => 'Gtk3::Table',
);
has 'warning_area' => (
    lazy_build => 1,
    is         => 'rw',
    isa        => 'Gtk3::HBox',
);
has 'warning_image' => (
    lazy_build => 1,
    is         => 'rw',
    isa        => 'Gtk3::Image',
);
has 'size_of_free_space' => (
    required => 1,
    is       => 'ro',
    isa      => 'Int',
);
foreach (qw{mount_persistence_partition_cb create_configuration_cb}) {
    has $_ => (
        required => 1,
        is       => 'ro',
        isa      => 'CodeRef',
    );
}

has 'passphrase_check_button' => (
    lazy_build => 1,
    is         => 'rw',
    isa        => 'Gtk3::CheckButton',
);


=head1 CONSTRUCTORS

=cut

method BUILD (@args) {
    $self->title->set_text($self->encoding->decode(gettext(
        q{Persistence wizard - Persistent volume creation}
    )));
    $self->subtitle->set_text($self->encoding->decode(gettext(
        q{Choose a passphrase to protect the persistent volume}
    )));
    $self->description->set_markup($self->encoding->decode(sprintf(
        # TRANSLATORS: size, device vendor, device model
        gettext(q{A %s persistent volume will be created on the <b>%s %s</b> device. Data on this volume will be stored in an encrypted form protected by a passphrase.}),
        format_bytes($self->size_of_free_space, mode => "iec"),
        $self->drive_vendor,
        $self->drive_model,
    )));
    $self->go_button->set_label($self->encoding->decode(gettext(q{Create})));
}

method _build_main_widget () {
    my $box = Gtk3::VBox->new();
    $box->set_spacing(6);
    $box->pack_start($self->title, FALSE, FALSE, 0);
    $box->pack_start($self->intro, FALSE, FALSE, 0);
    $box->pack_start($self->subtitle, FALSE, FALSE, 0);
    $box->pack_start($self->description, FALSE, FALSE, 0);

    my $show_passphrase_box = Gtk3::Box->new('GTK_ORIENTATION_HORIZONTAL', 0);
    $show_passphrase_box->pack_end($self->passphrase_check_button, FALSE, FALSE, 0);
    $box->add($show_passphrase_box);
    my $passphrase_box = Gtk3::VBox->new(FALSE, 6);
    $passphrase_box->set_spacing(6);
    $passphrase_box->pack_start($self->table_alignment, FALSE, FALSE, 0);
    $passphrase_box->pack_start($self->warning_area, FALSE, FALSE, 0);

    $box->pack_start($passphrase_box,  FALSE, FALSE, 0);

    $self->verify_passphrase_entry->set_activates_default(TRUE);

    $box->pack_start($self->status_area, FALSE, FALSE, 0);

    my $button_alignment = Gtk3::Alignment->new(1.0, 0, 0.2, 1.0);
    $button_alignment->set_padding(0, 0, 10, 10);
    $button_alignment->add($self->go_button);
    $box->pack_start($button_alignment, FALSE, FALSE, 0);
    $self->passphrase_entry->grab_focus();

    return $box;
}

method _build_intro () {
    my $intro = Gtk3::Label->new('');
    $intro->set_alignment(0.0, 0.5);
    $intro->set_padding(10, 10);
    $intro->set_line_wrap(TRUE);
    $intro->set_line_wrap_mode('word');
    $intro->set_single_line_mode(FALSE);
    $intro->set_max_width_chars(72);
    $intro->set_markup($self->encoding->decode(gettext(
        q{<b>Beware!</b> Using persistence has consequences that must be well understood. Tails can't help you if you use it wrong! See the <i>Encrypted persistence</i> page of the Tails documentation to learn more.}
    )));

    return $intro;
}

method _build_warning_image () {
    Gtk3::Image->new_from_stock('gtk-dialog-info', 'menu');
}

method _build_warning_area () {
    my $ext_hbox = Gtk3::HBox->new(FALSE, 0);
    $ext_hbox->set_border_width(10);
    $ext_hbox->set_spacing(6);

    my $box = Gtk3::HBox->new(FALSE, 12);
    $box->set_spacing(6);
    $box->pack_start($self->warning_image, FALSE, FALSE, 0);
    $box->pack_start($self->warning_label, FALSE, FALSE, 0);

    $ext_hbox->pack_start($box, FALSE, FALSE, 0);
    $ext_hbox->pack_start(Gtk3::Label->new(' '), FALSE, FALSE, 0);

    return $ext_hbox;
}

method _build_label () {
    my $label = Gtk3::Label->new($self->encoding->decode(gettext(
        q{Passphrase:}
    )));
    $label->set_alignment(0.0, 0.5);
    return $label;
}

method _build_verify_label () {
    my $label = Gtk3::Label->new($self->encoding->decode(gettext(
        q{Verify Passphrase:}
    )));
    $label->set_alignment(0.0, 0.5);
    return $label;
}

method _build_warning_label () {
    my $label = Gtk3::Label->new('');
    $label->set_padding(10, 0);
    $label->set_markup(
          "<i>"
        . $self->encoding->decode(gettext(q{Passphrase can't be empty}))
        . "</i>"
    );
    return $label;
}

method _build_passphrase_entry () {
    my $entry = Gtk3::Entry->new;
    $entry->set_visibility(FALSE);
    $entry->signal_connect("changed" => sub { $self->passphrase_entry_changed });

    return $entry;
}

method _build_table_alignment () {
    my $table_alignment = Gtk3::Alignment->new(0.0, 0.0, 1.0, 1.0);
    $table_alignment->add($self->table);
    return $table_alignment;
}

method _build_table () {
    my $table = Gtk3::Table->new(1, 2, FALSE);
    $table->set_border_width(10);
    $table->set_col_spacings(12);
    $table->set_row_spacings(6);
    $table->attach($self->label, 0, 1, 0, 1, 'fill', [qw{expand fill}], 0, 0);
    $table->attach_defaults($self->passphrase_entry, 1, 2, 0,  1);
    $table->attach($self->verify_label, 0, 1, 1, 2, 'fill', [qw{expand fill}], 0, 0);
    $table->attach_defaults($self->verify_passphrase_entry, 1, 2, 1,  2);

    return $table;
}

method _build_passphrase_check_button () {
    my $check_button = Gtk3::CheckButton->new_with_label(
        $self->encoding->decode(gettext(q{Show Passphrase}))
    );
    $check_button->set_active(FALSE);
    $check_button->signal_connect(
        toggled => sub { $self->passphrase_check_button_toggled }
    );

    return $check_button;
}


=head1 METHODS

=cut

method update_passphrase_ui () {
    my $passphrase = $self->passphrase_entry->get_text;
    my $passphrase_verify = $self->verify_passphrase_entry->get_text;

    # TODO: check passphrase strength (#7002)

    if ($passphrase ne $passphrase_verify) {
        $self->warning_label->set_markup(
              "<i>"
            . $self->encoding->decode(gettext(q{Passphrases do not match}))
            . "</i>"
        );
        $self->warning_image->show;
        $self->go_button->set_sensitive(FALSE);
    }
    elsif (length($passphrase) == 0) {
        $self->warning_label->set_markup(
              "<i>"
            . $self->encoding->decode(gettext(q{Passphrase can't be empty}))
            . "</i>"
        );
        $self->warning_image->show;
        $self->go_button->set_sensitive(FALSE);
    }
    else {
        $self->warning_image->hide;
        $self->warning_label->set_text(' ');
        $self->go_button->set_sensitive(TRUE);
    }
}

method passphrase_entry_changed () {
    $self->update_passphrase_ui;
}

method passphrase_check_button_toggled () {
    my $show_passphrase_op = $self->passphrase_check_button->get_active;
    foreach my $entry ($self->passphrase_entry, $self->verify_passphrase_entry) {
        $entry->set_visibility($show_passphrase_op);
    }
}

method operation_finished (HashRef $replies) {
    my ($created_device, $error);

    say STDERR "Entering Bootstrap::operation_finished";

    if (exists($replies->{created_device}) && defined($replies->{created_device})) {
        $created_device = $replies->{created_device};
        # For some reason, we cannot get the exception when Try::Tiny is used,
        # so let's do it by hand.
        {
            local $@;
            eval { $replies->{format_reply}->get_result };
            $error = $@;
        }
    }
    else {
        $error = $replies->{create_partition_error};
    }

    if ($error) {
        $self->working(0);
        say STDERR "$error";
        $self->subtitle->set_text($self->encoding->decode(gettext(q{Failed})));
        $self->description->set_text($error);
    }
    else {
        say STDERR "created ${created_device}.";
        $self->working(0);

        $self->subtitle->set_text($self->encoding->decode(gettext(
            q{Mounting Tails persistence partition.}
        )));
        $self->description->set_text($self->encoding->decode(gettext(
            q{The Tails persistence partition will be mounted.}
        )));
        $self->working(1);
        systemx(qw{/sbin/udevadm settle});
        my $mountpoint = $self->mount_persistence_partition_cb->();
        $self->working(0);
        say STDERR "mounted persistence partition on $mountpoint";

        $self->subtitle->set_text($self->encoding->decode(gettext(
            q{Correcting permissions of the persistent volume.}
        )));
        $self->description->set_text($self->encoding->decode(gettext(
            q{The permissions of the persistent volume will be corrected.}
        )));
        $self->working(1);
        systemx(qw{sudo -n /usr/local/bin/tails-fix-persistent-volume-permissions});
        $self->working(0);
        say STDERR "fixed permissions.";

        $self->subtitle->set_text($self->encoding->decode(gettext(
            q{Creating default persistence configuration.}
        )));
        $self->description->set_text($self->encoding->decode(gettext(
            q{The default persistence configuration will be created.}
        )));
        $self->working(1);
        $self->create_configuration_cb->();
        $self->working(0);
        say STDERR "created default persistence configuration.";

        $self->success_callback->();
    }
}

method go_button_pressed () {
    $_->hide foreach ($self->intro, $self->warning_area, $self->table,$self->passphrase_check_button);
    $self->working(1);
    $self->subtitle->set_text(
        $self->encoding->decode(gettext(q{Creating...})),
    );
    $self->description->set_text(
        $self->encoding->decode(gettext(q{Creating the persistent volume...})),
    );

    $self->go_callback->(
        passphrase => $self->passphrase_entry->get_text,
        end_cb => sub { $self->operation_finished(@_) },
    );
}

with 'Tails::Persistence::Role::StatusArea';
with 'Tails::Persistence::Role::SetupStep';

no Moo;
1;
