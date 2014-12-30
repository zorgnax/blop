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

sub newer {
    my ($self, $category) = @_;
    return $self->{newer} if exists $self->{newer};
    my $blop = Blop::instance();
    my $where = "";
    if ($category && !$category->{special}) {
        $where = " and categoryid=$category->{categoryid}";
    }
    elsif ($category && $category->{special} eq "uncat") {
        $where = " and categoryid=0";
    }
    my $now = $blop->dbh->quote($blop->now->str);
    my $published = $blop->dbh->quote($self->published->str);
    my $query = <<EOSQL;
select postid, title, url
from posts where published <= $now and published > ${published}$where
order by published asc limit 1
EOSQL
    my $sth = $blop->dbh->prepare($query);
    $sth->execute();
    my $newer = $sth->fetchrow_hashref();
    if ($newer) {
        $newer = bless $newer, "Blop::Post";
        $newer->{chain_category} = $category;
    }
    $self->{newer} = $newer;
    return $newer;
}

sub older {
    my ($self, $category) = @_;
    return $self->{older} if exists $self->{older};
    my $blop = Blop::instance();
    my $where = "";
    if ($category && !$category->{special}) {
        $where = " and categoryid=$category->{categoryid}";
    }
    elsif ($category && $category->{special} eq "uncat") {
        $where = " and categoryid=0";
    }
    my $now = $blop->dbh->quote($blop->now->str);
    my $published = $blop->dbh->quote($self->published->str);
    my $query = <<EOSQL;
select postid, title, url
from posts where published <= $now and published < ${published}$where
order by published desc limit 1
EOSQL
    my $sth = $blop->dbh->prepare($query);
    $sth->execute();
    my $older = $sth->fetchrow_hashref();
    if ($older) {
        $older = bless $older, "Blop::Post";
        $older->{chain_category} = $category;
    }
    $self->{older} = $older;
    return $older;
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
    my $url = "$blop->{urlbase}/$self->{url}";
    if ($self->{chain_category}) {
        $url .= "?cat=" . $self->{chain_category}{categoryid};
    }
    return $url;
}

sub editurl {
    my ($self) = @_;
    my $blop = Blop::instance();
    return "$blop->{urlbase}/admin/post/$self->{postid}";
}

sub category {
    my ($self) = @_;
    return $self->{category} if exists $self->{category};
    if ($self->{category_str}) {
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
    for my $path (glob ($self->content_path . "/files/*")) {
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

sub content_url {
    my ($self) = @_;
    return $self->{content_url} if $self->{content_url};
    return "post/$self->{postid}";
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

sub num_files {
    my ($self) = @_;
    my $count = 0;
    my $blop = Blop::instance();
    for my $path (glob $self->content_path . "/files/*") {
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

sub update_content {
    my ($self, %args) = @_;
    my $markup = Blop::Markup->new(entry => $self, update => 1, %args);
    return $markup->convert($self->{content});
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
    return $blop->{conf}{post_comments};
}

sub id_name {
    my ($self) = @_;
    return "postid";
}

sub id_value {
    my ($self) = @_;
    return $self->{postid};
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
    $where .=  "(status='Approved'$or_cookie)";
    $self->{comments} = Blop::Comment->list($where);
    return $self->{comments};
}

sub num_comments {
    my ($self) = @_;
    return $self->{num_comments} if exists $self->{num_comments};
    my $blop = Blop::instance();
    my $where = "postid=$self->{postid} and ";
    my $or_cookie = "";
    if ($blop->cgi->cookie("cmnt")) {
        $or_cookie = " or cookie=" . $blop->dbh->quote($blop->cgi->cookie("cmnt"));
    }
    $where .=  "(status='Approved'$or_cookie)";
    my $query = "select count(*) from comments where $where";
    my $sth = $blop->dbh->prepare($query);
    $sth->execute();
    my ($count) = $sth->fetchrow_array();
    $self->{num_comments} = $count;
    return $count;
}

sub label {
    my ($self) = @_;
    return $self->{title} ? $self->{title} : "Post $self->{postid}";
}

sub short {
    my ($self) = @_;
    return "Post $self->{postid}";
}

1;

