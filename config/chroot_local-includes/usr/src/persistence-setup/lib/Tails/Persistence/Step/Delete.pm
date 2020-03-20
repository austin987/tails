=head1 NAME

Tails::Persistence::Step::Delete - delete persistent storage

=cut

package Tails::Persistence::Step::Delete;

use 5.10.1;
use strictures 2;

use Function::Parameters;
use Glib qw{TRUE FALSE};
use Number::Format qw(:subs);

use Locale::gettext;
use POSIX;
setlocale(LC_MESSAGES, "");
textdomain("tails");

use Moo;
use MooX::late;
use namespace::clean;


=head1 ATTRIBUTES

=cut

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
has 'warning_icon' => (
    lazy_build => 1,
    is         => 'rw',
    isa        => 'Gtk3::Image',
);


=head1 CONSTRUCTORS

=cut

method BUILD (@args) {
    $self->title->set_text($self->encoding->decode(gettext(
        q{Persistence wizard - Persistent volume deletion}
    )));
    $self->subtitle->set_text($self->encoding->decode(gettext(
        q{Your persistent data will be deleted.}
    )));
    # TRANSLATORS: partition, size, device vendor, device model
    $self->description->set_markup($self->encoding->decode(sprintf(
        gettext(q{The persistent volume %s (%s), on the <b>%s %s</b> device, will be deleted.}),
        $self->persistence_partition_device_file,
        format_bytes($self->persistence_partition_size, mode => "iec"),
        $self->drive_vendor,
        $self->drive_model
    )));
    $self->go_button->set_label($self->encoding->decode(gettext(q{Delete})));
    $self->go_button->set_sensitive(TRUE);
}

method _build_warning_icon () {
    Gtk3::Image->new_from_stock("gtk-dialog-warning", "GTK_ICON_SIZE_DIALOG");
}

method _build_main_widget () {
    my $box = Gtk3::VBox->new();
    my $hbox = Gtk3::HBox->new();
    $box->set_spacing(6);

    $box->pack_start($self->title, FALSE, FALSE, 0);
    $hbox->pack_start($self->warning_icon, FALSE, FALSE, 10);
    $hbox->pack_start($self->subtitle, FALSE, FALSE, 0);
    $box->pack_start($hbox, FALSE, FALSE, 0);
    $box->pack_start($self->description, FALSE, FALSE, 0);

    $box->pack_start($self->status_area, FALSE, FALSE, 0);

    my $button_alignment = Gtk3::Alignment->new(1.0, 0, 0.2, 1.0);
    $button_alignment->set_padding(0, 0, 10, 10);
    $button_alignment->add($self->go_button);
    $box->pack_start($button_alignment, FALSE, FALSE, 0);

    return $box;
}

method operation_finished ($reply) {
    my $error;

    { local $@; eval { $reply->get_result }; $error = $@; }

    if ($error) {
        $self->working(0);
        say STDERR "$error";
        $self->subtitle->set_text($self->encoding->decode(gettext(q{Failed})));
        $self->description->set_text($error);
    }
    else {
        say STDERR "done.";
        $self->working(0);
        $self->warning_icon->hide();
        $self->success_callback->();
    }
}

method go_button_pressed () {
    $self->working(1);
    $self->subtitle->set_text(
        $self->encoding->decode(gettext(q{Deleting...})),
    );
    $self->description->set_text(
        $self->encoding->decode(gettext(q{Deleting the persistent volume...})),
    );

    $self->go_callback->(
        end_cb => sub { $self->operation_finished(@_) },
    );
}

with 'Tails::Persistence::Role::StatusArea';
with 'Tails::Persistence::Role::SetupStep';

no Moo;
1;
