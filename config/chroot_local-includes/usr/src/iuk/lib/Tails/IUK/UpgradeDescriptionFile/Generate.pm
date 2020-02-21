=head1 NAME

Tails::IUK::UpgradeDescriptionFile::Generate - create and update upgrade-description files

=cut

package Tails::IUK::UpgradeDescriptionFile::Generate;

no Moo::sification;
use Moo;

use 5.10.1;
use strictures 2;

use autodie qw(:all);
use Carp;
use Carp::Assert;
use Carp::Assert::More;
use Digest::SHA;
use English qw{-no_match_vars};
use Function::Parameters;
use Path::Tiny;
use Tails::IUK::UpgradeDescriptionFile;
use Types::Path::Tiny qw{AbsDir AbsFile};
use Types::Standard qw{ArrayRef Bool Str};

use namespace::clean;

use MooX::Options;


=head1 ATTRIBUTES

=cut

option "$_" => (
    required => 1,
    is       => 'ro',
    isa      => ArrayRef,
    format   => 's@',
) for (qw{previous_versions next_versions});

option version => (
    required => 1,
    is       => 'ro',
    isa      => Str,
    format   => 's',
);

option major_release => (
    required => 1,
    is       => 'ro',
    isa      => Bool,
);

option iso => (
    required => 1,
    is       => 'ro',
    isa      => AbsFile,
    coerce   => AbsFile->coercion,
    format   => 's',
);

option "$_" => (
    required => 1,
    is       => 'ro',
    isa      => AbsDir,
    coerce   => AbsDir->coercion,
    format   => 's',
) for (qw{iuks release_checkout});

option "$_" => (
    is     => 'lazy',
    isa    => Str,
    format => 's',
) for (qw{build_target channel product_name});


=head1 CONSTRUCTORS AND BUILDERS

=cut

method _build_build_target () { 'amd64'   }
method _build_channel      () { 'stable' }
method _build_product_name () { 'Tails'  }

method BUILD (@args) {
    assert(-f $self->iso);
    assert(-d $self->release_checkout);
}


=head1 METHODS

=cut

method run () {
    for my $channel (qw{alpha stable}) {
        say STDERR q{* Creating upgrade-description files for new release },
            '(', $self->version, "), ", $channel, " channel: \n  ",
            $self->udf_for_new_release($channel), ' ...';
        $self->create_udf_for_new_release($channel);
        say STDERR '';
    }

    for my $channel (qw{alpha stable}) {
        for my $next_version (@{$self->next_versions}) {
            say STDERR q{* Creating upgrade-description files for next release },
                '(', $next_version, "), ", $channel, " channel: \n  ",
                 $self->udf_for($next_version, channel => $channel), ' ...';
            $self->create_udf_for_next_release($next_version, $channel);
            say STDERR '';
        }
    }

    for my $previous_version (@{$self->previous_versions}) {
        say STDERR q{* Updating upgrade-description file for previous },
            'release (', $previous_version, "): \n  ",
            $self->udf_for($previous_version), ' ...';
        $self->update_udf_for_previous_release($previous_version);
        say STDERR '';
    }
}

method create_udf_for_new_release ($channel) {
    my $description = Tails::IUK::UpgradeDescriptionFile->new(
        product_name            => $self->product_name,
        initial_install_version => $self->version,
        build_target            => $self->build_target,
        channel                 => $channel,
    );
    $self->udf_for_new_release($channel)->parent->mkpath;
    $self->udf_for_new_release($channel)->spew(
        $description->stringify
    );
}

method create_udf_for_next_release ($version, $channel) {
    my $udf = $self->udf_for($version, channel => $channel);

    my $description = Tails::IUK::UpgradeDescriptionFile->new(
        product_name            => $self->product_name,
        initial_install_version => $version,
        build_target            => $self->build_target,
        channel                 => $channel,
    );
    $udf->parent->mkpath;
    $udf->spew($description->stringify);
}

method update_udf_for_previous_release ($previous_version) {
    my $udf         = $self->udf_for($previous_version);

    my $description;
    if (-e $udf) {
        $description = Tails::IUK::UpgradeDescriptionFile->new_from_file(filename => $udf->canonpath);
    }
    else {
        $description = Tails::IUK::UpgradeDescriptionFile->new(
            product_name            => $self->product_name,
            initial_install_version => $previous_version,
            build_target            => $self->build_target,
            channel                 => $self->channel,
        );
        $udf->parent->mkpath;
    }

    # We don't want older upgrades to be advertised forever, once we provide
    # an upgrade path to the last one.
    $description->empty_upgrades;

    $description->add_upgrade({
        version         => $self->version,
        'details-url'   => $self->details_url,
        type            => $self->major_release ? 'major' : 'minor',
        'upgrade-paths' => [$self->upgrade_paths_from_previous_release($previous_version)],
    });
    $udf->spew($description->stringify);
}

method upgrade_paths_from_previous_release ($previous_version) {
    my @paths;

    say STDERR q{  Adding full upgrade...};
    push @paths, {
        type           => 'full',
        'target-files' => [{
            sha256 => sha256_file($self->iso),
            size   => -s $self->iso,
            url    => $self->iso_url,
        }],
    };

    if ($self->has_iuk_for($previous_version)) {
        say STDERR q{  Adding incremental upgrade...};
        my $iuk = $self->iuk_for($previous_version);
        push @paths, {
            type           => 'incremental',
            'target-files' => [{
                sha256 => sha256_file($iuk),
                size   => -s $iuk,
                url    => $self->iuk_url($previous_version),
            }],
        };
    }
    else {
        say STDERR q{  No IUK could be found for }, $previous_version,
            q{, we will only advertise full upgrade.};
    }

    return @paths;
}

method udf_for ($version, :$channel = $self->channel) {
    path(
        $self->release_checkout, qw{wiki src upgrade v2}, $self->product_name,
        $version, $self->build_target, $channel, 'upgrades.yml'
    );
}

method udf_for_new_release ($channel) {
    $self->udf_for($self->version, channel => $channel)
}

method iso_url () {
    'http://dl.amnesia.boum.org/tails/'
        . $self->channel
        . '/'
        . lc($self->product_name)
        . '-'
        . $self->build_target
        . '-'
        . $self->version
        . '/'
        . lc($self->product_name)
        . '-'
        . $self->build_target
        . '-'
        . $self->version
        . '.iso';
}

method iuk_filename ($previous_version) {
    $self->product_name
        . '_'
        . $self->build_target
        . '_'
        . $previous_version
        . '_to_'
        . $self->version
        . '.iuk';
}

method iuk_url ($previous_version) {
    'http://dl.amnesia.boum.org/tails/'
        . $self->channel
        . '/iuk/v2/'
        . $self->iuk_filename($previous_version);
}

method iuk_for ($previous_version) {
    path($self->iuks, $self->iuk_filename($previous_version));
}

method has_iuk_for ($previous_version) {
    -f $self->iuk_for($previous_version);
}

method details_url () {
    my $version = version_for_website($self->version);
    if ($self->channel eq 'stable') {
        return 'https://tails.boum.org/news/version_'.$version.'/';
    }
    elsif ($self->channel eq 'alpha') {
        return 'https://tails.boum.org/news/test_'.$version.'/';
    }
    else {
        croak('Channel '.$self->channel.' is not supported.');
    }
}



=head1 FUNCTIONS

=cut

fun sha256_file ($file) {
    assert(-f $file);

    my $sha = Digest::SHA->new(256);
    $sha->addfile($file->stringify);
    return $sha->hexdigest;
}

fun version_for_website ($version) {
    assert_defined($version);
    assert(length($version));

    $version =~ s{~}{-}xms;

    return $version;
}

no Moo;
1;
