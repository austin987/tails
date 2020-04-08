#!perl

use 5.10.1;
use strictures 2;

use lib "lib";

use Test::More;
use Test::BDD::Cucumber::StepFile;

use Function::Parameters;
use List::Util qw{first};
use List::MoreUtils qw{all};
use Path::Tiny;
use File::Temp qw{tempfile};

use Tails::Persistence::Configuration;
use Tails::Persistence::Configuration::ConfigFile;
use Tails::Persistence::Step::Configure;

fun get_temp_file () {
    my ($fh, $filename) = tempfile();
    return path($filename);
}

Given qr{^the file does not exist$}, sub {
    my $config_path = get_temp_file();
    S->{config_path} = $config_path;
    ok(defined($config_path));
};

Given qr{^the file is empty$}, sub {
    my $config_path = get_temp_file();
    S->{config_path} = $config_path;
    $config_path->touch;
    ok(-e $config_path);
};

Given qr{^the file has a valid one-column line$}, sub {
    my $config_path = get_temp_file();
    S->{config_path} = $config_path;
    my $fh = $config_path->openw;
    say $fh "/home/amnesia";
};

Given qr{^the file has only a commented-out line$}, sub {
    my $config_path = get_temp_file();
    S->{config_path} = $config_path;
    my $fh = $config_path->openw;
    say $fh "  #/home/amnesia";
};

Given qr{^the file has a valid two-different-columns line$}, sub {
    my $config_path = get_temp_file();
    S->{config_path} = $config_path;
    my $fh = $config_path->openw;
    say $fh "/home/amnesia /something/else";
};

Given qr{^the file has two valid two-columns lines$}, sub {
    my $config_path = get_temp_file();
    S->{config_path} = $config_path;
    my $fh = $config_path->openw;
    say $fh "/home/amnesia /something/else";
    say $fh "/var/lib/tor /var/lib/tor";
};

Given qr{^the file has a valid line with options '([^']*)'$}, sub {
    my $options = C->matches->[0];
    my $config_path = get_temp_file();
    S->{config_path} = $config_path;
    my $fh = $config_path->openw;
    say $fh "/home/amnesia $options";
};

Given qr{^the file has the following content$}, sub {
    my $content = C->data;
    my $config_path = get_temp_file();
    S->{config_path} = $config_path;
    my $fh = $config_path->openw;
    say $fh $content;
};

Given qr{^I have a Configuration object$}, sub {
    my $config_path = get_temp_file();
    S->{config_path} = $config_path;
    $config_path->touch;
    my $configuration = Tails::Persistence::Configuration->new(
        config_file_path => $config_path
    );
    S->{configuration} = $configuration;
    ok(defined($configuration));
};

Given qr{^I have a Step::Configure object$}, sub {
    my $configure = Tails::Persistence::Step::Configure->new(
        name => 'configure',
        configuration => S->{configuration},
        drive_model => 'drive model',
        drive_vendor => 'drive vendor',
        go_callback => sub { S->{configuration}->save; },
        success_callback => sub { return 1; },
        persistence_partition_device_file => 'persistence partition device file',
        persistence_partition_size => 12000,
    );
    S->{configure} = $configure;
    ok(defined($configure));
};

When qr{^I create a ConfigFile object$}, sub {
    my $config_path = S->{config_path};
    my $config_file = Tails::Persistence::Configuration::ConfigFile->new(
        config_file_path => $config_path
    );
    S->{config_file} = $config_file;
    ok(defined($config_file));
};

When qr{^I write in-memory configuration to file$}, sub {
    S->{config_file}->save;
    ok("in-memory configuration saved to file");
};

When qr{^I merge the presets and the file$}, sub {
    my $config_path = S->{config_path};
    my $configuration = Tails::Persistence::Configuration->new(
        config_file_path => $config_path
    );
    S->{configuration} = $configuration;
    ok(defined($configuration));
};

When qr{^I toggle an inactive setting on$}, sub {
    my $setting = first { ! $_->is_active } S->{configure}->all_settings;
    ok(defined($setting));
    $setting->set_active(1);
    ok($setting->is_active);
};

When qr{^I toggle the "([^"]+)" inactive setting on$}, sub {
    my $id = C->matches->[0];
    use Data::Dumper::Concise;
    my $inactive_setting = first {
        my $setting = $_;
        ! $_->is_active && $setting->id eq $id;
    } S->{configure}->all_settings;
    ok(defined($inactive_setting));
    $inactive_setting->set_active(1);
    ok($inactive_setting->is_active);
};

When qr{^I toggle an active setting off$}, sub {
    my $setting = first { $_->is_active } S->{configure}->all_settings;
    $setting->set_active(0);
    ok(! $setting->is_active);
};

When qr{^I toggle the "([^"]+)" active setting off$}, sub {
    my $id = C->matches->[0];
    my $active_setting = first {
        my $setting = $_;
        $setting->is_active && $setting->id eq $id;
    } S->{configure}->all_settings;
    ok(defined($active_setting));
    $active_setting->set_active(0);
    ok(! $active_setting->is_active);
};

When qr{^I click the save button$}, sub {
    S->{configure}->go_button->clicked;
};

Then qr{^the file should be created$}, sub {
    ok(-e S->{config_file}->config_file_path->stringify);
};

Then qr{^the list of lines in the file object should be empty$}, sub {
    is(S->{config_file}->all_lines, 0);
};

Then qr{^the list of options should be empty$}, sub {
    my @lines = S->{config_file}->all_lines;
    my $line = $lines[0];
    is($line->all_options, 0);
};

Then qr{^the output string should contain (\d+) lines$}, sub {
    my $expected_lines = C->matches->[0];
    my $output = S->{config_file}->output;
    chomp $output;
    my $lines = split(/\n/, $output);
    is($lines, $expected_lines);
};

Then qr{^the file should contain (\d+) line[s]?$}, sub {
    my $expected_lines = C->matches->[0];
    my $config_path = S->{config_path};
    my @lines = path($config_path)->lines;
    is(@lines, $expected_lines);
};

Then qr{^the file should contain the "([^"]*)" line$}, sub {
    my $expected_line = C->matches->[0];
    my $config_path = S->{configuration}->config_file_path;
    my $matching_lines = grep {
        $_ eq $expected_line
    } path($config_path)->lines({chomp => 1});
    is($matching_lines, 1);
};

Then qr{^the first line in file should have options '([^']*)'$}, sub {
    my $expected_options = C->matches->[0];
    my $config_path = S->{config_path};
    my @lines = path($config_path)->lines;
    my $first_line = $lines[0];
    my ($destination, $options) = split /\s+/, $first_line;
    ok(defined($options)
        && length($options)
        && $options eq $expected_options
    );
};

Then qr/^the options list should contain (\d+) element[s]?$/, sub {
    my $expected_elements_count = C->matches->[0];
    my @lines = S->{config_file}->all_lines;
    my $line = $lines[0];
    is($line->count_options, $expected_elements_count);
};

Then qr/^'([^']*)' should be part of the options list$/, sub {
    my $expected_option = C->matches->[0];
    my @lines = S->{config_file}->all_lines;
    my $line = $lines[0];
    is($line->grep_options(sub { $_ eq $expected_option }), 1);
};

Then qr{^the list of configuration atoms should contain (\d+) elements$}, sub {
    my $expected = C->matches->[0];
    is(scalar(S->{configuration}->all_atoms), $expected);
};

Then qr{^the list of displayed settings should contain (\d+) elements$}, sub {
    my $expected = C->matches->[0];
    is(scalar(S->{configure}->all_settings), $expected);
};

Then qr{^there should be (\d+) enabled configuration lines?$}, sub {
    my $expected = C->matches->[0];
    is(S->{configuration}->all_enabled_lines, $expected);
};

Then qr{^I should have a defined Step::Configure object$}, sub {
    my $configure = S->{configure};
    ok(defined($configure));
};

Then qr{^there should be (\d+) active setting[s]?$}, sub {
    my $expected = C->matches->[0];
    my $nb_active_settings = grep { $_->is_active } S->{configure}->all_settings;
    is($nb_active_settings, $expected);
};

Then qr{^there should be (\d+) setting[s]? with a configuration button$}, sub {
    my $expected = C->matches->[0];
    my $nb_config_buttons = grep {
        $_->has_configuration_button
    } S->{configure}->all_settings;
    is($nb_config_buttons, $expected);
};

Then qr{^every active setting's atoms should be enabled$}, sub {
    my @active_settings = grep { $_->is_active } S->{configure}->all_settings;
    ok(all {
        my $active_setting = $_;
        all { $_->enabled } @{$active_setting->atoms};
    } @active_settings);
};

Then qr{^every inactive setting's atoms should be disabled$}, sub {
    my @inactive_settings = grep { ! $_->is_active } S->{configure}->all_settings;
    ok(all {
        my $active_setting = $_;
        all { ! $_->enabled } @{$active_setting->atoms};
    } @inactive_settings);
};

Then qr{^the list box should have (\d+) child(?:ren)?(?: including separators)?$}, sub {
    my @children = S->{configure}->list_box->get_children;
    is(@children, C->matches->[0]);
};
