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
    if ($self->{page} != 1) {
        my $url = $self->url(0);        
        $out .= "<a href=\"$url\">First</a>\n";
        $url = $self->url($self->{offset} - $self->{limit});        
        $out .= "<a href=\"$url\">Previous</a>\n";
    }
    my @links;
    my $win = 7;
    my $min = $self->{page} - int $win / 2;
    $min = 1 if $min < 1;
    my $max = $min + $win - 1;
    $max = $self->{pages} if $max > $self->{pages};
    for ($min .. $max) {
        my $offset = ($_ - 1) * $self->{limit};
        my $url = $self->url($offset);
        my $link = $_ == $self->{page} ? "<b>$_</b>\n" : "<a href=\"$url\">$_</a>\n";
        push @links, $link;
    }
    if (@links > 1) {
        $out .= "@links";
    }
    if ($self->{page} != $self->{pages}) {
        my $url = $self->url($self->{offset} + $self->{limit});
        $out .= "<a href=\"$url\">Next</a>\n";
        $url = $self->url(int(($self->{pages} - 1) * $self->{limit}));
        $out .= "<a href=\"$url\">Last</a>\n";
    }
    return $out;
}

sub url {
    my ($self, $offset) = @_;
    my $url = URI->new($ENV{REQUEST_URI});
    my %params = ($url->query_form, offset => $offset);
    $url->query_form(%params);
    return $url;
}

1;

