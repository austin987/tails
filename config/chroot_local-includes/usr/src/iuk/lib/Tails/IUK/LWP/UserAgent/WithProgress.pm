=head1 NAME

Tails::IUK::LWP::UserAgent::WithProgress - LWP::UserAgent subclass that displays progress information

=cut

package Tails::IUK::LWP::UserAgent::WithProgress;

use 5.10.1;
use strictures 2;
use autodie qw(:all);

use parent 'LWP::UserAgent';

sub progress {
    my($self, $status, $m) = @_;

    if ($status eq "begin") {
        say "0";
    }
    elsif ($status eq "end") {
        1; # "end" doesn't mean success, so don't display 100 here
    }
    elsif ($status eq "tick") {
        1; # the fraction can't be calculated
    }
    else {
        say $status * 100;
    }
    STDOUT->flush;
}

1;
