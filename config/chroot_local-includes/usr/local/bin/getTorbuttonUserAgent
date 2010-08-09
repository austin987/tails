#!/usr/bin/perl

use warnings;
use strict;
use 5.10.0;
use Fatal qw( open close );

sub getTorbuttonUserAgent {
    my $file = shift;

    my $ua;
    open (my $in, "<", $file);
    while (my $line = <$in>) {
        chomp $line;
        if (($ua) = ($line =~ m/^pref\("extensions\.torbutton\.useragent_override", "(.*)"\);$/)) {
            last;
        }
    }
    close $in;
    return $ua;
}

say getTorbuttonUserAgent('/usr/share/xul-ext/torbutton/defaults/preferences/preferences.js');
