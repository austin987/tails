=head1 NAME

Tails::Persistence::Configuration::Setting - a persistence feature displayed in the GUI

=cut

package Tails::Persistence::Configuration::Setting;

use 5.10.1;
use strictures 2;
use autodie qw(:all);
use Function::Parameters;
use Glib qw{TRUE FALSE};
use List::MoreUtils qw{all};
use Pango;
use UUID::Tiny ':std';

use Glib::Object::Introspection;
Glib::Object::Introspection->setup(
    basename => 'Gio',
    version  => '2.0',
    package  => 'Gio'
);

use Locale::gettext;
use POSIX;
setlocale(LC_MESSAGES, "");
textdomain("tails");

use Moo;
use MooX::late;
with 'Tails::Role::HasEncoding';
use namespace::clean;


=head1 ATTRIBUTES

=cut

has 'atoms' => (
    required    => 1,
    is          => 'ro',
    isa         => 'ArrayRef[Tails::Persistence::Configuration::Atom]',
);

foreach (qw{id name description icon_name}) {
    has $_ => (
        lazy_build => 1,
        is         => 'rw',
        isa        => 'Str',
    );
}

has 'icon' => (
    lazy_build => 1,
    is         => 'ro',
    isa        => 'Gtk3::Image',
);

has 'main_widget' => (
    lazy_build     => 1,
    is             => 'ro',
    isa            => 'Gtk3::HBox',
);

has 'switch' => (
    lazy_build     => 1,
    is             => 'ro',
    isa            => 'Gtk3::Switch',
    handles        => {
        is_active  => 'get_active',
        set_active => 'set_active',
    },
);

has 'icon_theme' => (
    is      => 'ro',
    isa     => 'Gtk3::IconTheme',
    builder => '_build_icon_theme',
);

has 'title_label' => (
    lazy_build => 1,
    is         => 'ro',
    isa        => 'Gtk3::Label',
);

has 'description_label' => (
    lazy_build => 1,
    is         => 'ro',
    isa        => 'Gtk3::Label',
);

has 'configuration_button' => (
    lazy_build => 1,
    is         => 'ro',
    isa        => 'Gtk3::Button',
);

has 'configuration_app_desktop_id' => (
    lazy_build => 1,
    is         => 'ro',
    isa        => 'Str',
    predicate  => 1,
);


=head1 CONSTRUCTORS

=cut

method _build_name () {
    $self->encoding->decode(gettext('Custom'));
}

method _build_id () {
    create_uuid();
}

method _build_description () {
    join(', ', map { $self->encoding->decode($_->destination) } @{$self->atoms});
}

method _build_icon_name () {
    'dialog-question'
}

method _build_icon () {
    Gtk3::Image->new_from_pixbuf($self->icon_theme->load_icon(
        $self->icon_name, 48, 'use-builtin'
    ));
}

method _build_switch () {
    my $switch = Gtk3::Switch->new();
    $switch->set_active($self->enabled);
    $switch->set_valign('GTK_ALIGN_CENTER');
    $switch->set_vexpand(FALSE);
    for (qw{start end top bottom}) {
        my $method = "set_margin_${_}";
        $switch->$method(12);
    }
    $switch->signal_connect('notify::active' => sub { $self->toggled_cb });
    return $switch;
}

method _build_configuration_button () {
    my $button = Gtk3::Button->new_from_icon_name(
        'emblem-system-symbolic', 1,
    );
    $button->set_valign('GTK_ALIGN_CENTER');
    $button->signal_connect('clicked' => sub { $self->configuration_cb() });

    return $button;
}

method _build_main_widget () {
    my $main_box = Gtk3::HBox->new();
    $main_box->set_border_width(5);

    my $text_box = Gtk3::VBox->new();
    $text_box->set_border_width(5);
    $text_box->pack_start($self->title_label, FALSE, FALSE, 0);
    $text_box->pack_start($self->description_label, FALSE, FALSE, 0);
    $text_box->set_margin_start(12);
    $text_box->set_margin_end(12);
    $text_box->set_margin_top(6);
    $text_box->set_margin_bottom(6);

    $main_box->pack_start($self->icon, FALSE, FALSE, 0);
    $main_box->pack_start($text_box, TRUE, TRUE, 0);
    if ($self->has_configuration_app_desktop_id) {
        $main_box->pack_start($self->configuration_button, FALSE, FALSE, 0);
    }
    $main_box->pack_start($self->switch, FALSE, FALSE, 0);

    return $main_box;
}

method _build_icon_theme () {
    my $theme = Gtk3::IconTheme::get_default();

    $theme->append_search_path('/usr/share/pixmaps/cryptui/48x48');
    $theme->append_search_path('/usr/share/pixmaps/seahorse/48x48');
    $theme->append_search_path('/usr/share/icons/gnome-colors-common/32x32/apps/');
    $theme->append_search_path('/usr/share/app-install/icons/');

    return $theme;
 }

method _build_title_label () {
    my $title = Gtk3::Label->new($self->name);
    $title->set_alignment(0.0, 0.5);
    my $title_attrlist = Pango::AttrList->new;
    $title_attrlist->insert($_)
        foreach ( Pango::AttrScale->new(1.1),Pango::AttrWeight->new('bold') );
    $title->set_attributes($title_attrlist);

    return $title;
}

method _build_description_label () {
    my $description = Gtk3::Label->new($self->description);
    $description->set_alignment(0.0, 0.5);
    my $description_attrlist = Pango::AttrList->new;
    $description_attrlist->insert(
        Pango::AttrForeground->new(30000, 30000, 30000)
      );
    $description->set_attributes($description_attrlist);
    $description->set_line_wrap(TRUE);
    $description->set_line_wrap_mode('word');
    $description->set_single_line_mode(FALSE);

    return $description;
}


=head1 METHODS

=cut

method enabled () {
    all { $_->enabled } @{$self->atoms};
}

method toggled_cb () {
    foreach my $atom (@{$self->atoms}) {
        $atom->enabled($self->is_active)
    }
}

method configuration_cb () {
    my $configuration_desktop_app_info = Gio::DesktopAppInfo->new(
        $ENV{DEV_MODE}
            ? 'yelp.desktop'
            : $self->configuration_app_desktop_id,
    );
    $configuration_desktop_app_info->launch();
}

no Moo;
1;
