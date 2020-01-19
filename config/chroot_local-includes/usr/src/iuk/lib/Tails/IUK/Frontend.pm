=head1 NAME

Tails::IUK::Frontend - lead Tails user through the process of upgrading the system, if needed

=cut

package Tails::IUK::Frontend;

use 5.10.1;
use strictures 2;

use autodie qw(:all);
use Carp;
use Carp::Assert;
use Carp::Assert::More;
use English qw{-no_match_vars};
use Env;
use Function::Parameters;
use IPC::Run;
use Number::Format qw(:subs);
use Path::Tiny;
use String::Errf qw{errf};
use Tails::Download::HTTPS;
use Tails::RunningSystem;
use Tails::IUK::UpgradeDescriptionFile;
use Tails::IUK::Utils qw{space_available_in};
use Tails::MirrorPool;
use Try::Tiny;
use Types::Path::Tiny qw{AbsDir AbsFile};
use Types::Standard qw(ArrayRef Bool CodeRef Defined HashRef InstanceOf Int Maybe Str);

use Locale::gettext;
use POSIX;
setlocale(LC_MESSAGES, "");
textdomain("tails");

no Moo::sification;
use Moo;
use MooX::HandlesVia;

with 'Tails::Role::HasEncoding';

use namespace::clean;

use MooX::Options;


=head1 ATTRIBUTES

=cut

option "override_$_" => (
    is        => 'lazy',
    isa       => Str,
    format    => 's',
    predicate => 1,
) for (qw{baseurl build_target trusted_gnupg_homedir});

option override_initial_install_os_release_file =>
    is        => 'lazy',
    isa       => AbsFile,
    coerce    => AbsFile->coercion,
    format    => 's',
    predicate => 1;

option override_os_release_file =>
    is        => 'lazy',
    isa       => AbsFile,
    coerce    => AbsFile->coercion,
    format    => 's',
    predicate => 1;

option "override_$_" => (
    isa        => AbsDir,
    is         => 'ro',
    lazy_build => 1,
    coerce     => AbsDir->coercion,
    format     => 's',
    predicate  => 1,
) for (qw{dev_dir liveos_mountpoint proc_dir run_dir});

option batch =>
    is  => 'lazy',
    isa => Bool;

option 'override_started_from_device_installed_with_tails_installer' =>
    is            => 'lazy',
    isa           => Str,
    format        => 's',
    predicate     => 1,
    documentation => q{Internal, for test suite only};

has 'running_system' =>
    is      => 'lazy',
    isa     => InstanceOf['Tails::RunningSystem'],
    handles => [
        qw{upgrade_description_file_url upgrade_description_sig_url},
        qw{product_name initial_install_version build_target channel}
    ];

has 'free_space' =>
    is            => 'lazy',
    isa           => Int,
    documentation => q{Free space (in bytes) on the system partition};

option 'override_free_space' =>
    is            => 'lazy',
    isa           => Int,
    format        => 'i',
    predicate     => 1,
    documentation => q{Internal, for test suite only};


=head1 CONSTRUCTORS AND BUILDERS

=cut

method _build_batch () { 0; }

method _build_running_system () {
    my @args;
    for (qw{baseurl build_target dev_dir liveos_mountpoint},
         qw{os_release_file initial_install_os_release_file},
         qw{proc_dir run_dir}) {
        my $attribute = "override_$_";
        my $predicate = "has_$attribute";
        if ($self->$predicate) {
            push @args, ($_ => $self->$attribute)
        }
    }
    if ($self->has_override_started_from_device_installed_with_tails_installer) {
        push @args, (
            override_started_from_device_installed_with_tails_installer
                => $self->override_started_from_device_installed_with_tails_installer
        );
    }
    Tails::RunningSystem->new(@args);
}

method _build_free_space () {
    $self->has_override_free_space
        ? $self->override_free_space
        : space_available_in($self->running_system->liveos_mountpoint);
}


=head1 METHODS

=cut

method fatal (Str $msg, Str :$title, Str :$debugging_info) {
    say STDERR $self->encoding->encode("$title\n$msg\n$debugging_info");
    $self->dialog($msg, type => 'error', title => $title) unless $self->batch;
    croak($self->encoding->encode("$title\n$msg\n$debugging_info"));
}

method info (Str $msg) {
    say $self->encoding->encode($msg);
}

method fatal_run_cmd (Str :$error_msg, ArrayRef :$cmd, Maybe[Str] :$as = undef, Str :$error_title) {
    my @cmd       = @{$cmd};

    if (defined $as && ! $ENV{HARNESS_ACTIVE}) {
        @cmd = ('sudo', '-n', '-u', $as, @cmd);
    }

    my ($stdout, $stderr);
    my $success = 1;
    my $exit_code;
    IPC::Run::run \@cmd, '>', \$stdout, '2>', \$stderr or $success = 0;
    $exit_code = $?;
    $success or $self->fatal(
        errf("<b>%{error_msg}s</b>\n\n%{details}s",
             {
                 error_msg => $error_msg, # was already decoded
                 details   => $self->encoding->decode(gettext(
                     q{For debugging information, execute the following command: sudo tails-debugging-info}
                 )),
             },
         ),
        title          => $error_title,
        debugging_info => $self->encoding->decode(errf(
            "exit code: %{exit_code}i\n\n".
            "stdout:\n%{stdout}s\n\n".
            "stderr:\n%{stderr}s",
            { exit_code => $exit_code, stdout => $stdout, stderr => $stderr }
        )),
    );

    return ($stdout, $stderr, $success, $exit_code);
}

method dialog (Str $question, Str :$type = 'question', Str :$title,
               Maybe[Str] :$ok_label = undef, Maybe[Str] :$cancel_label = undef) {
    if ($type ne 'question' && $type ne 'info') {
        assert_undefined($ok_label);
    }
    if ($type ne 'question') {
        assert_undefined($cancel_label);
    }
    my @cmd  = ('zenity', "--$type", '--ellipsize', '--text', $question);
    my $info = $question;
    if (defined $title) {
        $info = "$title\n$info";
        push @cmd, ('--title', $title);
    }
    if (defined $ok_label) {
        $info = "$info: $ok_label";
        push @cmd, ('--ok-label', $ok_label);
    }
    if (defined $cancel_label) {
        $info = "$info / $cancel_label";
        push @cmd, ('--cancel-label', $cancel_label);
    }
    $self->info($info);
    return 1 if $self->batch;
    system(@cmd);
    ${^CHILD_ERROR_NATIVE} == 0;
}

method upgrader_run_dir () {
    $self->running_system->run_dir->child('tails-upgrader');
}

method checked_upgrades_file () {
    $self->upgrader_run_dir->child('checked_upgrades');
}

method refresh_signing_key () {
    my $new_key_content = Tails::Download::HTTPS->new(
        max_download_size => 128 * 2**10,
    )->get_url(
        $self->running_system->baseurl . '/tails-signing-minimal.key'
    );
    my ($stdout, $stderr, $exit_code);
    my $success = 1;
    IPC::Run::run ['gpg', '--import'],
          '<', \$new_key_content, '>', \$stdout, '2>', \$stderr
          or $success = 0;
    $exit_code = $?;
    $success or $self->fatal(
        $self->encoding->decode(gettext(
            q{<b>An error occured while updating the signing key.</b>\n\n}.
            q{<b>This prevents determining whether an upgrade is available from our website.</b>\n\n}.
            q{Check your network connection, and restart Tails to try upgrading again.\n\n}.
            q{If the problem persists, go to file:///usr/share/doc/tails/website/doc/upgrade/error/check.en.html},
        )),
        title => $self->encoding->decode(gettext(
            q{Error while updating the signing key}
        )),
        debugging_info => $self->encoding->decode(errf(
            "exit code: %{exit_code}i\n\n".
            "stdout:\n%{stdout}s\n\n".
            "stderr:\n%{stderr}s",
            { exit_code => $exit_code, stdout => $stdout, stderr => $stderr }
        )),
    );
}

method get_upgrade_description () {
    my @args;
    for (qw{baseurl build_target os_release_file initial_install_os_release_file}) {
        my $attribute = "override_$_";
        my $predicate = "has_$attribute";
        if ($self->$predicate) {
            my $arg = "--$attribute";
            push @args, ($arg, $self->$attribute);
        }
    }
    if ($self->has_override_trusted_gnupg_homedir) {
        push @args, (
            '--trusted_gnupg_homedir', $self->override_trusted_gnupg_homedir
        );
    }
    my ($stdout, $stderr, $success, $exit_code) = $self->fatal_run_cmd(
        cmd         => [ 'tails-iuk-get-upgrade-description-file', @args ],
        error_title => $self->encoding->decode(gettext(
            q{Error while checking for upgrades}
        )),
        error_msg   => $self->encoding->decode(gettext(
            "<b>Could not determine whether an upgrade is available from our website.</b>\n\n".
            "Check your network connection, and restart Tails to try upgrading again.\n\n".
            "If the problem persists, go to file:///usr/share/doc/tails/website/doc/upgrade/error/check.en.html",
    )));

    return ($stdout, $stderr, $success, $exit_code);
}

method no_incremental_explanation (Str $no_incremental_reason) {
    assert_defined($no_incremental_reason);

    my $explanation;

    if ($no_incremental_reason eq 'no-incremental-upgrade-path') {
        $explanation = gettext(
            q{no automatic upgrade is available from our website }.
            q{for this version}
        );
    }
    elsif ($no_incremental_reason eq 'not-installed-with-tails-installer') {
        $explanation = gettext(
            q{your device was not created using a USB image or Tails Installer}
        );
    }
    elsif ($no_incremental_reason eq 'non-writable-device') {
        $explanation = gettext(
            q{Tails was started from a DVD or a read-only device}
        );
    }
    elsif ($no_incremental_reason eq 'not-enough-free-space') {
        $explanation = gettext(
            q{there is not enough free space on the Tails system partition}
        );
    }
    elsif ($no_incremental_reason eq 'not-enough-free-memory') {
        $explanation = gettext(
            q{not enough memory is available on this system}
        );
    }
    else {
        $self->debug(errf(
            $self->encoding->decode(gettext(
                q{No explanation available for reason '%{reason}s'.}
            )),
            { reason => $no_incremental_reason }
        ));
        $explanation = $no_incremental_reason;
    }

    return "$explanation";
}

method run () {
    $self->refresh_signing_key;
    my ($upgrade_description_text) = $self->get_upgrade_description;
    my $upgrade_description = Tails::IUK::UpgradeDescriptionFile->new_from_text(
        text            => $upgrade_description_text,
        product_version => $self->running_system->product_version,
    );
    assert_isa($upgrade_description, 'Tails::IUK::UpgradeDescriptionFile');

    $self->checked_upgrades_file->touch;

    unless ($upgrade_description->contains_upgrade_path) {
        $self->info($self->encoding->decode(gettext("The system is up-to-date")));
        exit(0);
    }

    $self->info($self->encoding->decode(gettext(
        'This version of Tails is outdated, and may have security issues.'
    )));
    my ($upgrade_path, $upgrade_type, $no_incremental_reason);

    if ($self->running_system->started_from_writable_device) {
        if ($self->running_system->started_from_device_installed_with_tails_installer) {
            $upgrade_description->contains_incremental_upgrade_path or
                $no_incremental_reason = 'no-incremental-upgrade-path';
        }
        else {
            $no_incremental_reason = 'not-installed-with-tails-installer';
        }
    }
    else {
        $no_incremental_reason = 'non-writable-device';
    }

    if (! defined($no_incremental_reason)) {
        my $incremental_upgrade_path = $upgrade_description->incremental_upgrade_path;
        my $free_memory             = $self->running_system->free_memory;
        my $memory_needed           = memory_needed($incremental_upgrade_path);
        if ($free_memory >= $memory_needed) {
            my $free_space   = $self->free_space;
            my $space_needed = space_needed($incremental_upgrade_path);
            if ($free_space >= $space_needed) {
                $upgrade_path = $incremental_upgrade_path;
                $upgrade_type = 'incremental';
            }
            else {
                $no_incremental_reason = 'not-enough-free-space';
                $self->info(errf(
                    $self->encoding->decode(gettext(
                        "The available incremental upgrade requires ".
                        "%{space_needed}s ".
                        "of free space on Tails system partition, ".
                        " but only %{free_space}s is available."
                    )),
                    {
                        space_needed => format_bytes($space_needed, mode => "iec"),
                        free_space   => format_bytes($free_space,   mode => "iec"),
                    }
                ));
            }
        }
        else {
            $no_incremental_reason = 'not-enough-free-memory';
            $self->info(errf(
                $self->encoding->decode(gettext(
                    "The available incremental upgrade requires ".
                    "%{memory_needed}s of free memory, but only ".
                    "%{free_memory}s is available."
                    )),
                {
                    memory_needed => format_bytes($memory_needed, mode => "iec"),
                    free_memory   => format_bytes($free_memory,   mode => "iec"),
                }
            ));
        }
    }

    # incremental upgrade is not available or possible,
    # let's see if we can do a full upgrade
    if (! defined($upgrade_path)) {
        if ($upgrade_description->contains_full_upgrade_path) {
            $upgrade_path = $upgrade_description->full_upgrade_path;
            $upgrade_type = 'full';
        }
        else {
            $self->fatal(
                $self->encoding->decode(gettext(
                    "An incremental upgrade is available, but no full upgrade is.\n".
                    "This should not happen. Please report a bug."
                )),
                title => $self->encoding->decode(gettext(
                    q{Error while detecting available upgrades}
                )),
            );
        }
    }

    if ($upgrade_type eq 'incremental') {
        exit(0) unless($self->dialog(
            errf(
                $self->encoding->decode(gettext(
                    "<b>You should upgrade to %{name}s %{version}s.</b>\n\n".
                    "For more information about this new version, go to %{details_url}s\n\n".
                    "We recommend you close all other applications during the upgrade.\n".
                    "Downloading the upgrade might take a long time, from several minutes to a few hours.\n\n".
                    "Download size: %{size}s\n\n".
                    "Do you want to upgrade now?"
                )),
                {
                    details_url => $upgrade_path->{'details-url'},
                    name        => $upgrade_description->product_name,
                    version     => $upgrade_path->{version},
                    size        => format_bytes($upgrade_path->{'total-size'},
                                                mode => "iec"),
                }),
            title        => $self->encoding->decode(gettext(q{Upgrade available})),
            ok_label     => $self->encoding->decode(gettext(q{Upgrade now})),
            cancel_label => $self->encoding->decode(gettext(q{Upgrade later})),
            ));
        $self->do_incremental_upgrade($upgrade_path);
    }
    else {
        exit(0) unless($self->dialog(
            errf(
                $self->encoding->decode(gettext(
                    "<b>You should do a manual upgrade to %{name}s %{version}s.</b>\n\n".
                    "For more information about this new version, go to %{details_url}s\n\n".
                     "It is not possible to automatically upgrade ".
                     "your device to this new version: %{explanation}s.\n\n".
                     "To learn how to do a manual upgrade, go to ".
                     "https://tails.boum.org/doc/upgrade/#manual",
                )),
                {
                    details_url => $upgrade_path->{'details-url'},
                    name        => $upgrade_description->product_name,
                    version     => $upgrade_path->{version},
                    explanation => $self->encoding->decode(
                        $self->no_incremental_explanation($no_incremental_reason)
                    ),
                }
            ),
            title => $self->encoding->decode(gettext(q{New version available})),
            type  => 'info',
        ));
        $self->do_full_upgrade($upgrade_path);
    }
}

fun target_files (HashRef $upgrade_path, AbsDir $destdir) {
    my @target_files;
    foreach my $target_file (@{$upgrade_path->{'target-files'}}) {
        my $basename    = path($target_file->{url})->basename;
        my $output_file = path($destdir, $basename);
        push @target_files,
            {
                %{$target_file},
                output_file => $output_file,
            };
    }

    return @target_files;
}

=head2 memory_needed

Returns the amount of free RAM, in bytes, needed to download and install
the incremental upgrade described in the upgrade path passed
as argument.

=cut
fun memory_needed (HashRef $upgrade_path) {
    # We need:
    #  - The size of the target file, because tails-iuk-get-target-file
    #    will download in a temporary directory stored in the root filesystem's
    #    union upper branch, that is in a tmpfs, that is in memory.
    #  - Enough memory to run the tails-iuk-get-target-file process.
    #  - Enough memory to run the tails-install-iuk process.
    #  - Some margin, e.g. for the squashfs kernel module to decompress
    #    the IUK when we copy its content to the system partition.
    my $get_target_file_process_memory = 60 * 1024 * 1024;
    my $install_iuk_process_memory = 90 * 1024 * 1024;
    my $margin = 64 * 1024 * 1024;

    $upgrade_path->{'total-size'}
        + $get_target_file_process_memory
        + $install_iuk_process_memory
        + $margin;
}

=head2 space_needed

Returns the amount of free space, in bytes, needed on the system
partition to download and install the incremental upgrade described in
the upgrade path passed as argument.

=cut
fun space_needed (HashRef $upgrade_path) {
    # At this point, we only know the size of the target file,
    # which is an IUK, i.e. a (compressed) SquashFS, whose content
    # will be copied to the system partition: vmlinuz, initrd; EFI,
    # isolinux, and utils directories; SquashFS diff.
    #
    # So the question basically boils down to: how well is the IUK
    # compressed?
    #
    # In practice, in most cases the total size of the IUK content is
    # dominated by the size of the SquashFS diff and the initrd, which
    # are already heavily compressed and won't be compressed further
    # in the IUK. So in most cases, we only need to leave room for
    # a tiny bit of margin, hence a $space_factor not much bigger
    # than 1 should do the job.
    #
    # Still, let's give ourselves a bit of margin, in the form or an
    # additional constant, just in case, for whatever reason, we ever
    # generate an IUK whose content is mostly uncompressed data,
    # and our $space_factor is not sufficient in itself.
    my $space_factor = 1.2;
    my $space_margin = 64 * 1024;
    $space_factor * $upgrade_path->{'total-size'} + $space_margin;
}

method get_target_files (HashRef $upgrade_path, CodeRef $url_transform, AbsDir $destdir) {
    my $title = $self->encoding->decode(gettext("Downloading upgrade"));
    my $info = $self->encoding->decode(errf(
        gettext(
            "Downloading the upgrade to %{name}s %{version}s..."
        ),
        {
            name    => $self->product_name,
            version => $upgrade_path->{version},
        }
    ));
    $self->info($info);

    foreach my $target_file (target_files($upgrade_path, $destdir)) {
        my @cmd = (
            'tails-iuk-get-target-file',
            '--uri',         $url_transform->($target_file->{url}),
            '--hash_type',   'sha256',
            '--hash_value',  $target_file->{sha256},
            '--size',        $target_file->{size},
            '--output_file', $target_file->{output_file},
        );
        if (! $ENV{HARNESS_ACTIVE}) {
            @cmd = ('sudo', '-n', '-u', 'tails-iuk-get-target-file', @cmd);
        }
        my ($exit_code, $stderr);
        my $success = 1;

        if ($self->batch) {
            IPC::Run::run \@cmd, '2>', \$stderr or $success = 0;
            $exit_code = $?;
        }
        else {
            IPC::Run::run \@cmd, '2>', \$stderr,
                '|', [qw{zenity --progress --percentage=0 --auto-close
                         --no-cancel}, '--title', $title, '--text', $info]
                or $success = 0;
            $exit_code = $?;
        }

        $success or $self->fatal(
            errf("<b>%{error_msg}s</b>\n\n%{details}s",
                 {
                     error_msg      => $self->encoding->decode(errf(
                         gettext(
                             q{<b>The upgrade could not be downloaded.</b>\n\n}.
                             q{Check your network connection, and restart }.
                             q{Tails to try upgrading again.\n\n}.
                             q{If the problem persists, go to }.
                             q{file:///usr/share/doc/tails/website/doc/upgrade/error/download.en.html}
                         ),
                         {
                             target_url => $target_file->{url},
                         }
                     )),
                     details => $self->encoding->decode(gettext(
                         q{For debugging information, execute the following command: sudo tails-debugging-info}
                     )),
                 }
            ),
            title => $self->encoding->decode(gettext(
                q{Error while downloading the upgrade}
            )),
            debugging_info => $self->encoding->decode(errf(
                "exit code: %{exit_code}i\n\n".
                "stderr:\n%{stderr}s",
                { exit_code => $exit_code, stderr => $stderr }
            )),
        );

        -e $target_file->{output_file} or $self->fatal(
            $self->encoding->decode(errf(
                gettext(
                    q{Output file '%{output_file}s' does not exist, but }.
                    q{tails-iuk-get-target-file did not complain. }.
                    q{Please report a bug.}
                ),
                { output_file => $target_file->{output_file} }
            )),
            title => $self->encoding->decode(gettext(
                q{Error while downloading the upgrade}
            )),
        );
    }
}

method do_incremental_upgrade (HashRef $upgrade_path) {
    my ($stdout, $stderr, $success, $exit_code);

    my ($target_files_tempdir) = $self->fatal_run_cmd(
        cmd       => ['tails-iuk-mktemp-get-target-file'],
        error_title => $self->encoding->decode(gettext(
            q{Error while creating temporary downloading directory}
        )),
        error_msg => $self->encoding->decode(gettext(
            "Failed to create temporary download directory"
        )),
        as        => 'tails-iuk-get-target-file',
    );
    chomp $target_files_tempdir;

    my $url_transform = sub {
        my $url = shift;

        try {
            $url = Tails::MirrorPool->new(
                # hack: piggy-back on the logic we have in T::RunningSystem
                # for handling the default value and override_baseurl
                baseurl         => $self->running_system->baseurl,
                ($ENV{HARNESS_ACTIVE}
                     ? (fallback_prefix => 'https://127.0.0.1:'
                                           . $ENV{TAILS_FALLBACK_DL_URL_PORT}
                                           . '/tails')
                     : ()
                ),
            )->transformURL($url);
        } catch {
            $self->fatal(
                $self->encoding->decode(gettext(
                    "<b>Could not choose a download server.</b>\n\n".
                    "This should not happen. Please report a bug.",
                )),
                title => $self->encoding->decode(gettext(
                    q{Error while choosing a download server}
                )),
                debugging_info => $self->encoding->decode($_),
            );
        };

        return $url;
    };

    $self->get_target_files(
        $upgrade_path, $url_transform, path($target_files_tempdir)
    );

    $self->dialog(
        $self->encoding->decode(gettext(
            "The upgrade was successfully downloaded.\n\n".
            "The network connection will now be disabled.\n\n".
            "Please save your work and close all other applications."
        )),
        type     => 'info',
        title    => $self->encoding->decode(gettext(
            q{Upgrade successfully downloaded}
        )),
        ok_label => $self->encoding->decode(gettext(q{Apply upgrade})),
    );

    $self->install_iuk($upgrade_path, path($target_files_tempdir));

    $self->dialog(
        $self->encoding->decode(gettext(
            "<b>Your Tails device was successfully upgraded.</b>\n\n".
            "Some security features were temporarily disabled.\n".
            "You should restart Tails on the new version as soon as possible.\n\n".
            "Do you want to restart now?"
        )),
        title        => $self->encoding->decode(gettext(q{Restart Tails})),
        ok_label     => $self->encoding->decode(gettext(q{Restart now})),
        cancel_label => $self->encoding->decode(gettext(q{Restart later})),
    ) && $self->restart_system;

    exit(0);
}

method restart_system () {
    $self->info("Restarting the system");
    $self->fatal_run_cmd(
        cmd       => ['/sbin/reboot'],
        error_title => $self->encoding->decode(gettext(
            q{Error while restarting the system}
        )),
        error_msg => $self->encoding->decode(gettext(
            q{Failed to restart the system}
        )),
        as        => 'root',
    ) unless $ENV{HARNESS_ACTIVE};
}

method do_full_upgrade (HashRef $upgrade_path) {
    exit(0);
}

method shutdown_network () {
    $self->info("Shutting down network connection");
    $self->fatal_run_cmd(
        cmd       => ['tails-shutdown-network'],
        error_title => $self->encoding->decode(gettext(
            q{Error while shutting down the network}
        )),
        error_msg => $self->encoding->decode(gettext(
            q{Failed to shutdown network}
        )),
        as        => 'root',
    ) unless $ENV{HARNESS_ACTIVE};
}

method install_iuk (HashRef $upgrade_path, AbsDir $target_files_tempdir) {
    my $title = $self->encoding->decode(gettext("Upgrading the system"));
    my $info = $self->encoding->decode(gettext(
        "<b>Your Tails device is being upgraded...</b>\n\n".
        "For security reasons, the networking is now disabled."
    ));
    $self->info($info);

    $self->shutdown_network;

    my @target_files = target_files($upgrade_path, $target_files_tempdir);
    assert(@target_files == 1);

    my @args;
    push @args, (
        '--override_liveos_mountpoint', $self->override_liveos_mountpoint
    ) if $self->has_override_liveos_mountpoint;

    my @cmd = ('tails-install-iuk', @args, $target_files[0]->{output_file});
    if (! $ENV{HARNESS_ACTIVE}) {
        @cmd = ('sudo', '-n', '-u', 'tails-install-iuk', @cmd);
    }

    my ($exit_code, $stdout, $stderr, $zenity_h);
    my $success = 1;

    $zenity_h = IPC::Run::start [qw{tail -f /dev/null}], '|', [qw{zenity --progress --pulsate --no-cancel --auto-close},
                       '--title', $title, '--text', $info] unless $self->batch;
    IPC::Run::run \@cmd, '>', \$stdout, '2>', \$stderr or $success = 0;
    $exit_code = $?;
    $zenity_h->kill_kill unless $self->batch;

    $success or $self->fatal(
        errf("<b>%{error_msg}s</b>\n\n%{details}s",
             {
                 error_msg => $self->encoding->decode(gettext(
                     q{<b>An error occured while installing the upgrade.</b>\n\n}.
                     q{Your Tails device needs to be repaired and might be unable to restart.\n\n}.
                     q{Please follow the instructions at }.
                     q{file:///usr/share/doc/tails/website/doc/upgrade/error/install.en.html})),
                 details   => $self->encoding->decode(gettext(
                     q{For debugging information, execute the following command: sudo tails-debugging-info}
                 )),
             },
         ),
        title => $self->encoding->decode(gettext(
            q{Error while installing the upgrade}
        )),
        debugging_info => $self->encoding->decode(errf(
            "exit code: %{exit_code}i\n\n".
            "stdout:\n%{stdout}s\n\n".
            "stderr:\n%{stderr}s",
            { exit_code => $exit_code, stdout => $stdout, stderr => $stderr }
        )),
    );
}

no Moo;
1;
