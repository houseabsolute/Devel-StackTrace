# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..1\n"; }
END {print "not ok 1\n" unless $main::loaded;}
use StackTrace;
use strict;

$^W = 1;
$main::loaded = 1;

result( $main::loaded, "Unable to load StackTrace module\n");

# 2-10 Test all accessors
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

    result( $f[0]->line == 112, "First frame line should be 112 but it's ",
	    $f[0]->line, "\n" );

    result( $f[0]->subroutine eq 'StackTrace::new', "First frame subroutine should be StackTrace::new but it's ",
	    $f[0]->subroutine, "\n" );

    result( $f[0]->hasargs == 1, "First frame hasargs should be true but it's not\n" );

    result( $f[0]->wantarray == 0, "First frame wantarray should be false but it's not\n" );

    my $trace_text = <<'EOF';
Trace begun at test.pl line 112
main::baz(1, 2) called at test.pl line 107
main::bar(1) called at test.pl line 102
main::foo at test.pl line 21
EOF

    result( $trace->as_string eq $trace_text,
	    "Trace should be:\n$trace_text but it's\n", $trace->as_string );
}

# 11-14 Test constructor params
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

{
    my $trace = baz();

    my $trace_text = <<'EOF';
Trace begun at test.pl line 112
main::baz at test.pl line 88
EOF

    my $t = "$trace";
    result( $t eq $trace_text,
	    "Trace should be:\n$trace_text but it's\n", $trace->as_string );
}

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
    StackTrace->new( @_ ? @_[0,1] : () );
}

sub result
{
    my $ok = !!shift;
    use vars qw($TESTNUM);
    $TESTNUM++;
    print "not "x!$ok, "ok $TESTNUM\n";
    print @_ if !$ok;
}

package Test;

sub foo
{
    trace(@_);
}

sub trace
{
    StackTrace->new(@_);
}

package SubTest;

use base qw(Test);

sub foo
{
    trace(@_);
}

sub trace
{
    StackTrace->new(@_);
}

