# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..19\n"; }
END {print "not ok 1\n" unless $main::loaded;}
use Devel::StackTrace;
use strict;

$^W = 1;
$main::loaded = 1;

result( $main::loaded, "Unable to load Devel::StackTrace module\n");

# 2-10 - Test all accessors
{
    my $trace = foo();

    my @f = ();
    while ( my $f = $trace->prev_frame ) { push @f, $f; }

    my $cnt = scalar @f;
    result( $cnt == 4, "Trace should have 4 frames but it has $cnt\n" );

    @f = ();
    while ( my $f = $trace->next_frame ) { push @f, $f; }

    $cnt = scalar @f;
    result( $cnt == 4, "Trace should have 4 frames but it has $cnt\n" );

    result( $f[0]->package eq 'main', "First frame package should be main but it's ",
	    $f[0]->package, "\n" );

    result( $f[0]->filename eq 'test.pl', "First frame package should be test.pl but it's ",
	    $f[0]->filename, "\n" );

    result( $f[0]->line == 1012, "First frame line should be 1012 but it's ",
	    $f[0]->line, "\n" );

    result( $f[0]->subroutine eq 'Devel::StackTrace::new', "First frame subroutine should be Devel::StackTrace::new but it's ",
	    $f[0]->subroutine, "\n" );

    result( $f[0]->hasargs == 1, "First frame hasargs should be true but it's not\n" );

    result( $f[0]->wantarray == 0, "First frame wantarray should be false but it's not\n" );

    my $trace_text = <<'EOF';
Trace begun at test.pl line 1012
main::baz(1, 2) called at test.pl line 1007
main::bar(1) called at test.pl line 1002
main::foo at test.pl line 21
EOF

    result( $trace->as_string eq $trace_text,
	    "Trace should be:\n$trace_text but it's\n", $trace->as_string );
}

# 11-14 - Test constructor params
{
    my $trace = SubTest::foo( ignore_class => 'Test' );

    my @f = ();
    while ( my $f = $trace->prev_frame ) { push @f, $f; }

    my $cnt = scalar @f;

    result( $cnt == 1, "Trace should have 1 frames but it has $cnt\n" );
    result( $f[0]->package eq 'main',
	    "The package for this frame should be main but it's ", $f[0]->package, "\n" );

    $trace = Test::foo( ignore_class => 'Test' );

    @f = ();
    while ( my $f = $trace->prev_frame ) { push @f, $f; }

    $cnt = scalar @f;

    result( $cnt == 1, "Trace should have 1 frames but it has $cnt\n" );
    result( $f[0]->package eq 'main',
	    "The package for this frame should be main but it's ", $f[0]->package, "\n" );
}

# 15 - stringification overloading
{
    my $trace = baz();

    my $trace_text = <<'EOF';
Trace begun at test.pl line 1012
main::baz at test.pl line 89
EOF

    my $t = "$trace";
    result( $t eq $trace_text,
	    "Trace should be:\n$trace_text but it's\n", $trace->as_string );
}

# 16-18 - frame_count, frame, reset_pointer, frames methods
{
    my $trace = foo();

    result( $trace->frame_count == 4,
	    "Trace should have 4 frames but it has ", $trace->frame_count, "\n" );

    my $f = $trace->frame(2);

    result( $f->subroutine eq 'main::bar',
	    "Frame 2's subroutine should be 'main::bar' but it's ", $f->subroutine, "\n" );

    $trace->next_frame; $trace->next_frame;
    $trace->reset_pointer;

    my $f = $trace->next_frame;
    result( $f->subroutine eq 'Devel::StackTrace::new',
	    "next_frame should return first frame after call to reset_pointer\n" );

    my @f = $trace->frames;
    result( ( scalar @f == 4 ) &&
	    ( $f[0]->subroutine eq 'Devel::StackTrace::new' ) &&
	    ( $f[3]->subroutine eq 'main::foo' ),
	    "frames method returned the wrong frames\n" );
}

sub result
{
    my $ok = !!shift;
    use vars qw($TESTNUM);
    $TESTNUM++;
    print "not "x!$ok, "ok $TESTNUM\n";
    print @_ if !$ok;
}

# This means I can move these lines down without constantly fiddling
# with the checks for line numbers in the tests.

#line 1000
sub foo
{
    bar(@_, 1);
}

sub bar
{
    baz(@_, 2);
}

sub baz
{
    Devel::StackTrace->new( @_ ? @_[0,1] : () );
}

package Test;

sub foo
{
    trace(@_);
}

sub trace
{
    Devel::StackTrace->new(@_);
}

package SubTest;

use base qw(Test);

sub foo
{
    trace(@_);
}

sub trace
{
    Devel::StackTrace->new(@_);
}

