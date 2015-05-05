package Blop::Date;
use strict;
use warnings;
use POSIX ();

use overload '""' => \&str;

sub new {
    my ($class, $str) = @_;
    return undef if !$str;
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

sub new_epoch {
    my ($class, $epoch) = @_;
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

sub strftime {
    my ($self, $fmt) = @_;
    my $str = POSIX::strftime($fmt, localtime($self->{epoch}));
    return $str;
}

my $now;
sub natural {
    my ($self) = @_;
    $now = time if !$now;
    my $delta = $now - $self->{epoch};
    if ($delta < -32 * 24 * 60 * 60) {
        return POSIX::strftime("%b %Y", localtime($self->{epoch}));
    }
    elsif ($delta < -2 * 24 * 60 * 60) {
        return "in " . int(-$delta / (24 * 60 * 60)) . " days";
    }
    elsif ($delta < -24 * 60 * 60) {
        return "in 1 day";
    }
    elsif ($delta < -2 * 60 * 60) {
        return "in " . int(-$delta / (60 * 60)) . " hours";
    }
    elsif ($delta < -60 * 60) {
        return "in 1 hour";
    }
    elsif ($delta < -2 * 60) {
        return "in " . int(-$delta / 60) . " minutes";
    }
    elsif ($delta < -60) {
        return "in 1 minute";
    }
    elsif ($delta < -1) {
        return "in $delta seconds";
    }
    elsif ($delta < 0) {
        return "in 1 second";
    }
    elsif ($delta < 1) {
        return "right now";
    }
    elsif ($delta < 2) {
        return "1 second ago";
    }
    if ($delta < 60) {
        return "$delta seconds ago";
    }
    elsif ($delta < 2 * 60) {
        return "1 minute ago";
    }
    elsif ($delta < 60 * 60) {
        return int($delta / 60) . " minutes ago";
    }
    elsif ($delta < 2 * 60 * 60) {
        return "1 hour ago";
    }
    elsif ($delta < 24 * 60 * 60) {
        return int($delta / (60 * 60)) . " hours ago";
    }
    elsif ($delta < 2 * 24 * 60 * 60) {
        return "1 day ago";
    }
    elsif ($delta < 32 * 24 * 60 * 60) {
        return int($delta / (24 * 60 * 60)) . " days ago";
    }
    else {
        return POSIX::strftime("%b %Y", localtime($self->{epoch}));
    }
}

sub time_zones {
    my %time_zones;
    open my $fh, "<", "/usr/share/zoneinfo/zone.tab" or return [];
    while (my $line = <$fh>) {
        $line =~ m{^[A-Z]{2}\s+\S+\s+(\w+)/(\S+)} or next;
        my $region = $1;
        my $name = $2;
        my $zone = "$region/$name";
        $name =~ s{_}{ }g;
        $name =~ s{/}{ - }g;
        push @{$time_zones{$region}}, {zone => $zone, name => $name};
    }
    my @time_zones;
    push @time_zones, {name => "Local", zone => ""};
    for my $region (sort keys %time_zones) {
        my @zones = sort {$a->{name} cmp $b->{name}} @{$time_zones{$region}};
        push @time_zones, {region => $region, zones => \@zones};
    }
    my @zones;
    for my $offset (qw{
        -12 -11:30 -11 -10:30 -10 -9:30 -8:30 -8 -7:30 -7 -6:30 -6 -5:30
        -5 -4:30 -4 -3:30 -3 -2:30 -2 -1:30 -1 -0:30 +0 +0:30 +1 +1:30
        +2 +2:30 +3 +3:30 +4 +4:30 +5 +5:30 +6 +6:30 +7 +7:30 +8 +8:30
        +9 +9:30 +10 +10:30 +11 +11:30 +12}) {
        push @zones, {zone => "UTC$offset", name => "UTC$offset"};
    }
    push @time_zones, {region => "UTC", zones => \@zones};
    return \@time_zones;
}

1;

