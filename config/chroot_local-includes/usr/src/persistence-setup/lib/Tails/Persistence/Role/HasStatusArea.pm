=head1 NAME

Tails::Persistence::Role::HasStatusArea - status area interface

=cut

package Tails::Persistence::Role::HasStatusArea;
use 5.10.1;
use strictures 2;
use Moo::Role;

requires 'status_area';
requires 'working';

use namespace::clean;

no Moo::Role;
1;
