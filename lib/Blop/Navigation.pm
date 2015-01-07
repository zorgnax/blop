package Blop::Navigation;
use strict;
use warnings;
use Blop;
use URI;
use POSIX ();

sub new {
    my ($class, $limit, $offset, $rows, $what, $plural, $prev_str, $next_str) = @_;
    my $self = bless {}, $class;
    $self->{what} = $what || "result";
    $self->{plural} = $plural || $self->{what} . "s";
    $self->{prev_str} = $prev_str || "prev";
    $self->{next_str} = $next_str || "next";
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
    $out .= "<a href=\"" . $self->prev . "\">$self->{prev_str}</a>\n" if $self->prev;
    my $links = $self->window(7, 1);
    for my $link (@$links) {
        if ($link->{dots}) {
            $out .= " ... ";
        }
        if ($link->{selected}) {
            $out .= "<b>$link->{page}</b>\n";
        }
        else {
            $out .= "<a href=\"$link->{url}\">$link->{page}</a>\n";
        }
    }
    $out .= "<a href=\"" . $self->next . "\">$self->{next_str}</a>\n" if $self->next;
    return $out;
}

sub window {
    my ($self, $window, $edge) = @_;
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
    if ($edge && $min > 1) {
        for (1 .. $edge) {
            last if $_ == $min;
            my $offset = ($_ - 1) * $self->{limit};
            my $url = $self->url($offset);
            push @links, {page => $_, url => $url};
        }
    }
    for ($min .. $max) {
        my $offset = ($_ - 1) * $self->{limit};
        my $url = $self->url($offset);
        my $selected = $_ == $self->{page};
        my $link = {page => $_, url => $url, selected => $selected};
        if ($edge && $_ == $min && $_ > $edge + 1) {
            $link->{dots} = 1;
        }
        push @links, $link;
    }
    if ($edge && $max < $self->{pages}) {
        for ($self->{pages} - $edge + 1 .. $self->{pages}) {
            next if $_ <= $max;
            my $offset = ($_ - 1) * $self->{limit};
            my $url = $self->url($offset);
            my $link = {page => $_, url => $url};
            if ($_ == $self->{pages} - $edge + 1 && $_ > $max + 1) {
                $link->{dots} = 1;
            }
            push @links, $link;
        }
    }
    return \@links;
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

