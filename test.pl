use strict;

use Test::More;

BEGIN
{
    my $tests = 27;
    eval { require Exception::Class };
    $tests++ if ! $@ && $Exception::Class::VERSION >= 1.09;

    plan tests => $tests;

    use_ok('Devel::StackTrace');
}

# Test all accessors
{
    my $trace = foo();

    my @f = ();
    while ( my $f = $trace->prev_frame ) { push @f, $f; }

    my $cnt = scalar @f;
    is( $cnt, 4,
        "Trace should have 4 frames" );

    @f = ();
    while ( my $f = $trace->next_frame ) { push @f, $f; }

    $cnt = scalar @f;
    is( $cnt, 4,
        "Trace should have 4 frames" );

    is( $f[0]->package, 'main',
        "First frame package should be main" );

    is( $f[0]->filename, 'test.pl', "First frame filename should be test.pl" );

    is( $f[0]->line, 1012, "First frame line should be 1012" );

    is( $f[0]->subroutine, 'Devel::StackTrace::new',
        "First frame subroutine should be Devel::StackTrace::new" );

    is( $f[0]->hasargs, 1, "First frame hasargs should be true" );

    is( $f[0]->wantarray, 0,
        "First frame wantarray should be false" );

    my $trace_text = <<'EOF';
Trace begun at test.pl line 1012
main::baz(1, 2) called at test.pl line 1007
main::bar(1) called at test.pl line 1002
main::foo at test.pl line 18
EOF

    is( $trace->as_string, $trace_text, 'trace text' );
}

# Test constructor params
{
    my $trace = SubTest::foo( ignore_class => 'Test' );

    my @f = ();
    while ( my $f = $trace->prev_frame ) { push @f, $f; }

    my $cnt = scalar @f;

    is( $cnt, 1, "Trace should have 1 frame" );

    is( $f[0]->package, 'main',
        "The package for this frame should be main" );

    $trace = Test::foo( ignore_class => 'Test' );

    @f = ();
    while ( my $f = $trace->prev_frame ) { push @f, $f; }

    $cnt = scalar @f;

    is( $cnt, 1, "Trace should have 1 frame" );
    is( $f[0]->package, 'main',
        "The package for this frame should be main" );
}

# 15 - stringification overloading
{
    my $trace = baz();

    my $trace_text = <<'EOF';
Trace begun at test.pl line 1012
main::baz at test.pl line 87
EOF

    my $t = "$trace";
    is( $t, $trace_text, 'trace text' );
}

# 16-18 - frame_count, frame, reset_pointer, frames methods
{
    my $trace = foo();

    is( $trace->frame_count, 4,
        "Trace should have 4 frames" );

    my $f = $trace->frame(2);

    is( $f->subroutine, 'main::bar',
        "Frame 2's subroutine should be 'main::bar'" );

    $trace->next_frame; $trace->next_frame;
    $trace->reset_pointer;

    my $f = $trace->next_frame;
    is( $f->subroutine, 'Devel::StackTrace::new',
        "next_frame should return first frame after call to reset_pointer" );

    my @f = $trace->frames;
    is( scalar @f, 4,
        "frames method should return four frames" );

    is( $f[0]->subroutine, 'Devel::StackTrace::new',
        "first frame's subroutine should be Devel::StackTrace::new" );

    is( $f[3]->subroutine, 'main::foo',
        "last frame's subroutine should be main::foo" );
}

# Storing references
{
    my $obj = RefTest->new;

    my $trace = $obj->{trace};

    my $call_to_trace = ($trace->frames)[1];

    my @args = $call_to_trace->args;

    is( scalar @args, 1,
        "Only one argument should have been passed in the call to trace()" );

    isa_ok( $args[0], 'RefTest' );
}

# Not storing references
{
    my $obj = RefTest2->new;

    my $trace = $obj->{trace};

    my $call_to_trace = ($trace->frames)[1];

    my @args = $call_to_trace->args;

    is( scalar @args, 1,
        "Only one argument should have been passed in the call to trace()" );

    like( $args[0], qr/RefTest2=HASH/,
        "Actual object should be replaced by string 'RefTest2=HASH'" );
}

# Not storing references (deprecated interface)
{
    my $obj = RefTest3->new;

    my $trace = $obj->{trace};

    my $call_to_trace = ($trace->frames)[1];

    my @args = $call_to_trace->args;

    is( scalar @args, 1,
        "Only one argument should have been passed in the call to trace()" );

    like( $args[0], qr/RefTest3=HASH/,
        "Actual object should be replaced by string 'RefTest3=HASH'" );
}

# No ref to Exception::Class::Base object without refs
if ( $Exception::Class::VERSION >= 1.09 )
{
    eval { Exception::Class::Base->throw( error => 'error',
                                          show_trace => 1,
                                        ) };
    my $exc = $@;
    eval { quux($exc) };

    ok( ! $@, 'create stacktrace with no refs and exception object on stack' );
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

sub quux
{
    Devel::StackTrace->new( no_refs => 1 );
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

package RefTest;

sub new
{
    my $self = bless {}, shift;

    $self->{trace} = trace($self);

    return $self;
}

sub trace
{
    Devel::StackTrace->new();
}

package RefTest2;

sub new
{
    my $self = bless {}, shift;

    $self->{trace} = trace($self);

    return $self;
}

sub trace
{
    Devel::StackTrace->new( no_refs => 1 );
}

package RefTest3;

sub new
{
    my $self = bless {}, shift;

    $self->{trace} = trace($self);

    return $self;
}

sub trace
{
    Devel::StackTrace->new( no_object_refs => 1 );
}
