=head1 NAME

Tails::Persistence::Role::SetupStep - role for persistence setup steps

=cut

package Tails::Persistence::Role::SetupStep;

use 5.10.1;
use strictures 2;
use autodie qw(:all);

use Function::Parameters;
use Glib qw{TRUE FALSE};
use Gtk3 qw{-init};

use Locale::gettext;
use POSIX;
setlocale(LC_MESSAGES, "");
textdomain("tails");

use Moo::Role;
use MooX::late;
use namespace::clean;

with 'Tails::Role::HasEncoding';
with 'Tails::Persistence::Role::HasStatusArea';

requires '_build_main_widget';
requires 'go_button_pressed';


=head1 ATTRIBUTES

=cut

has 'name' => (
    required => 1,
    is       => 'ro',
    isa      => 'Str',
);

has 'main_widget' => (
    lazy_build => 1,
    is         => 'rw',
    isa        => 'Gtk3::VBox',
);

foreach (qw{title subtitle description}) {
    has $_ => (
        lazy_build => 1,
        is         => 'rw',
        isa        => 'Gtk3::Label',
    );
}

has 'go_button'   => (
    lazy_build => 1,
    is         => 'rw',
    isa        => 'Gtk3::Button',
);
foreach (qw{go_callback success_callback}) {
    has $_ => (
        required => 1,
        is       => 'ro',
        isa      => 'CodeRef',
    );
}

foreach (qw{drive_vendor drive_model}) {
    has $_ => (
        required => 1,
        is       => 'ro',
        isa      => 'Str',
    );
}


=head1 CONSTRUCTORS

=cut

method _build_title () {
    my $label = Gtk3::Label->new('');
    $label->set_alignment(0.0, 0.5);
    my $attrlist  = Pango::AttrList->new;
    $attrlist->insert($_)
        foreach ( Pango::AttrScale->new(1.3),Pango::AttrWeight->new('bold') );
    $label->set_attributes($attrlist);
    $label->set_padding(10, 10);

    return $label;
}

method _build_subtitle () {
    my $label = Gtk3::Label->new('');
    $label->set_alignment(0.0, 0.5);
    my $attrlist  = Pango::AttrList->new;
    $attrlist->insert($_)
        foreach ( Pango::AttrScale->new(1.1),Pango::AttrWeight->new('bold') );
    $label->set_attributes($attrlist);
    $label->set_padding(10, 10);
    $label->set_line_wrap(TRUE);
    $label->set_line_wrap_mode('word');
    $label->set_single_line_mode(FALSE);

    return $label;
}

method _build_description () {
    my $label = Gtk3::Label->new('');
    $label->set_alignment(0.0, 0.5);
    $label->set_padding(10, 10);
    $label->set_line_wrap(TRUE);
    $label->set_line_wrap_mode('word');
    $label->set_single_line_mode(FALSE);

    return $label;
}

method _build_go_button () {
    my $button = Gtk3::Button->new;
    $button->set_sensitive(FALSE);
    $button->set_can_default(TRUE);
    $button->signal_connect('clicked', sub { $self->go_button_pressed });

    return $button;
}

no Moo::Role;
1;
