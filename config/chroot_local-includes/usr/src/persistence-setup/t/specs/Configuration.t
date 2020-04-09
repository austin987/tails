use Test::Spec;

use 5.10.1;
use File::Temp qw{tempfile};
use Path::Tiny;
use Tails::Persistence::Configuration;

describe 'A configuration object' => sub {
    describe 'built with no argument and an empty configuration file' => sub {
        my ($configuration, $config_fh, $config_filename);
        before sub {
            ($config_fh, $config_filename) = tempfile();
            print $config_fh '';
            close $config_fh;
            $configuration = Tails::Persistence::Configuration->new(
                config_file_path => $config_filename
            );
        };
        it 'is defined' => sub {
            ok(defined($configuration));
        };
        it 'has defined presets' => sub {
            ok(defined($configuration->presets));
        };
        it 'can return all presets' => sub {
            ok($configuration->presets->all);
        };
        it 'can return all atoms' => sub {
            ok($configuration->atoms);
        };
        it 'has a GnuPG preset' => sub {
            is(scalar(grep { $_->{id} eq 'GnuPG' } $configuration->presets->all), 1);
        };
        it 'has a GnuPG atom' => sub {
            is(scalar(grep { $_->destination eq '/home/amnesia/.gnupg' } $configuration->all_atoms), 1);
        };
        it 'has 12 atoms' => sub {
            is(scalar($configuration->all_atoms), 12);
        };
        it 'has 1 enabled atom' => sub {
            is(scalar($configuration->all_enabled_atoms), 1);
        };
        it 'has 1 enabled line' => sub {
            is(scalar($configuration->all_enabled_lines), 1);
        };
    };
    describe 'built with no argument and a non-empty configuration file' => sub {
        my ($configuration, $config_fh, $config_filename);
        before sub {
            ($config_fh, $config_filename) = tempfile();
            say $config_fh <<EOF
/home/amnesia link,source=dotfiles
/home/amnesia/.myapp source=myapp
/home/amnesia/.gnupg source=gnupg
EOF
;
            close $config_fh;
            $configuration = Tails::Persistence::Configuration->new(
                config_file_path => $config_filename
            );
        };
        it 'has 13 atoms' => sub {
            is(scalar($configuration->all_atoms), 13);
        };
        it 'has 4 enabled atoms' => sub {
            is(scalar($configuration->all_enabled_atoms), 4);
        };
        it 'has 4 enabled lines' => sub {
            is(scalar($configuration->all_enabled_lines), 4);
        };
    };
};

runtests unless caller;
