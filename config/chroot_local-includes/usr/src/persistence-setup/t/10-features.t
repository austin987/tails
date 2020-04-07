#!/usr/bin/perl

use 5.10.1;
use strictures 2;

use Test::More;

BEGIN {
    eval 'use Test::BDD::Cucumber::Loader';
    plan skip_all => 'Test::BDD::Cucumber::Loader required' if $@;
}

use Test::BDD::Cucumber::Loader;
use Test::BDD::Cucumber::Harness::TestBuilder;

my ($executor, @features) = Test::BDD::Cucumber::Loader->load('features/');
my $harness = Test::BDD::Cucumber::Harness::TestBuilder->new({});
$executor->execute( $_, $harness ) for @features;
done_testing;
