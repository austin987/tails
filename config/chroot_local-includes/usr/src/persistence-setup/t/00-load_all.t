use Test::Most;

use 5.10.1;
use strictures 2;

use Module::Pluggable::Object;
eval { require Win32; };

# libs
my @needsX = qw{Tails::Persistence::Bootstrap};
my $finder = Module::Pluggable::Object->new(
    search_path => [ 'Tails::Persistence' ],
);
foreach my $class (grep !/\.ToDo/,
                   sort do { local @INC = ('lib'); $finder->plugins }) {
  if (grep { $_ eq $class } @needsX) {
      next unless defined($ENV{DISPLAY}) && length($ENV{DISPLAY});
  }
  use_ok($class);
}

done_testing();
