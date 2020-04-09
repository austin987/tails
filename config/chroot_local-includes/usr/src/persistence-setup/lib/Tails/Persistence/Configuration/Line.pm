=head1 NAME

Tails::Persistence::Configuration::Line - read, parse and write live-persistence.conf lines

=cut

package Tails::Persistence::Configuration::Line;
use 5.10.1;
use strictures 2;
use Moo;
with 'Tails::Persistence::Role::ConfigurationLine';

use namespace::clean;

no Moo;
1;
