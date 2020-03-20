package My::Builder;

use 5.10.1;
use strictures 2;

use base qw{Module::Build};

use autodie;
use Cwd;
use Function::Parameters;
use Path::Tiny;


=head1 Methods and method modifiers

=head2 run_in_po_dir

Run the command+args passed in @_, using Module::Build's do_system
method, in the directory that contains our gettext infrastructure and
.po / .pot files. Return what do_system has returned, i.e. true on
success, false on failure.

=cut
method run_in_po_dir (@command) {
    my $orig_dir = getcwd;
    chdir('po');
    my $res = $self->do_system(@command);
    chdir($orig_dir);

    return $res;
}

=head2 ACTION_build

Copy .mo files to blib/share/locale.

=cut
method ACTION_build (@args) {
    $self->SUPER::ACTION_build(@args);

    my $blibdir = path('.')->parent->child('blib');
    say "blibdir: $blibdir";
    $self->run_in_po_dir(qw{make install}, "DESTDIR=$blibdir");
};

1;
