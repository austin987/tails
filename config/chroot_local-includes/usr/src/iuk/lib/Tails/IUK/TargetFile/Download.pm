=head1 NAME

Tails::IUK::TargetFile::Download - download and verify a target file

=cut

package Tails::IUK::TargetFile::Download;

no Moo::sification;
use Moo;

use 5.10.1;
use strictures 2;

use autodie qw(:all);
use Carp;
use Carp::Assert;
use Cwd;
use Digest::SHA;
use File::Temp qw{tempfile};
use Function::Parameters;
use HTTP::Request;
use Path::Tiny;
use String::Errf qw{errf};
use Tails::IUK::LWP::UserAgent::WithProgress;
use Tails::IUK::Utils qw{space_available_in};
use Types::Path::Tiny qw{AbsPath};
use Types::Standard qw{Enum Int Str};

use namespace::clean;

use MooX::Options;


=head1 ATTRIBUTES

=cut

option "$_" => (
    required => 1,
    is       => 'ro',
    isa      => Str,
    format   => 's',
) for (qw{uri hash_value});

option 'hash_type' => (
    required => 1,
    is       => 'ro',
    isa      => Enum[qw{sha256}],
    format   => 's',
);

option 'output_file' => (
    required => 1,
    is       => 'ro',
    isa      => AbsPath,
    coerce   => AbsPath->coercion,
    format   => 's',
);

option 'size' => (
    required => 1,
    is       => 'ro',
    isa      => Int,
    format   => 's',
);


=head1 METHODS

=cut

method fatal (@msg) {
    Tails::IUK::Utils::fatal(msg => \@msg);
}

method check_available_space () {
    my $target_dir      = $self->output_file->parent;
    my $space_needed    = $self->size;
    my $space_available = space_available_in($target_dir);
    $space_available >= $space_needed or $self->fatal(errf(
        "Downloading this incremental upgrade requires %{space_needed}s ".
        "of free space in %{target_dir}s, but only %{space_available}s is available.",
        {
            space_needed    => $space_needed,
            target_dir      => $target_dir,
            space_available => $space_available,
        }
    ));
}

method run () {
    $self->check_available_space;

    my $ua = Tails::IUK::LWP::UserAgent::WithProgress->new(ssl_opts => {
        verify_hostname => 0,
        SSL_verify_mode => 0,
    });
    unless ($ENV{HARNESS_ACTIVE} or $ENV{DISABLE_PROXY}) {
        $ua->proxy([qw(http https)] => 'socks://127.0.0.1:9062');
    }
    $ua->protocols_allowed([qw(http https)]);
    my $req = HTTP::Request->new('GET', $self->uri);

    my ($temp_fh, $temp_filename) = tempfile;
    close $temp_fh;

    sub clean_fatal {
        my $self   = shift;
        my $unlink = shift;
        unlink $unlink;
        $self->fatal(@_);
    }

    $ua->max_size($self->size);
    my $res = $ua->request($req, $temp_filename);

    defined $res or clean_fatal($self, $temp_filename, sprintf(
        "Could not download '%s' to '%s': undefined result",
        $self->uri, $temp_filename,
    ));

    for my $lwp_failure_header (qw{Client-Aborted X-Died}) {
        my $header = $res->header($lwp_failure_header);
        ! defined $header or clean_fatal($self, $temp_filename, sprintf(
            "Could not download '%s' to '%s' (%s): %s",
            $self->uri, $temp_filename, $lwp_failure_header, $header,
        ));
    }

    $res->is_success or clean_fatal($self, $temp_filename, sprintf(
        "Could not download '%s' to '%s', request failed:\n%s\n",
        $self->uri, $temp_filename, $res->status_line,
    ));

    -s $temp_filename == $self->size or clean_fatal(
        $self, $temp_filename, sprintf(
            "The file '%s' was downloaded but its size (%d) should be %d",
            $self->uri, -s $temp_filename, $self->size,
    ));

    my $sha = Digest::SHA->new(256);
    $sha->addfile($temp_filename);
    my $actual_hash = $sha->hexdigest;
    $actual_hash eq $self->hash_value or clean_fatal(
        $self, $temp_filename, sprintf(
            "The file '%s' was downloaded but its hash is not correct:\n"
                . "  - expected: %s\n"
                . "  - actual:   %s",
            $self->uri,
            $self->hash_value,
            $actual_hash,
    ));

    rename($temp_filename, $self->output_file);
    # autodie is supposed to throw an exception on rename error,
    # but one can't be too careful.
    assert(-e $self->output_file);

    chmod 0644, $self->output_file;

    return 1;
}

no Moo;
1;
