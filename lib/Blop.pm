package Blop;
use strict;
use warnings;
BEGIN {
    eval {require cPanelUserConfig};
    my $home = (getpwuid($<))[7];
    $ENV{PATH} .= ":$home/bin";
}
use CGI;
use Template;
use DBI;
use URI;
use Data::Dumper;
use Blop::Date;
use Blop::Category;
use Blop::Post;
use Blop::Page;
use Blop::Comment;
use Blop::Navigation;
use Blop::Section;
use Blop::Widget;
use Blop::Config;
use Blop::Log;
use Blop::Theme;

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
    $vars{theme} = $self->{theme};
    $vars{cgi} = $self->cgi;
    $template->process($file, \%vars, \my $out) or die $template->error;
    return $out;
}

sub load_theme {
    my ($self) = @_;
    my $theme = Blop::Theme->new($self->{conf}{theme});
    $self->{theme} = $theme;
    $self->{template_include_path} = $theme->template_include_path;
}

sub logo {
    my ($self) = @_;
    return $self->{logo} if exists $self->{logo};
    my ($logo) = glob "$self->{base}sect/main/logo.*";
    return "" if !$logo;
    $logo =~ m{([^/]+)$};
    my $name = $1;
    $self->{logo} = "$self->{urlbase}/sect/main/$name";
    return $self->{logo};
}

sub background {
    my ($self) = @_;
    return $self->{background} if exists $self->{background};
    my ($background) = glob "$self->{base}sect/main/background.*";
    return "" if !$background;
    $background =~ m{([^/]+)$};
    my $name = $1;
    $self->{background} = "$self->{urlbase}/sect/main/$name";
    return $self->{background};
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
    my $sth = $self->dbh->prepare("select * from config");
    $sth->execute();
    while (my $data = $sth->fetchrow_hashref()) {
        $self->{conf}{$data->{name}} = $data->{value};
    }
    if ($self->{conf}{timezone}) {
        $ENV{TZ} = $self->{conf}{timezone};
    }
    return $self;
}

sub dbh {
    my ($self) = @_;
    return $self->{dbh} if $self->{dbh};
    my $conf = Blop::Config::read("$self->{base}blop.conf");
    my $dsn = "dbi:mysql:host=$conf->{dbhost};database=$conf->{dbtable};";
    $dsn .= "mysql_multi_statements=1";
    my %vars = (PrintError => 0, RaiseError => 1);
    $self->{dbh} = DBI->connect($dsn, $conf->{dbuser}, $conf->{dbpass}, \%vars);
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
    my $abs_size = abs $size;
    for ($i = 0; $i < @power; $i++) {
        last if $abs_size < 1024;
        $abs_size /= 1024;
    }
    my $str = sprintf("%.1f", $abs_size) . $power[$i];
    $str =~ s/\.0//;
    $str = "-$str" if $size < 0;
    return $str;
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
    my ($self, %args) = @_;
    my $sets = join ", ", map "$_=" . $blop->dbh->quote($args{$_}), keys %args;
    my $sth = $self->dbh->prepare(<<EOSQL);
insert into log set date=?, ipaddr=?, uri=?, $sets
EOSQL
    $sth->execute($self->now->str, $ENV{REMOTE_ADDR}, $ENV{REQUEST_URI});
}

sub session {
    my ($self) = @_;
    return $self->{session} if exists $self->{session};
    if (!$self->cgi->cookie("sesh") || !$self->dbh) {
        $self->{session} = undef;
        return undef;
    }
    my $sth = $self->dbh->prepare(<<EOSQL);
select * from sessions where sessionid=?
EOSQL
    $sth->execute($self->cgi->cookie("sesh"));
    $self->{session} = $sth->fetchrow_hashref();
    return $self->{session};
}

sub create_session {
    my ($self) = @_;
    my $sessionid = $self->token(22);
    my $csrf = $self->token(22);
    my $sth = $self->dbh->prepare(<<EOSQL);
insert into sessions set sessionid=?, admin=1, ipaddr=?, added=?, csrf=?
EOSQL
    $sth->execute($sessionid, $ENV{REMOTE_ADDR}, $self->now->str, $csrf);
    $self->{new_sesh} = $sessionid;
    return $sessionid;
}

# keeps refreshing your cookies so they expire x days after last view not login
sub http_header {
    my ($self, @headers) = @_;
    my $out = "";
    my %headers;
    while (my $name = shift @headers) {
        my $value = shift @headers;
        $headers{$name} = $value;
        $out .= "$name: $value\n";
    }
    my $sesh;
    $sesh = $self->session->{sessionid} if $self->session;
    $sesh = $self->{new_sesh} if $self->{new_sesh};
    if ($sesh) {
        my $cookie = $cgi->cookie(
            -name => "sesh", -value => $sesh,
            -expires => "+25d", -path => "$self->{urlbase}/", -httponly => 1);
        $out .= "Set-Cookie: $cookie\n";
    }
    my $cmnt = $self->{new_cmnt} || $self->cgi->cookie("cmnt");
    if ($cmnt) {
        my $cookie = $cgi->cookie(
            -name => "cmnt", -value => $cmnt,
            -expires => "+25d", -path => "$self->{urlbase}/", -httponly => 1);
        $out .= "Set-Cookie: $cookie\n";
    }
    if (!$headers{"Content-Type"}) {
        $out .= "Content-Type: text/html; charset=utf-8\n";
    }
    $out .= "\n";
    return $out;
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
    $self->{categories} = Blop::Category->list(%args);
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

sub last_comment {
    my ($self) = @_;
    return $self->{last_comment} if exists $self->{last_comment};
    $self->{last_comment} = undef;
    my $cookie = $self->cgi->cookie("cmnt") or return;
    my $sth = $self->dbh->prepare(<<EOSQL);
select commentid, name, email from comments where cookie=?
order by ifnull(edited, added) desc limit 1
EOSQL
    $sth->execute($cookie);
    my $comment = $sth->fetchrow_hashref();
    $comment = bless $comment, "Blop::Comment" if $comment;
    $self->{last_comment} = $comment;
    return $comment;
}

sub date_archives {
    my ($self) = @_;
    return $self->{date_archives} if $self->{date_archives};
    my $now = $self->dbh->quote($self->now->str);
    my $sth = $self->dbh->prepare(<<EOSQL);
select
    date_format(published, "%M %Y") name,
    date_format(published, "%Y/%m") url,
    count(*) posts
from posts
where published <= $now
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

sub num_posts {
    my ($self) = @_;
    return $self->{num_posts} if $self->{num_posts};
    my $now = $self->dbh->quote($self->now->str);
    my $sth = $self->dbh->prepare(<<EOSQL);
select count(*) count, sum(published < $now) published, sum(published is null or published >= $now) unpublished from posts
EOSQL
    $sth->execute();
    $self->{num_posts} = $sth->fetchrow_hashref();
    $self->{num_posts}{published} ||= 0;
    $self->{num_posts}{unpublished} ||= 0;
    return $self->{num_posts};
}

sub num_pages {
    my ($self) = @_;
    return $self->{num_pages} if $self->{num_pages};
    my $now = $self->dbh->quote($self->now->str);
    my $sth = $self->dbh->prepare(<<EOSQL);
select count(*) count, sum(published < $now) published, sum(published is null or published >= $now) unpublished from pages
EOSQL
    $sth->execute();
    $self->{num_pages} = $sth->fetchrow_hashref();
    $self->{num_pages}{published} ||= 0;
    $self->{num_pages}{unpublished} ||= 0;
    return $self->{num_pages};
}

sub num_categories {
    my ($self) = @_;
    return $self->{num_categories} if exists $self->{num_categories};
    my $sth = $self->dbh->prepare(<<EOSQL);
select count(*) from categories where special is null
EOSQL
    $sth->execute();
    ($self->{num_categories}) = $sth->fetchrow_array();
    return $self->{num_categories};
}

sub num_tags {
    my ($self) = @_;
    return $self->{num_tags} if exists $self->{num_tags};
    my $sth = $self->dbh->prepare(<<EOSQL);
select count(distinct name) from tags
EOSQL
    $sth->execute();
    ($self->{num_tags}) = $sth->fetchrow_array();
    return $self->{num_tags};
}

sub num_comments {
    my ($self) = @_;
    return $self->{num_comments} if $self->{num_comments};
    my $sth = $self->dbh->prepare(<<EOSQL);
select sum(status="approved") approved, sum(status="pending") pending from comments
EOSQL
    $sth->execute();
    $self->{num_comments} = $sth->fetchrow_hashref();
    $self->{num_comments}{approved} ||= 0;
    $self->{num_comments}{pending} ||= 0;
    return $self->{num_comments};
}

sub page {
    my ($self, %args) = @_;
    my $page = Blop::Page->new(%args);
    return $page;
}

sub pages {
    my ($self) = @_;
    return $self->{pages} if $self->{pages};
    $self->{pages} = Blop::Page->list();
    return $self->{pages};
}

sub parent_pages {
    my ($self, $child) = @_;
    return $self->{parent_pages} if $self->{parent_pages};
    $self->{parent_pages} = Blop::Page->parent_pages($child);
    return $self->{parent_pages};
}

sub section {
    my ($self, $name) = @_;
    return $self->{$name} if exists $self->{$name};
    my $section = Blop::Section->new($name);
    $self->{$name} = $section;
    return $section;
}

sub sidebar {
    my ($self) = @_;
    return $self->section("sidebar");
}

sub footer {
    my ($self) = @_;
    return $self->section("footer");
}

sub ps {
    my ($self) = @_;
    return $self->section("ps");
}

sub widgets {
    my ($self) = @_;
    return sort {$a->{name} cmp $b->{name}} values %Blop::Widget::widgets;
}

sub url_available {
    my ($self, $url) = @_;
    if (length($url) && -e "$self->{base}$url") {
        return 0;
    }
    return 0 if $url =~ m{^(admin|tag|themes|\d{4}|post/\d+|page/\d+|sect)(/|$)};
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
    print $self->http_header(Status => "303 See Other", Location => $location);
    exit;
}

sub assert_admin {
    my ($self) = @_;
    die "Admin privilege required!\n" if !$self->admin;
}

sub assert_csrf {
    my ($self) = @_;
    my $csrf = $cgi->param("csrf") || "";
    die "CSRF token doesn't match!\n" if $csrf ne $self->csrf;
}

sub csrf {
    my ($self) = @_;
    return "" if !$self->session;
    return $self->session->{csrf} || "";
}

sub token {
    my ($self, $chars, $set) = @_;
    $chars ||= 22;
    $set ||= "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    return join "", map substr($set, rand(length($set)), 1), 1 .. $chars;
}

sub now {
    my ($self) = @_;
    return Blop::Date->now;
}

sub comma_and {
    my ($self, @a) = @_;
    return "" if !@a;
    return $a[0] if @a == 1;
    return "$a[0] and $a[1]" if @a == 2;
    my $last = pop @a;
    return join(", ", @a) . ", and " . $last;
}

sub build {
    my ($self) = @_;
    return $self->{build} if $self->{build};
    if (-e "$self->{base}.blop-build") {
        open my $fh, "<", "$self->{base}.blop-build" or die "$!\n";
        $self->{build} = do {local $/; <$fh>};
        chomp $self->{build};
        close $fh;
        return $self->{build};
    }
    if (-e "$self->{base}.git") {
        if (open my $fh, "-|", "git", "log", "--format=%cd",
                          "-1", "--date=iso") {
            $self->{build} = do {local $/; <$fh>};
            $self->{build} =~ s/\s+[+-]?\d+\s*$//;
            close $fh;
            return $self->{build};
        }
    }
    $self->{build} = "unknown";
    return $self->{build};
}

sub search {
    my ($self) = @_;
    return $self->cgi->param("s");
}

1;

