=head1 NAME

Tails::Persistence::Role::StatusArea - role to manage a status area

=cut

package Tails::Persistence::Role::StatusArea;
use 5.10.1;
use strictures 2;
use autodie qw(:all);
use Function::Parameters;
use Glib qw{TRUE FALSE};
use Gtk3;

use Moo::Role;
use MooX::late;
use namespace::clean;


=head1 ATTRIBUTES

=cut

has 'status_area' => (
    lazy_build => 1,
    is         => 'rw',
    isa        => 'Gtk3::HBox',
);
has 'spinner'     => (
    lazy_build => 1,
    is         => 'rw',
    isa        => 'Gtk3::Spinner',
);
has 'working'     => (
    lazy_build => 1,
    is         => 'rw',
    isa        => 'Bool',

);


=head1 CONSTRUCTORS

=cut

method _build_status_area () {
    my $box = Gtk3::HBox->new(FALSE, 64);
    $box->set_border_width(10);
    $box->pack_start($self->spinner, FALSE, FALSE, 0);

    return $box;
}

method _build_spinner () {
    my $spinner = Gtk3::Spinner->new;
    $spinner->set_size_request(80,80);
    return $spinner;
}


=head1 METHOD MODIFIERS

=cut

after 'working' => sub {
    my $self    = shift;

    return unless @_;
    my $new_value = shift;

    if ($new_value) {
        $self->spinner->start;
        $self->spinner->show;
        $self->go_button->set_sensitive(FALSE);
    }
    else {
        $self->spinner->stop;
        $self->spinner->hide;
    }
};

no Moo::Role;
1;
