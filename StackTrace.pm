package StackTrace;

use strict;
use vars qw($VERSION);

use fields qw( index frames );

use overload
    '""' => \&as_string,
    fallback => 1;

$VERSION = '0.51';

1;

sub new
{
    my $proto = shift;
    my $class = ref $proto || $proto;

    my $self;
    {
	no strict 'refs';
	$self = bless [ \%{"${class}::FIELDS"} ], $class;
    }

    $self->{index} = undef;
    $self->{frames} = [];
    $self->_add_frames(@_);

    return $self;
}

sub _add_frames
{
    my StackTrace $self = shift;
    my %p = @_;

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
	next if ( grep { $c[0]->isa($_) } keys %i_class );

	# eval and is_require are only returned when applicable.
	push @c, (undef, undef) if scalar @c == 6;

	my @a = @DB::args;
	push @{ $self->{frames} }, StackTraceFrame->new(@c, \@a);
    }
}

sub next_frame
{
    my StackTrace $self = shift;

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
    my StackTrace $self = shift;

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

sub as_string
{
    my StackTrace $self = shift;

    my $st = '';
    my $first = 1;
    foreach my $f (@{ $self->{frames} })
    {
	$st .= $f->as_string($first) . "\n";
	$first = 0;
    }

    return $st;
}

package StackTraceFrame;

use strict;
use vars qw($VERSION);

use fields qw( package filename line subroutine hasargs wantarray evaltext is_require args );

$VERSION = '0.01';

# Create accessor routines
{
    no strict 'refs';
    foreach my $f (keys %{__PACKAGE__.'::FIELDS'})
    {
	next if $f eq 'args';
	*{$f} = sub { my StackTraceFrame $s = shift; return $s->{$f} };
    }
}

1;

sub new
{
    my $proto = shift;
    my $class = ref $proto || $proto;

    my $self;
    {
	no strict 'refs';
	$self = bless [ \%{"${class}::FIELDS"} ], $class;
    }

    @{ $self }{ qw( package filename line subroutine hasargs wantarray evaltext is_require args ) } = @_;

    return $self;
}

sub args
{
    my StackTraceFrame $self = shift;

    return @{ $self->{args} };
}

sub as_string
{
    my StackTraceFrame $self = shift;
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
	if ( my @a = @{ $self->{args} } )
	{
	    for (@a)
	    {
		# set args to the string "undef" if undefined
		$_ = "undef", next unless defined $_;
		if (ref $_)
		{
		    # dunno what this is for... (I bet it's to force a
		    # stringification if available -dave)
		    $_ .= '';
		}

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

StackTrace - Stack trace and stack trace frame objects

=head1 SYNOPSIS

  use StackTrace;

  my $trace = StackTrace->new;

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

The StackTrace module contains two classes, StackTrace and
StackTraceFrame.  The goal of this object is to encapsulate the
information that can found through using the caller() function, as
well as providing a simple interface to this data.

The StackTrace object contains a set of StackTraceFrame objects, one
for each level of the stack.  The frames contain all the data
available from caller() as of Perl 5.00503.  There are changes in Perl
5.6.0 that have yet to be incorporated.

This code was created to support my L<Exception> class but may be
useful in other contexts.

=head1 StackTrace METHODS

=over 4

=item * new(%named_params)

Returns a new StackTrace object.

Allowed params are

=item -- ignore_package => $package_name OR \@package_names

Any frames where the package is one of these packages will not be on
the stack.

=item -- ignore_class => $package_name OR \@package_names

Any frames where the package is a subclass of one of these packages
(or is the same package) will not be on the stack.

StackTrace internally adds itself to the 'ignore_package' parameter,
meaning that the StackTrace package is B<ALWAYS> ignored.  However, if
you create a subclass of StackTrace it will not be ignored.

=item * next_frame

Returns the next StackTraceFrame object down on the stack.  If it
hasn't been called before it returns the first frame.  It returns
undef when it reaches the bottom of the stack and then resets its
pointer so the next call to next_frame or prev_frame will work
properly.

=item * prev_frame

Returns the next StackTraceFrame object up on the stack.  If it hasn't
been called before it returns the last frame.  It returns undef when
it reaches the top of the stack and then resets its pointer so the
next call to next_frame or prev_frame will work properly.

=item * as_string

Calls as_string on each frame from top to bottom, producing output
quite similar to the Carp module's cluck/confess methods.

=back

=head1 StackTraceFrame METHODS

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
that are references are returned without copying them.

=head1 AUTHOR

Dave Rolsky, <autarch@urth.org>

=head1 SEE ALSO

Exception

=cut
