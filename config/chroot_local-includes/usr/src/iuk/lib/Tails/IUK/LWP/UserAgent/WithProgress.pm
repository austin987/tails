=head1 NAME

Tails::IUK::LWP::UserAgent::WithProgress - LWP::UserAgent subclass that displays progress information

=cut

package Tails::IUK::LWP::UserAgent::WithProgress;

use 5.10.1;
use strictures 2;
use autodie qw(:all);
use Carp::Assert;

use parent 'LWP::UserAgent';

sub new {
    my $class = shift;
    my $args  = shift;
    assert('HASH' eq ref $args);

    my $self = $class->SUPER::new(@_);
    while (my ($k, $v) = each(%{$args})) { $self->{$k} = $v; }
    bless($self, $class);

    return $self;
}

sub progress {
    # When $status is "begin", $request_or_response is the
    # HTTP::Request object, otherwise it is the HTTP::Response object.
    my($self, $status, $request_or_response) = @_;

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
