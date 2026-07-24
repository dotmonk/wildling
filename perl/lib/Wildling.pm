package Wildling;

use strict;
use warnings;

use Wildling::Generator;

our $VERSION = '2.0.5';

# Out-of-range get() / exhausted next() return undef (not the string "false").
# Empty-string combinations are defined and distinct from the sentinel.
sub is_false {
    my ($value) = @_;
    return !defined($value);
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
    return if $self->{internal_index} == $self->{pattern_count};
    $self->{internal_index} += 1;
    return $self->get( $self->{internal_index} - 1 );
}

sub generators {
    my ($self) = @_;
    return $self->{generators};
}

sub get {
    my ( $self, $index ) = @_;
    return
      if $index > $self->{pattern_count} - 1 || $index < 0;

    my $segment_index = 0;
    for my $generator ( @{ $self->{generators} } ) {
        my $pattern_index = $index - $segment_index;
        return $generator->get($pattern_index)
          if $pattern_index < $generator->count();
        $segment_index += $generator->count();
    }
    return;
}

1;
