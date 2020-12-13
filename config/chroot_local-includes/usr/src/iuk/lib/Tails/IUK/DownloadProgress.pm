=head1 NAME

Tails::IUK::DownloadProgress - keeps tracks information of a download in progress 

=cut

package Tails::IUK::DownloadProgress;

no Moo::sification;
use Moo;

use 5.10.1;
use strictures 2;

use autodie qw(:all);
use Types::Standard qw{Num Str HashRef};
use Time::HiRes;
use Time::Duration;
use Function::Parameters;
use Locale::TextDomain 'tails';

use namespace::clean;

has 'size' => (
    is        => 'ro',
    isa       => Num,
    required  => 1,
    
);

has 'size_left' => (
    is       => 'rw',
    isa      => Num,
    lazy     => 1,
    init_arg => 'size',
);

has "$_" => (
    is       => 'rw',
    isa      => Num,
    default  => 0,
    init_arg => undef,
    
) for (qw{speed last_bytes_downloaded last_progress_time});

has 'update_interval_time' => (
    is => 'ro',
    isa => Num,
    default => 0.4,
    documentation => q{Default update value, based on Doherty Threshold} 
   
);

has 'estimated_end_time' => (
    is => 'rw',
    isa => Str,
    lazy =>1 ,
    default => 'Unknow time',

);

has 'time_units' => (
    is          => 'lazy',
    isa     => HashRef[Str],
);

method _build_time_units () {
    my %time_units = (
        year   => __(q{y}),
        day    => __(q{d}),
        hour   => __(q{h}),
        minute => __(q{m}),
        second => __(q{s}),
        );
        
    return \%time_units;
}

# Based on the code in  DownloadCore.jsm in Tor Browser
method update (Num $downloaded_bytes) {
    my ($current_time) = Time::HiRes::gettimeofday();
    my $elapsed_time = $current_time - $self->last_progress_time;
    return unless ($elapsed_time >= $self->update_interval_time);

    $self->download_speed($downloaded_bytes,$elapsed_time);
    $self->size_left ($self->size - $downloaded_bytes);
    $self->set_estimated_end_time();
    $self->last_bytes_downloaded($downloaded_bytes);
    $self->last_progress_time($current_time);
       
}

method download_speed (Num $downloaded_bytes, Num $elapsed_time) {
    my $raw_speed = ($downloaded_bytes - $self->last_bytes_downloaded)/$elapsed_time;
    if ($self->speed == 0) {
        $self->speed($raw_speed);
    }
    else {
        # Apply exponential smoothing, with a smoothing factor of 0.1.
        $self->speed(($self->speed * 0.9) + ($raw_speed * 0.1));
    }
}

method set_estimated_end_time () {
    return  unless ($self->speed > 0); 
    my $timeleft =  $self->size_left / $self->speed;
    $timeleft = duration($timeleft);
    $timeleft =~ s/\band\b//;
    $timeleft =~ s/\b(year|day|hour|minute|second)s?\b/$self->time_units->{$1}/eg;
    $timeleft =~ s/(\d+)\s*/$1/g;
    $self->estimated_end_time($timeleft);
}

no Moo;
1;
