package Blop::Navigation;
use strict;
use warnings;
use Blop;
use URI;
use POSIX ();

sub new {
    my ($class, $limit, $offset, $rows, $what, $plural) = @_;
    my $self = bless {}, $class;
    $self->{what} = $what || "result";
    $self->{plural} = $plural || $self->{what} . "s";
    $self->{rows} = $rows;
    $self->{limit} = $limit;
    $self->{offset} = $offset;
    $self->{end_offset} = $offset + $limit - 1;
    $self->{end_offset} = $rows - 1 if $self->{end_offset} >= $rows;
    $self->{row_min} = $offset + 1;
    $self->{row_max} = $self->{end_offset} + 1;
    $self->{pages} = POSIX::ceil($rows / $limit);
    $self->{page} = int($offset / $limit) + 1;
    return $self;
}

sub summary {
    my ($self) = @_;
    my $out = "$self->{rows} ";
    $out .= $self->{rows} == 1 ? $self->{what} : $self->{plural};
    if ($self->{pages} > 1) {
        $out = "$self->{row_min} - $self->{row_max} of $out";
    }
    return $out;
}

sub links {
    my ($self) = @_;
    return "" if !$self->{rows};
    my $out = "";
    $out .= "<a href=\"" . $self->first . "\">First</a>\n" if $self->first;
    $out .= "<a href=\"" . $self->prev . "\">Previous</a>\n" if $self->prev;
    my $links = $self->window(7);
    for my $link (@$links) {
        if ($link->{selected}) {
            $out .= "<b>$link->{page}</b>\n";
        }
        else {
            $out .= "<a href=\"$link->{url}\">$link->{page}</a>\n";
        }
    }
    $out .= "<a href=\"" . $self->next . "\">Next</a>\n" if $self->next;
    $out .= "<a href=\"" . $self->last . "\">Last</a>\n" if $self->last;
    return $out;
}

sub first {
    my ($self) = @_;
    return "" if $self->{page} == 1;
    return $self->url(0);
}

sub prev {
    my ($self) = @_;
    return "" if $self->{page} == 1;
    return $self->url($self->{offset} - $self->{limit});
}

sub window {
    my ($self, $window) = @_;
    my $min = $self->{page} - int $window / 2;
    $min = 1 if $min < 1;
    my $max = $min + $window - 1;
    $max = $self->{pages} if $max > $self->{pages};
    if ($max == $self->{pages}) {
        $min = $max - $window + 1;
        $min = 1 if $min < 1;
    }
    return [] if $max - $min < 1;
    my @links;
    for ($min .. $max) {
        my $offset = ($_ - 1) * $self->{limit};
        my $url = $self->url($offset);
        my $selected = $_ == $self->{page};
        push @links, {page => $_, url => $url, selected => $selected};
    }
    return \@links;
}

sub next {
    my ($self) = @_;
    return "" if $self->{page} == $self->{pages};
    return $self->url($self->{offset} + $self->{limit});
}

sub last {
    my ($self) = @_;
    return "" if $self->{page} == $self->{pages};
    return $self->url(int(($self->{pages} - 1) * $self->{limit}));
}

sub url {
    my ($self, $offset) = @_;
    my $url = URI->new($ENV{REQUEST_URI});
    my %params = ($url->query_form, offset => $offset);
    $url->query_form(%params);
    return $url;
}

1;

