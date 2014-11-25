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
    my ($class) = @_;
    my $blop = Blop::instance();
    my $now = $blop->dbh->quote($blop->now->str);
    my $sth = $blop->dbh->prepare(<<EOSQL);
select pageid, title, url, added, published, sequence, parentid
from pages where published <= $now order by sequence, title
EOSQL
    $sth->execute();
    my (@pages, %pages);
    while (my $page = $sth->fetchrow_hashref()) {
        $page = bless $page, $class;
        push @pages, $page;
        $pages{$page->{pageid}} = $page;
    }
    my @top;
    for my $page (@pages) {
        my $parent = $pages{$page->{parentid}};
        if ($parent) {
            push @{$parent->{children}}, $page;
        }
        else {
            push @top, $page;
        }
    }
    return \@top;
}

sub parent_pages {
    my ($class, $child) = @_;
    my $blop = Blop::instance();
    my $sth = $blop->dbh->prepare(<<EOSQL);
select pageid, title, url, added, published, sequence, parentid
from pages order by sequence, title
EOSQL
    $sth->execute();
    my (@pages, %pages);
    while (my $page = $sth->fetchrow_hashref()) {
        $page = bless $page, $class;
        push @pages, $page;
        $pages{$page->{pageid}} = $page;
    }
    return \@pages if !$child;
    my @parents;
    PAGE: for my $page (@pages) {
        my $page_ = $page;
        while ($page_) {
            next PAGE if $page_->{pageid} == $child->{pageid};
            $page_ = $pages{$page_->{parentid}};
        }
        push @parents, $page;
    }
    return \@parents;
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
    for my $path (glob $self->content_path . "/files/*") {
        next if -d $path;
        $path =~ m{([^/]+)$};
        my $name = $1;
        my $file = {
            name => $name,
            path => $path,
            url => "/" . $self->content_url . "/files/$name",
            fullurl => $self->content_fullurl . "/files/$name",
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
    for my $path (glob ($self->content_path . "/files/*")) {
        next if -d $path;
        $count++;
    }
    return $count;
}

sub content_url {
    my ($self) = @_;
    return $self->{content_url} if $self->{content_url};
    return "page/$self->{pageid}";
}

sub content_path {
    my ($self) = @_;
    my $blop = Blop::instance();
    return $blop->{base} . $self->content_url;
}

sub content_fullurl {
    my ($self) = @_;
    my $blop = Blop::instance();
    return $blop->{urlbase} . "/" . $self->content_url;
}

sub published {
    my ($self) = @_;
    return $self->{published} if ref $self->{published};
    return undef if !$self->{published};
    $self->{published} = Blop::Date->new($self->{published});
    return $self->{published};
}

sub was_published {
    my ($self) = @_;
    return 0 if !$self->{published};
    my $published = Blop::Date->new($self->{published});
    return 0 if !$published;
    return 0 if $published->{epoch} > time;
    return 1;
}

sub comments_enabled {
    my ($self) = @_;
    my $blop = Blop::instance();
    return $blop->{conf}{page_comments};
}

sub id_name {
    my ($self) = @_;
    return "pageid";
}

sub id_value {
    my ($self) = @_;
    return $self->{pageid};
}

sub comments {
    my ($self) = @_;
    return $self->{comments} if $self->{comments};
    my $blop = Blop::instance();
    my $where = "pageid=$self->{pageid} and ";
    my $or_cookie = "";
    if ($blop->cgi->cookie("cmnt")) {
        $or_cookie = " or cookie=" . $blop->dbh->quote($blop->cgi->cookie("cmnt"));
    }
    $where .= "(status='Approved'$or_cookie)";
    $self->{comments} = Blop::Comment->list($where);
    return $self->{comments};
}

sub num_comments {
    my ($self) = @_;
    return $self->{num_comments} if exists $self->{num_comments};
    my $blop = Blop::instance();
    my $sth = $blop->dbh->prepare(<<EOSQL);
select count(*) from comments where pageid=$self->{pageid} and status="Approved"
EOSQL
    $sth->execute();
    my ($count) = $sth->fetchrow_array();
    $self->{num_comments} = $count;
    return $count;
}

sub parsed_content {
    my ($self) = @_;
    my $markup = Blop::Markup->new(entry => $self);
    return $markup->convert($self->{content});
}

sub update_content {
    my ($self, %args) = @_;
    my $markup = Blop::Markup->new(entry => $self, update => 1, %args);
    return $markup->convert($self->{content});
}

sub label {
    my ($self) = @_;
    return $self->{title} ? $self->{title} : "Page $self->{pageid}";
}

sub short {
    my ($self) = @_;
    return "Page $self->{pageid}";
}

1;

