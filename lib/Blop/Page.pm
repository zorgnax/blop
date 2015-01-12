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
from pages where published <= $now and hidden=0 and title!=""
order by sequence, pageid
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
    my $extra_links = $blop->{conf}{extra_links} || "";
    while ($extra_links =~ /\s*([^,]+)\s+([^,]+)/g) {
        my $title = $1;
        my $fullurl = $2;
        my $link = bless {title => $title, fullurl => $fullurl}, $class;
        push @top, $link;
    }
    return \@top;
}

# gives a list of pages that do not include $child as one of it's
# possible parents
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
    return $self->{fullurl} if $self->{fullurl};
    my $blop = Blop::instance();
    return "$blop->{urlbase}/" . $blop->escape_uri($self->{url});
}

sub editurl {
    my ($self) = @_;
    my $blop = Blop::instance();
    return "$blop->{urlbase}/admin/page/$self->{pageid}";
}

sub get_file_paths {
    my ($self, $sort) = @_;
    my @paths = glob ($self->content_path . "/files/*");
    if ($sort eq "time") {
        my %mtime;
        for my $path (@paths) {
            $mtime{$path} = (stat($path))[9];
        }
        @paths = sort {$mtime{$a} <=> $mtime{$b}} @paths;
    }
    else {
        @paths = sort @paths;
    }
    return \@paths;
}

sub files {
    my ($self, $sort) = @_;
    my @files;
    my $blop = Blop::instance();
    my $paths = $self->get_file_paths($sort);
    for my $path (@$paths) {
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
    my $where = "pageid=$self->{pageid} and ";
    my $or_cookie = "";
    if ($blop->cgi->cookie("cmnt")) {
        $or_cookie = " or cookie=" . $blop->dbh->quote($blop->cgi->cookie("cmnt"));
    }
    $where .= "(status='Approved'$or_cookie)";
    my $query = "select count(*) from comments where $where";
    my $sth = $blop->dbh->prepare($query);
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

sub label2 {
    my ($self) = @_;
    my $label2 = "Page ";
    $label2 .= $self->{title} ? "\"$self->{title}\"" : $self->{pageid};
    return $label2;
}

sub short {
    my ($self) = @_;
    return "Page $self->{pageid}";
}

sub full_title {
    my ($self) = @_;
    my $blop = Blop::instance();
    my $title = $blop->{conf}{title};
    if ($self->{title}) {
        $title = "$self->{title} | $title";
    }
    return $title;
}

1;

