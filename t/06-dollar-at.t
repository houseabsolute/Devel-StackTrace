use strict;
use warnings;

use Test::More;

use Devel::StackTrace;

{
    $@ = my $msg = q{Don't tread on me};

    Devel::StackTrace->new()->frame(0)->as_string();

    is( $@, $msg, '$@ is not overwritten in as_string() method' );
}

{
    $@ = my $msg = q{Don't tread on me};

    Devel::StackTrace->new( ignore_package => 'Foo' )->frames();

    is( $@, $msg, '$@ is not overwritten in _make_filter() method' );
}

done_testing();
