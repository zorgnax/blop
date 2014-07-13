package Blop::Category;
use strict;
use warnings;
use Blop;

sub new {
    my ($class, %args) = @_;
    return undef if !%args;
    my $blop = Blop::instance();
    my $where = join " and ", map "$_=" . $blop->dbh->quote($args{$_}), keys %args;
    my $sth = $blop->dbh->prepare(<<EOSQL);
select * from categories where $where
EOSQL
    $sth->execute();
    my $category = $sth->fetchrow_hashref();
    return undef if !$category;
    $category = bless $category, $class;
    return $category;
}

# non-special published list
sub nsp_list {
    my ($class) = @_;
    my $blop = Blop::instance();
    my $now = $blop->dbh->quote($blop->now->str);
    my $sth = $blop->dbh->prepare(<<EOSQL);
select c.*, count(p.postid) posts
from categories c
left join posts p on p.categoryid=c.categoryid
where c.special is null and (p.postid is null or p.published <= $now)
group by c.categoryid
order by c.categoryid
EOSQL
    $sth->execute();
    my @categories;
    while (my $category = $sth->fetchrow_hashref()) {
        $category = bless $category, $class;
        push @categories, $category;
    }
    return \@categories;
}

sub add {
    my ($class, %args) = @_;
    my $self = bless \%args, $class;
    $self->{url} = $self->get_available_url($args{url});
    my $blop = Blop::instance();
    my $sth = $blop->dbh->prepare(<<EOSQL);
insert into categories set name=?, url=?
EOSQL
    $sth->execute($self->{name}, $self->{url});
    $self->{categoryid} = $sth->{mysql_insertid};
    return $self;
}

sub edit {
    my ($self, %args) = @_;
    my $blop = Blop::instance();
    my %sets;
    for my $key (keys %args) {
        if ($self->{$key} ne $args{$key}) {
            $sets{$key} = $args{$key};
        }
    }
    if (%sets) {
        my $sets = join ", ", map "$_=" . $blop->dbh->quote($sets{$_}), keys %sets;
        my $sth = $blop->dbh->prepare(<<EOSQL);
update categories set $sets where categoryid=?
EOSQL
        $sth->execute($self->{categoryid});
    }
}

sub get_available_url {
    my ($self, $url) = @_;
    my $blop = Blop::instance();
    if (defined $url && length($url)) {
        if (!$blop->url_available($url)) {
            die "Category URL '$url' is unavailable.\n";
        }
        return $url;
    }
    $url = $blop->url($self->{name});
    if ($url ne "" && $blop->url_available($url)) {
        return $url;
    }
    while (1) {
        $url = $blop->token(4, "abcdefghijklmnopqrstuvwxyz");
        last if $blop->url_available($url);
    }
    return $url;
}

sub num_posts {
    my ($self) = @_;
    return $self->{num_posts} if exists $self->{num_posts};
    if (!$self->{special}) {
        $self->{num_posts} = $self->{posts};
        return $self->{num_posts};
    }
    my $where = "";
    if ($self->{special} eq "uncat") {
        $where = " where categoryid=0";
    }
    my $blop = Blop::instance();
    my $sth = $blop->dbh->prepare(<<EOSQL);
select count(*) from posts$where
EOSQL
    $sth->execute();
    my ($count) = $sth->fetchrow_array();
    $self->{num_posts} = $count;
    return $count;
}

sub latest_post {
    my ($self) = @_;
    return $self->{latest_post} if exists $self->{latest_post};
    my $blop = Blop::instance();
    my $where = "";
    if (!$self->{special}) {
        $where = " and categoryid=$self->{categoryid}";
    }
    elsif ($self->{special} eq "uncat") {
        $where = " and categoryid=0"
    }
    my $now = $blop->dbh->quote($blop->now->str);
    my $sth = $blop->dbh->prepare(<<EOSQL);
select * from posts where published <= $now$where order by published desc limit 1
EOSQL
    $sth->execute();
    my $post = $sth->fetchrow_hashref();
    $self->{latest_post} = $post;
    $post = bless $post, "Blop::Post" if $post;
    return $post;
}

1;

