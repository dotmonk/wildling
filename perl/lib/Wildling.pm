package Wildling;

use strict;
use warnings;

use Wildling::Generator;

our $VERSION = '1.0.0';

# Sentinel for out-of-range get() / exhausted next(). Stringifies to "false".
{
    package Wildling::FalseValue;
    use overload
      '""'     => sub {'false'},
      'bool'   => sub {0},
      'eq'     => sub { $_[1] eq 'false' || ( ref( $_[1] ) && $_[1]->isa('Wildling::FalseValue') ) },
      'ne'     => sub { !( $_[0] eq $_[1] ) },
      fallback => 1;
}

our $FALSE = bless {}, 'Wildling::FalseValue';

sub is_false {
    my ($value) = @_;
    return defined($value) && ref($value) && $value->isa('Wildling::FalseValue');
}

sub create {
    my ( $patterns, $dictionaries ) = @_;
    return Wildling::Client->new( $patterns, $dictionaries );
}

package Wildling::Client;

use strict;
use warnings;

sub new {
    my ( $class, $patterns, $dictionaries ) = @_;
    $dictionaries ||= {};
    $patterns     ||= [];

    my @generators =
      map { Wildling::Generator->new( $_, $dictionaries ) } @$patterns;
    my $pattern_count = 0;
    $pattern_count += $_->count() for @generators;

    return bless {
        dictionaries   => $dictionaries,
        generators     => \@generators,
        pattern_count  => $pattern_count,
        internal_index => 0,
    }, $class;
}

sub index {
    my ($self) = @_;
    return $self->{internal_index};
}

sub count {
    my ($self) = @_;
    return $self->{pattern_count};
}

sub reset {
    my ($self) = @_;
    $self->{internal_index} = 0;
    return;
}

sub next {
    my ($self) = @_;
    return $Wildling::FALSE if $self->{internal_index} == $self->{pattern_count};
    $self->{internal_index} += 1;
    return $self->get( $self->{internal_index} - 1 );
}

sub generators {
    my ($self) = @_;
    return $self->{generators};
}

sub get {
    my ( $self, $index ) = @_;
    return $Wildling::FALSE
      if $index > $self->{pattern_count} - 1 || $index < 0;

    my $segment_index = 0;
    for my $generator ( @{ $self->{generators} } ) {
        my $pattern_index = $index - $segment_index;
        return $generator->get($pattern_index)
          if $pattern_index < $generator->count();
        $segment_index += $generator->count();
    }
    return $Wildling::FALSE;
}

1;
