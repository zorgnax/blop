package Blop::Page;
use strict;
use warnings;
use Blop;

sub new {
    my ($class, %args) = @_;
    return undef if !%args;
    my $blop = Blop::instance();
    my $where = join " and ", map "$_=" . $blop->dbh->quote($args{$_}), keys %args;
    my $query = "select * from pages where $where";
    my $sth = $blop->dbh->prepare($query);
    $sth->execute();
    my $page = $sth->fetchrow_hashref();
    return undef if !$page;
    $page = bless $page, $class;
    return $page;
}

sub list {
    my ($class, %args) = @_;
    my $blop = Blop::instance();
    my $sth = $blop->dbh->prepare(<<EOSQL);
select pageid, title, url, added, published
from pages where published <= now() order by pageid
EOSQL
    $sth->execute();
    my @pages;
    while (my $page = $sth->fetchrow_hashref()) {
        $page = bless $page, $class;
        push @pages, $page;
    }
    return \@pages;
}

sub fullurl {
    my ($self) = @_;
    my $blop = Blop::instance();
    return "$blop->{urlbase}/$self->{url}";
}

sub editurl {
    my ($self) = @_;
    my $blop = Blop::instance();
    return "$blop->{urlbase}/admin/page/$self->{pageid}";
}

sub files {
    my ($self) = @_;
    my @files;
    my $blop = Blop::instance();
    for my $path (glob "$blop->{base}content/page/$self->{pageid}/*") {
        next if -d $path;
        $path =~ m{([^/]+)$};
        my $name = $1;
        my $url = "/content/page/$self->{pageid}/$name";
        my $file = {
            name => $name,
            path => $path,
            url => $url,
            fullurl => "$blop->{urlbase}$url",
            size => $blop->human_readable(-s $path),
        };
        push @files, $file;
    }
    return \@files;
}

sub num_files {
    my ($self) = @_;
    my $count = 0;
    my $blop = Blop::instance();
    for my $path (glob "$blop->{base}content/page/$self->{pageid}/*") {
        next if -d $path;
        $count++;
    }
    return $count;
}

sub was_published {
    my ($self) = @_;
    return 0 if !$self->{published};
    my $published = Blop::Date->new($self->{published});
    return 0 if !$published;
    return 0 if $published->{epoch} > time;
    return 1;
}

1;

