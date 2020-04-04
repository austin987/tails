use Test::Spec;
use Test::Exception;

use 5.10.1;
use strictures 2;
use Function::Parameters;
use Tails::Persistence::Configuration::Atom;
use Tails::Persistence::Configuration::Line;

fun stringify_and_split ($config_atom) {
    split /\s+/, $config_atom->stringify;
}

describe 'A configuration atom object' => sub {
    describe 'built from a line' => sub {
        my $atom;
        before sub {
            my $line = Tails::Persistence::Configuration::Line->new(
                destination => 'dst'
            );
            $atom = Tails::Persistence::Configuration::Atom->new_from_line(
                $line,
                enabled => 1,
            );
        };
        it 'is defined' => sub {
            ok(defined($atom));
        };
    };
    describe 'built with a destination' => sub {
        my $atom;
        before sub {
            $atom = Tails::Persistence::Configuration::Atom->new(
                destination => 'dst', enabled => 1,
            );
        };
        it 'is defined' => sub {
            ok(defined($atom));
        };
        it "stringifies to a string with exactly one column" => sub {
            my ($destination, $options) = stringify_and_split($atom);
            ok(defined($destination) && !defined($options));
        };
    };
    describe 'built with options optA,optB' => sub {
        my $atom;
        before sub {
            $atom = Tails::Persistence::Configuration::Atom->new(
                destination => 'dst', enabled => 1, options => [ qw{optA optB} ],
            );
        };
        it 'has options equivalent to optA,optB' => sub {
            ok($atom->options_are(qw{optA optB}));
        };
        it 'has options equivalent to optB,optA' => sub {
            ok($atom->options_are(qw{optB optA}));
        };
        it 'has options not equivalent to optA,optB,optC' => sub {
            ok(! $atom->options_are(qw{optA optB optC}));
        };
        it 'has options not equivalent to optA' => sub {
            ok(! $atom->options_are(qw{optA}));
        };
        it 'equals equivalent line with options optA,optB' => sub {
            my $line = Tails::Persistence::Configuration::Line->new(
                destination => 'dst', options => [ qw{optA optB} ]
            );
            ok($atom->equals_line($line));
        };
        it 'equals equivalent line with options optB,optA' => sub {
            my $line = Tails::Persistence::Configuration::Line->new(
                destination => 'dst', options => [ qw{optB optA} ]
            );
            ok($atom->equals_line($line));
        };
    };
    describe '\'s constructor, run with no argument' => sub {
        it 'dies' => sub {
            dies_ok { Tails::Persistence::Configuration::Atom->new() };
        };
    };
};

runtests unless caller;
