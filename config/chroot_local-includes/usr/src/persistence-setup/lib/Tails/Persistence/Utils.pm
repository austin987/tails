=head1 NAME

Tails::Persistence::Utils - utilities for Tails persistent storage

=cut

package Tails::Persistence::Utils;

use strictures 2;
use 5.10.1;

use Carp;
use Function::Parameters;
use IPC::System::Simple qw{capturex};
use List::MoreUtils qw{last_value};
use Path::Tiny;
use Types::Standard qw(HashRef Int Str StrictNum);
use Types::Path::Tiny qw{Path};

use namespace::clean;

use Exporter;
our @ISA = qw{Exporter};
our @EXPORT = qw{align_up_at_2MiB align_down_at_2MiB step_name_to_class_name get_variable_from_file check_config_file_permissions};


=head1 FUNCTIONS

=cut

fun round_down (StrictNum $number, StrictNum $round) {
    return (int($number/$round)) * $round if $number % $round;
    return $number;
}

fun round_up (StrictNum $number, StrictNum $round) {
    return (1 + int($number/$round)) * $round if $number % $round;
    return $number;
}

fun align_up_at_2MiB (Int $bytes) {
    round_up($bytes, 2 * 2 ** 20)
}

fun align_down_at_2MiB (Int $bytes) {
    round_down($bytes, 2 * 2 ** 20)
}

fun step_name_to_class_name (Str $name) {
    'Tails::Persistence::Step::' . ucfirst($name);
}

fun get_variable_from_file (Str $file, Str $variable) {
    foreach my $line (path($file)->lines({chomp => 1})) {
        if (my ($name, $value) =
                ($line =~ m{\A [[:space:]]* ($variable)=(.*) \z}xms)) {
            return $value;
        }
    }

    return;
}

=head2 check_config_file_permissions

Refuse to read persistence.conf if it has different type, permission
or ownership than expected. We don't check the parent directory since
live-persist ensures it's right for us.

=cut
fun check_config_file_permissions (Path $config_file_path, HashRef $expected) {
    croak(q{persistence.conf is a symbolic link})  if -l $config_file_path;
    croak(q{persistence.conf is not a plain file}) unless -f $config_file_path;

    my $st = $config_file_path->stat();

    # ownership
    foreach my $field (qw{uid gid}) {
        my $actual_value = $st->$field;
        croak("Expected value for '$field' is not defined")
            unless defined $expected->{$field};
        $actual_value eq $expected->{$field}
            or croak("persistence.conf has unsafe $field: '$actual_value'");
    }

    # mode
    my $actual_mode   = sprintf("%04o",   $st->mode & oct(7777));
    my $expected_mode = sprintf("%04o", $expected->{mode});
    $actual_mode eq $expected_mode
        or croak(sprintf(
            "persistence.conf has unsafe mode: '%s'; expected: '%s'",
            $actual_mode, $expected_mode));

    # ACL
    capturex('/bin/getfacl', '--omit-header', '--skip-base', $config_file_path)
        eq $expected->{acl}
            or croak("persistence.conf has unsafe ACLs");

    return 1;
}

1;
