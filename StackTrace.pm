package Devel::StackTrace;

use 5.005;

use strict;
use vars qw($VERSION);

use fields qw( index frames );

use overload
    '""' => \&as_string,
    fallback => 1;

$VERSION = '1.02';

1;

sub new
{
    my $proto = shift;
    my $class = ref $proto || $proto;

    my $self = bless { index => undef,
		       frames => [],
		     }, $class;

    $self->_add_frames(@_);

    return $self;
}

sub _add_frames
{
    my $self = shift;
    my %p = @_;

    $p{no_refs} = delete $p{no_object_refs} if exists $p{no_object_refs};

    my (%i_pack, %i_class);
    if ($p{ignore_package})
    {
	$p{ignore_package} = [$p{ignore_package}] unless ref $p{ignore_package};
	%i_pack = map {$_ => 1} @{ $p{ignore_package} };
    }

    if ($p{ignore_class})
    {
	$p{ignore_class} = [$p{ignore_class}] unless ref $p{ignore_class};
	%i_class = map {$_ => 1} @{ $p{ignore_class} };
    }
    # This _will_ cause all subclasses of this class to be ignored as
    # well.
    my $p = __PACKAGE__;
    $i_pack{$p} = 1;

    my $x = 0;
    my @c;
    while ( do { package DB; @c = caller($x++) } )
    {
	# Do the quickest ones first.
	next if $i_pack{ $c[0] };
	next if grep { $c[0]->isa($_) } keys %i_class;

	# eval and is_require are only returned when applicable under 5.00503.
	push @c, (undef, undef) if scalar @c == 6;

	my @a = @DB::args;

        if ( $p{no_refs} )
        {
            @a = map { ref $_ ? "$_" : $_ } @a;
        }

	push @{ $self->{frames} }, Devel::StackTraceFrame->new(\@c, \@a);
    }
}

sub next_frame
{
    my $self = shift;

    # reset to top if necessary.
    $self->{index} = -1 unless defined $self->{index};

    if (defined $self->{frames}[ $self->{index} + 1 ])
    {
	return $self->{frames}[ ++$self->{index} ];
    }
    else
    {
	$self->{index} = undef;
	return undef;
    }
}

sub prev_frame
{
    my $self = shift;

    # reset to top if necessary.
    $self->{index} = scalar @{ $self->{frames} } unless defined $self->{index};

    if (defined $self->{frames}[ $self->{index} - 1 ] && $self->{index} >= 1)
    {
	return $self->{frames}[ --$self->{index} ];
    }
    else
    {
	$self->{index} = undef;
	return undef;
    }
}

sub reset_pointer
{
    my $self = shift;

    $self->{index} = undef;
}

sub frames
{
    my $self = shift;

    return @{ $self->{frames} };
}

sub frame
{
    my $self = shift;
    my $i = shift;

    return unless defined $i;

    return $self->{frames}[$i];
}

sub frame_count
{
    my $self = shift;

    return scalar @{ $self->{frames} };
}

sub as_string
{
    my $self = shift;

    my $st = '';
    my $first = 1;
    foreach my $f (@{ $self->{frames} })
    {
	$st .= $f->as_string($first) . "\n";
	$first = 0;
    }

    return $st;
}

package Devel::StackTraceFrame;

use strict;
use vars qw($VERSION);

use fields qw( package filename line subroutine hasargs wantarray evaltext is_require hints bitmask args );

$VERSION = '0.6';

# Create accessor routines
BEGIN
{
    no strict 'refs';
    foreach my $f ( qw( package filename line subroutine hasargs
                        wantarray evaltext is_require hints bitmask args ) )
    {
	next if $f eq 'args';
	*{$f} = sub { my $s = shift; return $s->{$f} };
    }
}

1;

sub new
{
    my $proto = shift;
    my $class = ref $proto || $proto;

    my $self = bless {}, $class;

    my @fields =
        ( qw( package filename line subroutine hasargs wantarray evaltext is_require ) );
    push @fields, ( qw( hints bitmask ) ) if $] >= 5.006;

    @{ $self }{ @fields } = @{$_[0]};

    $self->{args} = $_[1] ? $_[1] : [];

    return $self;
}

sub args
{
    my $self = shift;

    return @{ $self->{args} };
}

sub as_string
{
    my $self = shift;
    my $first = shift;

    my $sub = $self->subroutine;
    # This code stolen straight from Carp.pm and then tweaked.  All
    # errors are probably my fault  -dave
    if ($first)
    {
	$sub = 'Trace begun';
    }
    else
    {
	# Build a string, $sub, which names the sub-routine called.
	# This may also be "require ...", "eval '...' or "eval {...}"
	if (my $eval = $self->evaltext)
	{
	    if ($self->is_require)
	    {
		$sub = "require $eval";
	    }
	    else
	    {
		$eval =~ s/([\\\'])/\\$1/g;
		$sub = "eval '$eval'";
	    }
	}
	elsif ($sub eq '(eval)')
	{
	    $sub = 'eval {...}';
	}

	# if there are any arguments in the sub-routine call, format
	# them according to the format variables defined earlier in
	# this file and join them onto the $sub sub-routine string
	#
	# We copy them because they're going to be modified.
	#
	if ( my @a = $self->args )
	{
	    for (@a)
	    {
		# set args to the string "undef" if undefined
		$_ = "undef", next unless defined $_;

		# force stringification
		$_ .= '' if ref $_;

		s/'/\\'/g;

		# 'quote' arg unless it looks like a number
		$_ = "'$_'" unless /^-?[\d.]+$/;

		# print high-end chars as 'M-<char>' or '^<char>'
		s/([\200-\377])/sprintf("M-%c",ord($1)&0177)/eg;
		s/([\0-\37\177])/sprintf("^%c",ord($1)^64)/eg;
	    }

	    # append ('all', 'the', 'arguments') to the $sub string
	    $sub .= '(' . join(', ', @a) . ')';
	    $sub .= ' called';
	}
    }

    return "$sub at " . $self->filename . ' line ' . $self->line;
}

__END__

=head1 NAME

Devel::StackTrace - Stack trace and stack trace frame objects

=head1 SYNOPSIS

  use Devel::StackTrace;

  my $trace = Devel::StackTrace->new;

  print $trace->as_string; # like carp

  # from top (most recent) of stack to bottom.
  while (my $frame = $trace->next_frame)
  {
      print "Has args\n" if $f->hasargs;
  }

  # from bottom (least recent) of stack to top.
  while (my $frame = $trace->prev_frame)
  {
      print "Sub: ", $f->subroutine, "\n";
  }

=head1 DESCRIPTION

The Devel::StackTrace module contains two classes, Devel::StackTrace
and Devel::StackTraceFrame.  The goal of this object is to encapsulate
the information that can found through using the caller() function, as
well as providing a simple interface to this data.

The Devel::StackTrace object contains a set of Devel::StackTraceFrame
objects, one for each level of the stack.  The frames contain all the
data available from caller() as of Perl 5.6.0 though this module still
works with 5.00503.

This code was created to support my L<Exception::Class::Base> class
(part of Exception::Class) but may be useful in other contexts.

=head1 'TOP' AND 'BOTTOM' OF THE STACK

When describing the methods of the trace object, I use the words 'top'
and 'bottom'.  In this context, the 'top' frame on the stack is the
most recent frame and the 'bottom' is the least recent.

Here's an example:

  foo();  # bottom frame is here

  sub foo
  {
     bar();
  }

  sub bar
  {
     Devel::StackTrace->new;  # top frame is here.
  }

=head1 Devel::StackTrace METHODS

=over 4

=item * new(%named_params)

Returns a new Devel::StackTrace object.

Takes the following parameters:

=item -- ignore_package => $package_name OR \@package_names

Any frames where the package is one of these packages will not be on
the stack.

=item -- ignore_class => $package_name OR \@package_names

Any frames where the package is a subclass of one of these packages
(or is the same package) will not be on the stack.

Devel::StackTrace internally adds itself to the 'ignore_package'
parameter, meaning that the Devel::StackTrace package is B<ALWAYS>
ignored.  However, if you create a subclass of Devel::StackTrace it
will not be ignored.

=item -- no_refs => $boolean

If this parameter is true, then Devel::StackTrace will not store
references internally when generating stacktrace frames.  This lets
your objects go out of scope.

Devel::StackTrace replaces any references with their stringified
representation.

=item * next_frame

Returns the next Devel::StackTraceFrame object down on the stack.  If
it hasn't been called before it returns the first frame.  It returns
undef when it reaches the bottom of the stack and then resets its
pointer so the next call to C<next_frame> or C<prev_frame> will work
properly.

=item * prev_frame

Returns the next Devel::StackTraceFrame object up on the stack.  If it
hasn't been called before it returns the last frame.  It returns undef
when it reaches the top of the stack and then resets its pointer so
pointer so the next call to C<next_frame> or C<prev_frame> will work
properly.

=item * reset_pointer

Resets the pointer so that the next call C<next_frame> or
C<prev_frame> will start at the top or bottom of the stack, as
appropriate.

=item * frames

Returns a list of Devel::StackTraceFrame objects.  The order they are
returned is from top (most recent) to bottom.

=item * frame ($index)

Given an index, returns the relevant frame or undef if there is not
frame at that index.  The index is exactly like a Perl array.  The
first frame is 0 and negative indexes are allowed.

=item * frame_count

Returns the number of frames in the trace object.

=item * as_string

Calls as_string on each frame from top to bottom, producing output
quite similar to the Carp module's cluck/confess methods.

=back

=head1 Devel::StackTraceFrame METHODS

See the L<caller> documentation for more information on what these
methods return.

=over 4

=item * package

=item * filename

=item * line

=item * subroutine

=item * hasargs

=item * wantarray

=item * evaltext

Returns undef if the frame was not part of an eval.

=item * is_require

Returns undef if the frame was not part of a require.

=item * args

Returns the arguments passed to the frame.  Note that any arguments
that are references are returned as references, not copies.

=head2 These only contain data as of Perl 5.6.0 or later

=item * hints

=item * bitmask

=head1 AUTHOR

Dave Rolsky, <autarch@urth.org>

=head1 SEE ALSO

Exception::Class

=cut
