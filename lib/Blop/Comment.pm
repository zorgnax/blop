package Blop::Comment;
use strict;
use warnings;
use Blop;
use Blop::Post;
use Blop::Page;

sub new {
    my ($class, %args) = @_;
    return undef if !%args;
    my $blop = Blop::instance();
    my $where = join " and ", map "$_=" . $blop->dbh->quote($args{$_}), keys %args;
    my $query = "select * from comments where $where";
    my $sth = $blop->dbh->prepare($query);
    $sth->execute();
    my $comment = $sth->fetchrow_hashref();
    return undef if !$comment;
    $comment = bless $comment, $class;
    return $comment;
}

sub list {
    my ($class, $where) = @_;
    return [] if !$where;
    my $blop = Blop::instance();
    my $sth = $blop->dbh->prepare(<<EOSQL);
select * from comments where $where order by added
EOSQL
    $sth->execute();
    my @comments;
    while (my $comment = $sth->fetchrow_hashref()) {
        $comment = bless $comment, $class;
        push @comments, $comment;
    }
    return \@comments;
}

sub added {
    my ($self) = @_;
    return $self->{added} if ref $self->{added};
    return undef if !$self->{added};
    $self->{added} = Blop::Date->new($self->{added});
    return $self->{added};
}

sub edited {
    my ($self) = @_;
    return $self->{edited} if ref $self->{edited};
    return undef if !$self->{edited};
    $self->{edited} = Blop::Date->new($self->{edited});
    return $self->{edited};
}

sub editable {
    my ($self) = @_;
    my $blop = Blop::instance();
    my $cookie = $blop->cgi->cookie("cmnt") || "";
    $self->{cookie} ||= "";
    return $cookie && $cookie eq $self->{cookie};
}

sub parsed_content {
    my ($self) = @_;
    my $markup = Blop::Markup->new(entry => $self, comment => 1);
    return $markup->convert($self->{content});
}

sub added_to {
    my ($self) = @_;
    if ($self->{postid}) {
        my $post = bless {postid => $self->{postid}}, "Blop::Post";
        $post->{title} = $self->{post_title};
        $post->{url} = $self->{post_url};
        return $post;
    }
    elsif ($self->{pageid}) {
        my $page = bless {pageid => $self->{pageid}}, "Blop::Page";
        $page->{title} = $self->{page_title};
        $page->{url} = $self->{page_url};
        return $page;
    }
    return undef;
}

sub gravatar {
    my ($self) = @_;
    my $email = $self->{email};
    $email =~ s/^\s+|\s+$//g;
    $email = lc $email;
    require Digest::MD5;
    my $md5 = Digest::MD5::md5_hex($email);
    return "http://www.gravatar.com/avatar/$md5";
}

1;

