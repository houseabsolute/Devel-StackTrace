package StackTrace;

use strict;
use vars qw($VERSION);

use fields qw( index frames );

use overload
    '""' => \&as_string,
    fallback => 1;

$VERSION = '0.02';

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
    $i_class{$p} = 1;

    my $x = 0;
    my @c;
    while ( do { package DB; @c = caller($x++) } )
    {
	# Do the quickest ones first.
	next if ( exists $p{ignore_package} &&
		  $i_pack{ $c[0] } );
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
	    if ($self->require)
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
	if ( @{ $self->{args} } )
	{
	    for (@{ $self->{args} })
	    {
		# set args to the string "undef" if undefined
		$_ = "undef", next unless defined $_;
		if (ref $_)
		{
		    # dunno what this is for...
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
	    $sub .= '(' . join(', ', @{ $self->{args} }) . ')';
	    $sub .= ' called';
	}
    }

    return "$sub at " . $self->filename . ' line ' . $self->line;
}

__END__

=head1 NAME

StackTrace - Perl extension for blah blah blah

=head1 SYNOPSIS

  use StackTrace;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for StackTrace was created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head1 AUTHOR

A. U. Thor, a.u.thor@a.galaxy.far.far.away

=head1 SEE ALSO

perl(1).

=cut
