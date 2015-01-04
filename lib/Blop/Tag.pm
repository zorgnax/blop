package Blop::Tag;
use strict;
use warnings;
use Blop;

sub new {
    my ($class, %args) = @_;
    return undef if !%args;
    my $blop = Blop::instance();
    my $where = join " and ", map "$_=" . $blop->dbh->quote($args{$_}), keys %args;
    my $sth = $blop->dbh->prepare(<<EOSQL);
select * from tags where $where
EOSQL
    $sth->execute();
    my $tag = $sth->fetchrow_hashref();
    return undef if !$tag;
    $tag = bless $tag, $class;
    return $tag;
}

my $max_posts = 0;

sub list {
    my ($class) = @_;
    my $blop = Blop::instance();
    my $now = $blop->dbh->quote($blop->now->str);
    my $sth = $blop->dbh->prepare(<<EOSQL);
select t.name, count(p.postid) posts
from tags t left join posts p on p.postid=t.postid
where p.published <= $now group by t.name
EOSQL
    $sth->execute();
    my @tags;
    while (my $tag = $sth->fetchrow_hashref()) {
        $tag = bless $tag, $class;
        push @tags, $tag;
        if ($tag->{posts} > $max_posts) {
            $max_posts = $tag->{posts};
        }
    }
    return \@tags;
}

sub fullurl {
    my ($self) = @_;
    my $blop = Blop::instance();
    return "$blop->{urlbase}/tag/" . $blop->escape_uri($self->{name});
}

sub size {
    my ($self) = @_;
    my $min = 10;
    my $max = 60;
    my $size = int ($min + ($self->{posts} / $max_posts) * ($max - $min));
    return $size . "px";
}

1;

