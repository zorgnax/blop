package Blop::Visits;
use strict;
use warnings;
use Blop;
use Blop::Date;

sub visits {
    my $blop = Blop::instance();
    my $sth = $blop->dbh->prepare(<<EOSQL);
select
    min(date) min_date, max(date) max_date, count(*) as page_views,
    sum(first) unique_ips
from
    visits
EOSQL
    $sth->execute();
    my $visits = $sth->fetchrow_hashref();
    $visits->{page_views} ||= 0;
    $visits->{unique_ips} ||= 0;
    $visits->{min_date} = Blop::Date->new($visits->{min_date});
    $visits->{max_date} = Blop::Date->new($visits->{max_date});

    my $max = Blop::Date->new_epoch(time);
    my $min = $visits->{min_date} || $max;
    if ($min->{epoch} > $max->{epoch} - 60 * 60 * 3) {
        $min = Blop::Date->new_epoch($max->{epoch} - 60 * 60 * 3);
    }
    my $n = 20;
    my $segment = ($max->{epoch} - $min->{epoch}) / $n;

    my $query = <<EOSQL;
select
    floor((unix_timestamp(date) - unix_timestamp("$min")) / $segment) + 1 i,
    count(*) count,
    count(distinct ipaddr) ip_count
from
    visits
group
    by i
EOSQL
    $sth = $blop->dbh->prepare($query);
    $sth->execute();
    my %h;
    while (my $visit = $sth->fetchrow_hashref()) {
        $h{$visit->{i}} = $visit;
    }

    my $n_labels = 6;
    my $labels_every = int($n / $n_labels);

    my @list;
    my @labels;
    my @counts;
    my @ip_counts;
    for my $i (0 .. $n) {
        my $visit = $h{$i} || {i => $i};
        my $time = $min->{epoch} + ($i - 1) * $segment;
        my $date = Blop::Date->new_epoch($time);
        $visit->{date} = $date;
        $visit->{count} ||= 0;
        $visit->{ip_count} ||= 0;
        push @list, $visit;
        my $label;
        if ($i % $labels_every) {
            $label = "";
        }
        elsif ($segment < 60 * 60 * 2) {
            $label = $date->strftime("%I:%M");
        }
        else {
            $label = $date->strftime("%b %d");
        }
        push @labels, $label;
        push @counts, $visit->{count};
        push @ip_counts, $visit->{ip_count};
    }
    $visits->{list} = \@list;
    $visits->{labels} = \@labels;
    $visits->{counts} = \@counts;
    $visits->{ip_counts} = \@ip_counts;

    return $visits;
}

1;

