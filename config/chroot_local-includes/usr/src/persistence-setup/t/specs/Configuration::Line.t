use Test::Spec;

use 5.10.1;
use strictures 2;

use Tails::Persistence::Configuration::Line;

describe "A Line object" => sub {

    sub stringify_and_split {
        my $config_line = shift;
        split /\s+/, $config_line->stringify;
    }

    describe "built with only a destination" => sub {
        my $line;
        before sub {
            $line = Tails::Persistence::Configuration::Line->new(
                destination => 'dst',
            );
        };
        it "stringifies to a string with exactly one column" => sub {
            my ($destination, $options) = stringify_and_split($line);
            ok(defined($destination) && !defined($options));
        };
    };

    describe "built from an empty string" => sub {
        it "is undef" => sub {
            ok(!defined(
                Tails::Persistence::Configuration::Line->new_from_string("")
            ));
        };
    };

    describe "built from a commented string" => sub {
        it "is undef" => sub {
            ok(!defined(
                Tails::Persistence::Configuration::Line->new_from_string("# destination optA,optB")
            ));
        };
    };

    describe "built from a one-column string" => sub {
        my $line;
        before sub {
            $line = Tails::Persistence::Configuration::Line->new_from_string(
                "/home/amnesia/Music"
            );
        };
        it "stringifies to a string with exactly one column" => sub {
            my ($destination, $options) = stringify_and_split($line);
            ok(defined($destination) && !defined($options));
        };
    };

    describe "built from a string with options" => sub {
        my ($input_options, $line);
        before sub {
            $input_options = "optA,optB";
            $line = Tails::Persistence::Configuration::Line->new_from_string(
                "destination $input_options"
            );
        };
        it "stringifies to a string with the same options" => sub {
            my ($destination, $options) = stringify_and_split($line);
            ok(defined($options)
                   && length($options)
                   && $options eq $input_options
            );
        };
    };

};

runtests unless caller;
