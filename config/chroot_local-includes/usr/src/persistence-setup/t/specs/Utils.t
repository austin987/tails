use Test::Spec;

use 5.10.1;
use strictures 2;

use Carp;
use File::stat;
use File::Temp qw{tempdir tempfile};
use Path::Tiny;
use IPC::System::Simple qw{systemx};
use Tails::Persistence::Utils qw{check_config_file_permissions get_variable_from_file};
use Test::Fatal qw{dies_ok lives_ok};

describe 'A file' => sub {
    my ($fh, $file);
    before sub {
        ($fh, $file) = tempfile();
        print $fh '';
        close $fh;
    };
    describe 'that contains "a=b" on the first line' => sub {
        before sub {
            my $fh = path($file)->openw;
            print $fh "a=b\n";
        };
        it 'has value "b" for variable "a"' => sub {
            is(get_variable_from_file($file, "a"), "b");
        };
    };
    describe 'that contains "  a=b" on the first line' => sub {
        before sub {
            my $fh = path($file)->openw;
            print $fh "  a=b\n";
        };
        it 'has value "b" for variable "a"' => sub {
            is(get_variable_from_file($file, "a"), "b");
        };
    };
    describe 'that contains "a=b" on the second line' => sub {
        before sub {
            my $fh = path($file)->openw;
            print $fh "bla\na=b\n";
        };
        it 'has value "b" for variable "a"' => sub {
            is(get_variable_from_file($file, "a"), "b");
        };
    };
    describe 'that contains "a = b"' => sub {
        before sub {
            my $fh = path($file)->openw;
            print $fh "a = b\n";
        };
        it 'has no value for variable "a"' => sub {
            ok(! defined(get_variable_from_file($file, "a")));
        };
    };
};

# check_config_file_permissions
describe 'A configuration file' => sub {
    my ($file, $tempdir);
    my $expected = {
        mode => oct(600),
        uid  => '4242',
        gid  => '2424',
        acl  => '',
    };
    before sub {
        # Set up test environment
        $tempdir = tempdir(CLEANUP => 1);
        $file    = path($tempdir, 'persistence.conf');
        # Check that we're running under fakeroot
        my ($test_fh, $test_file) = tempfile();
        print $test_fh '';
        close $test_fh;
        chown 0, 0, $test_file or croak "Please run this test under fakeroot";
        my $st = stat($test_file);
        $st->uid eq 0 or croak "Please run this test under fakeroot";
        $st->gid eq 0 or croak "Please run this test under fakeroot";
    };
    describe 'that has correct ownership, permissions and ACL' => sub {
        before sub {
            $file->touch;
            chown $expected->{uid}, $expected->{gid}, $file;
            chmod $expected->{mode}, $file;
        };
        it 'is accepted' => sub {
            lives_ok { check_config_file_permissions($file, $expected) };
        };
    };
    describe 'that is a directory' => sub {
        before sub {
            mkdir $file;
            chown $expected->{uid}, $expected->{gid}, $file;
            chmod $expected->{mode}, $file;
        };
        it 'is rejected' => sub {
            dies_ok { check_config_file_permissions($file, $expected) };
        };
    };
    describe 'that is a broken symlink' => sub {
        before sub {
            my $destination = path($tempdir, 'destination');
            link $destination, $file;
        };
        it 'is rejected' => sub {
            dies_ok { check_config_file_permissions($file, $expected) };
        };
    };
    describe 'that is a symlink to a file with correct ownership, permissions and ACL' => sub {
        before sub {
            my $destination = path($tempdir, 'destination');
            $destination->touch;
            chown $expected->{uid}, $expected->{gid}, $destination;
            chmod $expected->{mode}, $destination;
            symlink $destination, $file or croak "Could not link '$file' to '$destination'";
        };
        it 'is rejected' => sub {
            dies_ok { check_config_file_permissions($file, $expected) };
        };
    };
    describe 'that has wrong owner' => sub {
        before sub {
            $file->touch;
            chown 0, $expected->{gid}, $file;
            chmod $expected->{mode}, $file;
        };
        it 'is rejected' => sub {
            dies_ok { check_config_file_permissions($file, $expected) };
        };
    };
    describe 'that has wrong owning group' => sub {
        before sub {
            $file->touch;
            chown $expected->{uid}, 0, $file;
            chmod $expected->{mode}, $file;
        };
        it 'is rejected' => sub {
            dies_ok { check_config_file_permissions($file, $expected) };
        };
    };
    describe 'that has wrong permissions' => sub {
        before sub {
            $file->touch;
            chown $expected->{uid}, $expected->{gid}, $file;
            chmod 0644, $file;
        };
        it 'is rejected' => sub {
            dies_ok { check_config_file_permissions($file, $expected) };
        };
    };
    describe 'that has wrong ACL' => sub {
        before sub {
            $file->touch;
            chown $expected->{uid}, $expected->{gid}, $file;
            chmod $expected->{mode}, $file;
            systemx('/bin/setfacl', '-m', 'other:r', $file);
        };
        it 'is rejected' => sub {
            dies_ok { check_config_file_permissions($file, $expected) };
        };
    };
};

runtests unless caller;
