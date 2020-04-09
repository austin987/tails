use Test::Spec;

use 5.10.1;
use strictures 2;

use Tails::Persistence::Configuration::Line;
use Tails::Persistence::Configuration::Presets;

describe 'A configuration presets object' => sub {
    my $presets;
    before sub {
        $presets = Tails::Persistence::Configuration::Presets->new();
    };
    it 'is defined' => sub {
        ok(defined($presets));
    };
    it 'can return all presets' => sub {
        ok($presets->all);
    };
    it 'has 11 elements' => sub {
        is(scalar($presets->all), 11);
    };
    it 'has a GnuPG preset' => sub {
        is(scalar(grep { $_->{name} eq 'GnuPG' } $presets->all), 1);
    };
    it 'has a GnuPG atom' => sub {
        is(scalar(grep { $_->destination eq '/home/amnesia/.gnupg' } $presets->atoms), 1);
    };
    it 'has no XYZ preset' => sub {
        is(scalar(grep { $_->{name} eq 'XYZ' } $presets->all), 0);
    };
    describe 'with state set from a line that duplicates an enabled-by-default preset' => sub {
        before sub {
            $presets->set_state_from_lines(
                Tails::Persistence::Configuration::Line->new(
                    destination => '/home/amnesia/Persistent',
                )
            );
        };
        it 'has this preset enabled' => sub {
            my @presets = grep { $_->destination eq '/home/amnesia/Persistent' } $presets->atoms;
            ok($presets[0]->enabled);
        };
    };
    describe 'with state set from a line that duplicates a disabled-by-default preset' => sub {
        before sub {
            $presets->set_state_from_lines(
                Tails::Persistence::Configuration::Line->new(
                    destination => '/home/amnesia/.gnupg',
                    options     => [ 'source=gnupg' ],
                )
            );
        };
        it 'has this preset enabled' => sub {
            my @presets = grep { $_->destination eq '/home/amnesia/.gnupg' } $presets->atoms;
            ok($presets[0]->enabled);
        };
    };
};

runtests unless caller;
