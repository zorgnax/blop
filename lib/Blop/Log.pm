package Blop::Log;
use strict;
use warnings;
use Blop;

sub date {
    my ($self) = @_;
    return $self->{date} if ref $self->{date};
    return undef if !$self->{date};
    $self->{date} = Blop::Date->new($self->{date});
    return $self->{date};
}

1;

