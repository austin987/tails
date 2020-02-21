=head1 NAME

Tails::Role::HasCodeset - role to get the codeset being used

=cut

package Tails::Role::HasCodeset;

use 5.10.1;
use strictures 2;
use autodie qw(:all);

use Function::Parameters;
use Try::Tiny;

use Moo::Role; # Moo::Role exports all methods declared after it's "use"'d
use MooX::late;

use namespace::clean;

has 'codeset'  => (
    isa        => 'Str',
    is         => 'ro',
    lazy_build => 1,
);

method _build_codeset () {
    my $codeset;
    try {
        require I18N::Langinfo;
        I18N::Langinfo->import(qw(langinfo CODESET));
        $codeset = langinfo(CODESET());
    } catch {
        die "No default character code set configured.\nPlease fix your locale settings.";
    };
    $codeset;
}

no Moo::Role;
1; # End of Tails::Role::HasCodeset
