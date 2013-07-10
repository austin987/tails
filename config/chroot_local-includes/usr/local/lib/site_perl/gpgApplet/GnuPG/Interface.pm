package gpgApplet::GnuPG::Interface;
use Any::Moose;
extends 'GnuPG::Interface';

use namespace::autoclean;
use Carp;

sub get_public_keys_light ( $@ ) {
    my ( $self, @key_ids ) = @_;

    return $self->get_keys_light(
        commands     => ['--list-public-keys'],
        command_args => [@key_ids],
    );
}

sub get_secret_keys_light ( $@ ) {
    my ( $self, @key_ids ) = @_;

    return $self->get_keys_light(
        commands     => ['--list-secret-keys'],
        command_args => [@key_ids],
    );
}

sub get_keys_light {
    my ( $self, %args ) = @_;

    my $saved_options = $self->options();
    my $new_options   = $self->options->copy();
    $self->options($new_options);
    $self->options->push_extra_args(
        '--with-colons',
        '--fixed-list-mode',
        '--with-fingerprint',
        '--with-fingerprint',
        '--with-key-data',
    );

    my $stdin  = IO::Handle->new();
    my $stdout = IO::Handle->new();

    my $handles = GnuPG::Handles->new(
        stdin  => $stdin,
        stdout => $stdout,
    );

    my $pid = $self->wrap_call(
        handles => $handles,
        %args,
    );

    my @returned_keys;
    my $current_primary_key;
    my $current_signed_item;
    my $current_key;

    require GnuPG::PublicKey;
    require GnuPG::SecretKey;
    require GnuPG::SubKey;
    require GnuPG::Fingerprint;
    require GnuPG::UserId;
    require GnuPG::UserAttribute;
    require GnuPG::Signature;
    require GnuPG::Revoker;

    while (<$stdout>) {
        my $line = $_;
        chomp $line;
        my @fields = split ':', $line, -1;
        next unless @fields > 3;

        my $record_type = $fields[0];

        if ( $record_type eq 'pub' or $record_type eq 'sec' ) {
            push @returned_keys, $current_primary_key
                if $current_primary_key;

            my (
                $user_id_validity, $key_length, $algo_num, $hex_key_id,
                $creation_date, $expiration_date,
                $local_id, $owner_trust, $user_id_string,
                $sigclass, #unused
                $usage_flags,
            ) = @fields[ 1 .. $#fields ];

            # --fixed-list-mode uses epoch time for creation and expiration date strings.
            # For backward compatibility, we convert them back using GMT;
            my $expiration_date_string;
            if (defined $expiration_date) {
              if ($expiration_date eq '') {
                $expiration_date = undef;
              } else {
                $expiration_date_string = $self->_downrez_date($expiration_date);
              }
            }
            my $creation_date_string = $self->_downrez_date($creation_date);

            $current_primary_key = $current_key
                = $record_type eq 'pub'
                ? GnuPG::PublicKey->new()
                : GnuPG::SecretKey->new();

            $current_primary_key->hash_init(
                length                 => $key_length,
                algo_num               => $algo_num,
                hex_id                 => $hex_key_id,
                local_id               => $local_id,
                owner_trust            => $owner_trust,
                creation_date          => $creation_date,
                expiration_date        => $expiration_date,
                creation_date_string   => $creation_date_string,
                expiration_date_string => $expiration_date_string,
                usage_flags            => $usage_flags,
            );

            $current_signed_item = $current_primary_key;
        }
        elsif ( $record_type eq 'fpr' ) {
            my $hex = $fields[9];
            my $f = GnuPG::Fingerprint->new( as_hex_string => $hex );
            $current_key->fingerprint($f);
        }
        elsif ( $record_type eq 'sig' or
                $record_type eq 'rev'
              ) {
            my (
                $validity,
                $algo_num,              $hex_key_id,
                $signature_date,
                $expiration_date,
                $user_id_string,
                $sig_type,
            ) = @fields[ 1, 3 .. 6, 9, 10 ];

            my $expiration_date_string;
            if (defined $expiration_date) {
              if ($expiration_date eq '') {
                $expiration_date = undef;
              } else {
                $expiration_date_string = $self->_downrez_date($expiration_date);
              }
            }
            my $signature_date_string = $self->_downrez_date($signature_date);

            my ($sig_class, $is_exportable);
            if ($sig_type =~ /^([[:xdigit:]]{2})([xl])$/ ) {
              $sig_class = hex($1);
              $is_exportable = ('x' eq $2);
            }

            my $signature = GnuPG::Signature->new(
                validity       => $validity,
                algo_num       => $algo_num,
                hex_id         => $hex_key_id,
                date           => $signature_date,
                date_string    => $signature_date_string,
                expiration_date => $expiration_date,
                expiration_date_string => $expiration_date_string,
                user_id_string => GnuPG::Interface::unescape_string($user_id_string),
                sig_class      => $sig_class,
                is_exportable  => $is_exportable,
            );

            if ( $current_signed_item->isa('GnuPG::Key') ||
                 $current_signed_item->isa('GnuPG::UserId') ||
                 $current_signed_item->isa('GnuPG::Revoker') ||
                 $current_signed_item->isa('GnuPG::UserAttribute')) {
              if ($record_type eq 'sig') {
                $current_signed_item->push_signatures($signature);
              } elsif ($record_type eq 'rev') {
                $current_signed_item->push_revocations($signature);
              }
            } else {
              warn "do not know how to handle signature line: $line\n";
            }
        }
        elsif ( $record_type eq 'uid' ) {
            my ( $validity, $user_id_string ) = @fields[ 1, 9 ];

            $current_signed_item = GnuPG::UserId->new(
                validity  => $validity,
                as_string => GnuPG::Interface::unescape_string($user_id_string),
            );

            $current_primary_key->push_user_ids($current_signed_item);
        }
        elsif ( $record_type eq 'sub' or $record_type eq 'ssb' ) {
            my (
                $validity, $key_length, $algo_num, $hex_id,
                $creation_date, $expiration_date,
                $local_id,
                $dummy0, $dummy1, $dummy2, #unused
                $usage_flags,
            ) = @fields[ 1 .. 11 ];

            my $expiration_date_string;
            if (defined $expiration_date) {
                if ($expiration_date eq '') {
                    $expiration_date = undef;
                } else {
                    $expiration_date_string = $self->_downrez_date($expiration_date);
                }
            }
            my $creation_date_string = $self->_downrez_date($creation_date);

            $current_signed_item = $current_key
                = GnuPG::SubKey->new(
                validity               => $validity,
                length                 => $key_length,
                algo_num               => $algo_num,
                hex_id                 => $hex_id,
                creation_date          => $creation_date,
                expiration_date        => $expiration_date,
                creation_date_string   => $creation_date_string,
                expiration_date_string => $expiration_date_string,
                local_id               => $local_id,
                usage_flags            => $usage_flags,
                );

            $current_primary_key->push_subkeys($current_signed_item);
        }
    }

    waitpid $pid, 0;

    push @returned_keys, $current_primary_key
        if $current_primary_key;

    $self->options($saved_options);
    $self->options->clear_extra_args;

    return @returned_keys;
}

no Any::Moose;
1;
