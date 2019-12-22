=head1 NAME

Tails::MirrorPool - class that represents the Tails HTTP download mirror pool

=cut

package Tails::MirrorPool;

no Moo::sification;
use Moo;

use 5.10.1;
use strictures 2;
use autodie qw(:all);

use Carp;
use Carp::Assert;
use Carp::Assert::More;
use Function::Parameters;
use IPC::System::Simple qw{capturex};
use Tails::Download::HTTPS;
use Types::Standard qw{InstanceOf Str};

use namespace::clean;

=head1 ATTRIBUTES

=cut

has 'baseurl' => (
    required => 1,
    is       => 'ro',
    isa      => Str,
);

has 'fallback_prefix' => (
    is  => 'lazy',
    isa => Str,
);

has 'downloader' => (
    is  => 'lazy',
    isa => InstanceOf['Tails::Download::HTTPS'],
);

has 'filename' => (
    is  => 'lazy',
    isa => Str,
);


=head1 CONSTRUCTORS AND BUILDERS

=cut

method _build_fallback_prefix () {
    q{http://dl.amnesia.boum.org/tails'}
}

method _build_downloader () {
    Tails::Download::HTTPS->new();
}

method _build_filename () {
    q{mirrors.json}
}


=head1 METHODS

=cut

method transformURL (Str $url) {
    my $orig_url = $url;
    my $mirrors_json = $self->downloader->get_url(
        $self->baseurl . '/' . $self->filename
    );
    $ENV{NODE_PATH} //= '/usr/local/lib/nodejs';
    $url = capturex(
        'tails-transform-mirror-url', $url, $self->fallback_prefix,
        $mirrors_json
    );
    say STDERR "Transformed '$orig_url' into '$url'" if $ENV{DEBUG};
    return $url;
}

no Moo;
1;
