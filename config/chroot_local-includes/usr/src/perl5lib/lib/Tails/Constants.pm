package Tails::Constants;

use 5.10.1;
use strictures 2;
use autodie qw(:all);

use Function::Parameters;

no Moo::sification;
use Moo;
use MooX::late;
use namespace::clean;

has 'system_partition_label' => (
    lazy_build => 1,
    is         => 'ro',
    isa        => 'Str',
);

method _build_system_partition_label () { 'Tails' }

no Moo;
1; # End of Tails::Constants
