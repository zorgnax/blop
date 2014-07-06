package Blop::Post;
use strict;
use warnings;
use Blop;
use Blop::Category;
use Blop::Tag;
use Blop::Markup;
use Blop::Comment;

sub new {
    my ($class, %args) = @_;
    return undef if !%args;
    my $blop = Blop::instance();
    my $where = join " and ", map "$_=" . $blop->dbh->quote($args{$_}), keys %args;
    my $sth = $blop->dbh->prepare(<<EOSQL);
select * from posts where $where
EOSQL
    $sth->execute();
    my $post = $sth->fetchrow_hashref();
    return undef if !$post;
    $post = bless $post, $class;
    return $post;
}

sub next {
    my ($self, $category) = @_;
    return $self->{next} if exists $self->{next};
    my $blop = Blop::instance();
    my $where = "";
    if ($category && !$category->{special}) {
        $where = " and categoryid=$category->{categoryid}";
    }
    elsif ($category && $category->{special} eq "uncat") {
        $where = " and categoryid=0";
    }
    my $query = <<EOSQL;
select postid, title, url
from posts where published > ?$where
order by published asc limit 1
EOSQL
    my $sth = $blop->dbh->prepare($query);
    $sth->execute($self->{published});
    my $next = $sth->fetchrow_hashref();
    $next = bless $next, "Blop::Post" if $next;
    $self->{next} = $next;
    return $next;
}

sub prev {
    my ($self, $category) = @_;
    return $self->{prev} if exists $self->{prev};
    my $blop = Blop::instance();
    my $where = "";
    if ($category && !$category->{special}) {
        $where = " and categoryid=$category->{categoryid}";
    }
    elsif ($category && $category->{special} eq "uncat") {
        $where = " and categoryid=0";
    }
    my $query = <<EOSQL;
select postid, title, url
from posts where published < ?$where
order by published desc limit 1
EOSQL
    my $sth = $blop->dbh->prepare($query);
    $sth->execute($self->{published});
    my $prev = $sth->fetchrow_hashref();
    $prev = bless $prev, "Blop::Post" if $prev;
    $self->{prev} = $prev;
    return $prev;
}

sub tags_str {
    my ($self) = @_;
    return join ", ", map $_->{name}, @{$self->tags};
}

sub tags {
    my ($self) = @_;
    return $self->{tags} if $self->{tags};
    my $blop = Blop::instance();
    my $sth = $blop->dbh->prepare(<<EOSQL);
select * from tags where postid=? order by tagid
EOSQL
    $sth->execute($self->{postid});
    $self->{tags} = [];
    while (my $tag = $sth->fetchrow_hashref()) {
        $tag = bless $tag, "Blop::Tag";
        push @{$self->{tags}}, $tag;
        $self->{tag_hash}{$tag->{name}} = $tag;
    }
    return $self->{tags};
}

sub has_tag {
    my ($self, $tag) = @_;
    $self->tags();
    return $self->{tag_hash} && $self->{tag_hash}{$tag};
}

sub add_tag {
    my ($self, $tag) = @_;
    my $blop = Blop::instance();
    my $sth = $blop->dbh->prepare(<<EOSQL);
insert into tags set postid=?, name=?
EOSQL
    $sth->execute($self->{postid}, $tag);
}

sub rm_tag {
    my ($self, $tag) = @_;
    my $blop = Blop::instance();
    my $sth = $blop->dbh->prepare(<<EOSQL);
delete from tags where postid=? and name=?
EOSQL
    $sth->execute($self->{postid}, $tag);
}

sub fullurl {
    my ($self) = @_;
    my $blop = Blop::instance();
    return "$blop->{urlbase}/$self->{url}";
}

sub editurl {
    my ($self) = @_;
    my $blop = Blop::instance();
    return "$blop->{urlbase}/admin/post/$self->{postid}";
}

sub category {
    my ($self) = @_;
    return $self->{category} if exists $self->{category};
    if (exists $self->{category_str}) {
        $self->{category} = bless {
            categoryid => $self->{categoryid},
            name => $self->{category_str},
            url => $self->{category_url},
        }, "Blop::Category";
    }
    else {
        $self->{category} = Blop::Category->new(categoryid => $self->{categoryid});
    }
    return $self->{category};
}

sub files {
    my ($self) = @_;
    my @files;
    my $blop = Blop::instance();
    for my $path (glob "$blop->{base}content/post/$self->{postid}/*") {
        next if -d $path;
        $path =~ m{([^/]+)$};
        my $name = $1;
        my $url = "/content/post/$self->{postid}/$name";
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
    for my $path (glob "$blop->{base}content/post/$self->{postid}/*") {
        next if -d $path;
        $count++;
    }
    return $count;
}

sub parsed_content {
    my ($self) = @_;
    my $markup = Blop::Markup->new(entry => $self);
    return $markup->convert($self->{content});
}

sub was_published {
    my ($self) = @_;
    return 0 if !$self->{published};
    my $published = Blop::Date->new($self->{published});
    return 0 if !$published;
    return 0 if $published->{epoch} > time;
    return 1;
}

sub comments {
    my ($self) = @_;
    return $self->{comments} if $self->{comments};
    my $blop = Blop::instance();
    my $where = "postid=$self->{postid} and ";
    my $or_cookie = "";
    if ($blop->cgi->cookie("cmnt")) {
        $or_cookie = " or cookie=" . $blop->dbh->quote($blop->cgi->cookie("cmnt"));
    }
    $where .=  "(status='approved'$or_cookie)";
    $self->{comments} = Blop::Comment->list($where);
    return $self->{comments};
}

sub num_comments {
    my ($self) = @_;
    return $self->{num_comments} if exists $self->{num_comments};
    my $blop = Blop::instance();
    my $sth = $blop->dbh->prepare(<<EOSQL);
select count(*) from comments where postid=$self->{postid} and status="approved"
EOSQL
    $sth->execute();
    my ($count) = $sth->fetchrow_array();
    $self->{num_comments} = $count;
    return $count;
}

1;

