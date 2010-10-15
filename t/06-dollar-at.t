use strict;
use warnings;

use Test::More;

use Devel::StackTrace;

$@ = my $msg = "Don't tread on me";

Devel::StackTrace->new->frame(0)->as_string;

is( $@, $msg, '$@ is not overwritten in as_string() method' );

done_testing();
