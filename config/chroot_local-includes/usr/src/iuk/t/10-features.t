#!/usr/bin/perl

use strictures 2;

use Test::More;

BEGIN {
    eval 'use Test::BDD::Cucumber::Loader';
    plan skip_all => 'Test::BDD::Cucumber::Loader required' if $@;
}

use Path::Tiny;
use Test::BDD::Cucumber::Loader;
use Test::BDD::Cucumber::Harness::TestBuilder;

for my $feature_dir (path('features')->children) {
    my ($executor, @features) = Test::BDD::Cucumber::Loader->load("$feature_dir");
    my $harness = Test::BDD::Cucumber::Harness::TestBuilder->new({});
    $executor->execute( $_, $harness ) for @features;
}
done_testing;
