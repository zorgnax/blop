package Blop;
use strict;
use warnings;
use CGI;
use Template;
use Config::Tiny;
use DBI;
use URI;
use Data::Dumper;
use Blop::Date;
use Blop::Category;
use Blop::Post;
use Blop::Page;
use Blop::Comment;
use Blop::Navigation;

my $blop;
my $template;
my $cgi;

sub instance {
    return $blop;
}

sub new {
    my ($class, %args) = @_;
    my $self = bless \%args, $class;
    $self->{base} ||= "";
    $self->{urlbase} ||= "";
    $blop = $self;
    return $self;
}

sub cgi {
    my ($self) = @_;
    $cgi ||= CGI->new;
    return $cgi;
}

sub template {
    my ($self, $file, %extra_vars) = @_;
    if (!$template) {
        my $path = $self->{template_include_path} || "$self->{base}admin/templates";
        my $args = {INCLUDE_PATH => $path};
        $template = Template->new($args) or die $Template::ERROR;
        $Template::Filters::FILTERS->{uri} = sub {return $self->escape_uri(@_)};
        $Template::Filters::FILTERS->{html} = sub {return $self->escape_html(@_)};
        $Template::Filters::FILTERS->{json} = sub {return $self->escape_json(@_)};
    }
    my %vars = (blop => $self, urlbase => $self->{urlbase}, %extra_vars);
    $vars{ENV} = \%ENV;
    $vars{dump} = sub {return "<pre>" . $self->dump(@_ ? @_ : \%vars) . "</pre>"};
    $vars{url} = sub {$self->theme_url(@_)};
    $vars{cgi} = $self->cgi;
    $template->process($file, \%vars, \my $out) or die $template->error;
    return $out;
}

sub load_theme {
    my ($self) = @_;
    my $path = "";
    my $theme = $self->{conf}{theme} || "";
    if ($theme && $theme ne "default") {
        $path .= "$self->{base}themes/$theme:";
    }
    $path .= "$self->{base}themes/default";
    $self->{template_include_path} = $path;
}

sub theme_url {
    my ($self, $file) = @_;
    my $theme = $self->{conf}{theme} || "";
    if ($theme && $theme ne "default" && -e "$self->{base}themes/$theme/$file") {
        return "$self->{urlbase}/themes/$theme/$file";
    }
    elsif (-e "$self->{base}themes/default/$file") {
        return "$self->{urlbase}/themes/default/$file";
    }
    return undef;
}

sub read_conf {
    my ($self) = @_;
    if (!-e "$self->{base}blop.conf") {
        print <<EOHEADER;
Status: 303 See Other
Location: $self->{urlbase}/admin/install
Content-Type: text/html; charset=utf-8

EOHEADER
        exit;
    }
    my $conf = Config::Tiny->read("$self->{base}blop.conf")
        or die "$Config::Tiny::errstr\n";
    my $dsn = "dbi:mysql:host=$conf->{_}{dbhost};database=$conf->{_}{dbtable};";
    $dsn .= "mysql_multi_statements=1";
    my %vars = (PrintError => 0, RaiseError => 1);
    $self->{dbh} = DBI->connect($dsn, $conf->{_}{dbuser}, $conf->{_}{dbpass}, \%vars);
    my $sth = $self->{dbh}->prepare("select * from config");
    $sth->execute();
    while (my $data = $sth->fetchrow_hashref()) {
        $self->{conf}{$data->{name}} = $data->{value};
    }
}

sub dbh {
    my ($self) = @_;
    return $self->{dbh};
}

sub dump {
    my ($self, @args) = @_;
    $Data::Dumper::Indent = 1;
    $Data::Dumper::Sortkeys = 1;
    return Dumper(@args);
}

sub human_readable {
    my ($self, $size) = @_;
    my @power = ("B", "K", "M", "G", "T", "P", "E", "Z", "Y");
    my $i = 0;
    for ($i = 0; $i < @power; $i++) {
        last if $size < 1024;
        $size /= 1024;
    }
    return sprintf("%.0f", $size) . $power[$i];
}

sub escape_uri {
    my ($self, $str) = @_;
    return "" if !defined $str;
    $str =~ s/([?#&=+;])/sprintf("%%%02x", ord($1))/ge;
    return $str;
}

sub escape_html {
    my ($self, $str) = @_;
    $str = "" if !defined $str;
    $str =~ s/&/&amp;/g;
    $str =~ s/>/&gt;/g;
    $str =~ s/</&lt;/g;
    $str =~ s/"/&quot;/g;
    return $str;
}

sub escape_json_str {
    my ($self, $str) = @_;
    return "null" if !defined $str;
    $str =~ s/\r//g;
    $str =~ s/\n/\\n/g;
    $str =~ s/"/\\"/g;
    return "\"$str\"";
}

sub escape_json {
    my ($self, $data, $level) = @_;
    $level ||= 0;
    my $out;
    if (!ref $data) {
        $out = $self->escape_json_str($data);
    }
    elsif (eval {ref $data eq "HASH" || $data->isa("HASH")}) {
        $out = "{\n";
        my @keys = sort keys %$data;
        for my $i (0 .. $#keys) {
            my $key = $keys[$i];
            $out .= "    " x ($level + 1);
            $out .= $self->escape_json_str($key) . ": ";
            $out .= $self->escape_json($data->{$key}, $level + 1);
            $out .= "," if $i != $#keys;
            $out .= "\n";
        }
        $out .= ("    " x $level) . "}";
    }
    elsif (eval {ref $data eq "ARRAY" || $data->isa("ARRAY")}) {
        $out = "[\n";
        for my $i (0 .. $#$data) {
            $out .= "    " x ($level + 1);
            $out .= $self->escape_json($data->[$i], $level + 1);
            $out .= "," if $i != $#$data;
            $out .= "\n";
        }
        $out .= ("    " x $level) . "]";
    }
    else {
        $out = $self->escape_json_str("" . $data);
    }
    $out .= "\n" if !$level;
    return $out;
}

sub log {
    my ($self, $content) = @_;
    my $sth = $self->dbh->prepare(<<EOSQL);
insert into log set date=now(), content=?, ipaddr=?, uri=?
EOSQL
    $sth->execute($content, $ENV{REMOTE_ADDR}, $ENV{REQUEST_URI});
}

sub session {
    my ($self) = @_;
    return $self->{session} if exists $self->{session};
    my $sth = $self->dbh->prepare(<<EOSQL);
select * from sessions where sessionid=?
EOSQL
    $sth->execute($self->cgi->cookie("sesh") || "");
    $self->{session} = $sth->fetchrow_hashref();
    return $self->{session};
}

sub category {
    my ($self, %args) = @_;
    my $category = Blop::Category->new(%args);
    return $category;
}

sub allcat {
    my ($self) = @_;
    return $self->{allcat} if $self->{allcat};
    $self->{allcat} = $self->category(special => "allcat");
    return $self->{allcat};
}

sub categories {
    my ($self, %args) = @_;
    return $self->{categories} if $self->{categories};
    $self->{categories} = Blop::Category->nsp_list(%args);
    return $self->{categories};
}

sub add_category {
    my ($self, %args) = @_;
    my $category = Blop::Category->add(%args);
    return $category;
}

sub post {
    my ($self, %args) = @_;
    my $post = Blop::Post->new(%args);
    return $post;
}

sub comment {
    my ($self, %args) = @_;
    my $comment = Blop::Comment->new(%args);
    return $comment;
}

sub pending_comments {
    my ($self) = @_;
    return $self->{pending_comments} if exists $self->{pending_comments};
    my $sth = $self->dbh->prepare(<<EOSQL);
select count(*) from comments where status="pending"
EOSQL
    $sth->execute();
    my ($count) = $sth->fetchrow_array();
    $self->{pending_comments} = $count;
    return $count;
}

sub date_archives {
    my ($self) = @_;
    return $self->{date_archives} if $self->{date_archives};
    my $sth = $self->dbh->prepare(<<EOSQL);
select
    date_format(published, "%b %Y") name,
    date_format(published, "%Y/%m") url,
    count(*) posts
from posts
where published <= now()
group by year(published), month(published)
order by published desc;
EOSQL
    $sth->execute();
    my @archives;
    while (my $archive = $sth->fetchrow_hashref()) {
        push @archives, $archive;
    }
    $self->{date_archives} = \@archives;
    return \@archives;
}

sub page {
    my ($self, %args) = @_;
    my $page = Blop::Page->new(%args);
    return $page;
}

sub pages {
    my ($self, %args) = @_;
    return $self->{pages} if $self->{pages};
    $self->{pages} = Blop::Page->list(%args);
    return $self->{pages};
}

sub url_available {
    my ($self, $url) = @_;
    if (length($url) && -e "$self->{base}$url") {
        return 0;
    }
    return 0 if $url =~ m{^(tag|themes|\d{4})(/|$)};
    return 0 if $self->post(url => $url);
    return 0 if $self->page(url => $url);
    return 0 if $self->category(url => $url);
    return 1;
}

sub url {
    my ($self, $name) = @_;
    return "" if !defined $name;
    my $url = lc($name);
    $url =~ s{[\*\.\[\]\(\)\{\}\<\>\&"';:\?\/\^\%\|\$\#\@\!\,]}{}g;
    $url =~ s{\s+}{-}g;
    return $url;
}

sub admin {
    my ($self) = @_;
    return 0 if !$self->session;
    return $self->session->{admin};
}

sub require_admin {
    my ($self) = @_;
    return if $self->admin;
    my $location = URI->new("$self->{urlbase}/admin/login");
    $location->query_form(redirect => $ENV{REQUEST_URI});
    print <<EOHEADER;
Status: 303 See Other
Location: $location
Content-Type: text/html; charset=utf-8

EOHEADER
    exit;
}

sub token {
    my ($self, $chars, $set) = @_;
    $chars ||= 22;
    $set ||= "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    return join "", map substr($set, rand(length($set)), 1), 1 .. $chars;
}

1;

