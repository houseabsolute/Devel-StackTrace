use strict;
use warnings;

use Test::More;
use Test::Pod::Coverage 1.04;

my @modules = all_modules();
plan tests => scalar @modules;

my %trustme = (
    'Devel::StackTrace::Frame' => [qw( new as_string )],
);

for my $module ( sort @modules ) {
    my $trustme = [];
    if ( $trustme{$module} ) {
        my $methods = join '|', @{ $trustme{$module} };
        $trustme = [qr/^(?:$methods)$/];
    }

    pod_coverage_ok(
        $module, { trustme => $trustme },
        "Pod coverage for $module"
    );
}
