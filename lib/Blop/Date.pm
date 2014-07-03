package Blop::Date;
use strict;
use warnings;
use POSIX ();

sub new {
    my ($class, $str) = @_;
    $str =~ /^(\d{4})(-(\d+)(-(\d+)((\s+|T)(\d+)(:(\d+)(:(\d+)(\.(\d+))?)?)?)?)?)?(.*)$/;
    my $year = $1;
    my $month = $3 || 1;
    my $day = $5 || 1;
    my $hour = $8 || 0;
    my $minute = $10 || 0;
    my $second = $12 || 0;
    my $millisecond = $14 || 0;
    my $ampm = $15;
    return undef if !defined $year;
    if ($ampm =~ /^\s*am?$/i) {
        $hour -= 12 if $hour == 12;
    }
    elsif ($ampm =~ /^\s*pm?$/i) {
        $hour += 12 if $hour != 12;
    }
    elsif ($ampm !~ /^\s*$/) {
        return undef;
    }
    $month -= 1;
    $year -= 1900;
    my $epoch = POSIX::mktime($second, $minute, $hour, $day, $month, $year);
    return undef if !defined $epoch;
    my $self = bless {epoch => $epoch}, $class;
    return $self;
}

sub now {
    my ($class) = @_;
    my $self = bless {epoch => time}, $class;
    return $self;
}

sub str {
    my ($self) = @_;
    my $str = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime($self->{epoch}));
    return $str;
}

1;

