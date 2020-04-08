=head1 NAME

Tails::Persistence::Role::ConfigurationLine - live-persistence.conf data structure

=cut

package Tails::Persistence::Role::ConfigurationLine;
use 5.10.1;
use strictures 2;
use autodie qw(:all);
use Carp;
use Function::Parameters;
use Types::Standard qw(ClassName Str);

use Moo::Role; # Moo::Role exports all methods declared after it's "use"'d
use MooX::late;
use MooX::HandlesVia;

use namespace::clean;


=head1 ATTRIBUTES

=cut

has 'destination' => (
    lazy_build => 1,
    is         => 'ro',
    isa        => 'Str',
);

has 'options' => (
    lazy_build        => 1,
    is                => 'ro',
    isa               => 'ArrayRef[Str]',
    handles_via       => 'Array',
    handles           => {
        count_options => 'count',
        all_options   => 'elements',
        join_options  => 'join',
        grep_options  => 'grep',
    }
);


=head1 CONSTRUCTORS

=cut

method _build_options () {
    return []
}


=head2 new_from_string

input: a line e.g. read from live-persistence.conf

output:
  - undef if that line can be safely ignored (e.g. comment)
  - a new Tails::Persistence::Configuration::Line object if "normal" line
  - throws exception on badly formatted line

=cut
method new_from_string (ClassName $class: Str $line) {
    chomp $line;

    # skip pure-whitespace lines
    return if $line =~ m{^[[:space:]]*$};
    # skip commented-out lines
    return if $line =~ m{^[[:space:]]*#};

    my ($destination, $options) = split /\s+/, $line;
    defined($destination) or croak "Unparseable line: $line";
    my @options = defined $options ? split(/,/, $options) : ();

    return Tails::Persistence::Configuration::Line->new(
        destination => $destination,
        options     => [ @options ],
    );
}


=head1 METHODS

=cut

=head2 stringify

Returns a in-memory configuration line,
as a string in the live-persistence.conf format,
with no trailing newline.

=cut
method stringify () {
    my $out = $self->destination;
    if ($self->count_options) {
        $out .= "\t" . $self->join_options(',');
    }
    return $out;
}

no Moo::Role;
1;
