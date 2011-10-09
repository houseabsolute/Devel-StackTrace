package Devel::StackTrace::Frame;

use 5.008;

use strict;
use warnings;

use Any::Moose;
use Carp ();
use File::Spec;

has [qw( package filename subroutine )] => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has line => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

has has_args => (
    is       => 'ro',
    isa      => 'Bool',
    required => 1,
);

sub hasargs { goto &has_args }

has wantarray => (
    is       => 'ro',
    isa      => 'Bool',    # well, more of a Troolean
    required => 1,
);

has evaltext => (
    is       => 'ro',
    isa      => 'Maybe[Str]',
    required => 1,
);

has is_require => (
    is       => 'ro',
    isa      => 'Bool',
    required => 1,
);

has hints => (
    is       => 'ro',
    isa      => 'Defined',
    required => 1,
);

has bitmask => (
    is       => 'ro',
    isa      => 'Defined',
    required => 1,
);

if ( $] >= 5.010 ) {
    has hinthash => (
        is       => 'ro',
        isa      => 'Maybe[HashRef]',
        required => 1,
    );
}

has message => (
    is        => 'ro',
    isa       => 'Str',
    predicate => '_has_message',
);

has tid => (
    is        => 'ro',
    isa       => 'Str',
    predicate => '_has_tid',
);

has args => (
    is         => 'ro',
    isa        => 'ArrayRef',
    required   => 1,
    auto_deref => 1,
);

has max_args => (
    is  => 'ro',
    isa => 'Int',
);

has max_arg_length => (
    is  => 'ro',
    isa => 'Int',
);

has max_eval_length => (
    is  => 'ro',
    isa => 'Int',
);

has respect_overload => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has indent => (
    is      => 'ro',
    isa     => 'Bool',
    default => 1,
);

override BUILDARGS => sub {
    my $class = shift;

    my $p = super();

    $p->{filename} = File::Spec->canonpath( $p->{filename} );

    return $p;
};

sub as_string {
    my $self  = shift;
    my $first = shift;

    my $sub;

    # This code stolen straight from Carp.pm and then tweaked.  All
    # errors are probably my fault  -dave
    if ($first) {
        $sub
            = $self->_has_message()
            ? $self->message()
            : 'Trace begun';
    }
    else {
        $sub = $self->subroutine();

        # Build a string, $sub, which names the sub-routine called.
        # This may also be "require ...", "eval '...' or "eval {...}"
        if ( my $eval = $self->evaltext ) {
            if ( $self->is_require ) {
                $sub = "require $eval";
            }
            else {
                $eval =~ s/([\\\'])/\\$1/g;
                $sub = "eval '$eval'";
            }
        }
        elsif ( $sub eq '(eval)' ) {
            $sub = 'eval {...}';
        }

        # if there are any arguments in the sub-routine call, format
        # them according to the format variables defined earlier in
        # this file and join them onto the $sub sub-routine string
        #
        # We copy them because they're going to be modified.
        #
        if ( my @a = $self->args() ) {
            for (@a) {

                # set args to the string "undef" if undefined
                $_ = "undef", next unless defined $_;

                # hack!
                $_ = $self->Devel::StackTrace::_ref_to_string($_)
                    if ref $_;

                local $SIG{__DIE__};
                local $@;

                eval {
                    if ( $self->max_arg_length()
                        && length $_ > $self->max_arg_length() ) {
                        substr( $_, $self->max_arg_length() ) = '...';
                    }

                    s/'/\\'/g;

                    # 'quote' arg unless it looks like a number
                    $_ = "'$_'" unless /^-?[\d.]+$/;

                    # print non-printable ASCII chars as \x{0x01} - doesn't
                    # handle non-printable Unicode characters.
                    s/([\0-\37\177])/sprintf( "\\x{%x}", ord($1) )/eg;
                };

                if ( my $e = $@ ) {
                    $_ = $e =~ /malformed utf-8/i ? '(bad utf-8)' : '?';
                }
            }

            # append ('all', 'the', 'arguments') to the $sub string
            $sub .= '(' . join( ', ', @a ) . ')';
            $sub .= ' called';
        }
    }

    # If the user opted into indentation (a la Carp::confess), pre-add a tab
    my $tab = $self->indent() && !$first ? "\t" : q{};

    return "${tab}$sub at " . $self->filename() . ' line ' . $self->line();
}

1;

# ABSTRACT: A single frame in a stack trace

__END__

=head1 DESCRIPTION

See L<Devel::StackTrace> for details.

=head1 METHODS

See the L<caller> documentation for more information on what these
methods return.

=over 4

=item * $frame->package

=item * $frame->filename

=item * $frame->line

=item * $frame->subroutine

=item * $frame->has_args

=item * $frame->wantarray

=item * $frame->evaltext

Returns undef if the frame was not part of an eval.

=item * $frame->is_require

Returns undef if the frame was not part of a require.

=item * $frame->args

Returns the arguments passed to the frame.  Note that any arguments
that are references are returned as references, not copies.

=item * $frame->hints

=item * $frame->bitmask

=back
