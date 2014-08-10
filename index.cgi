#!/usr/bin/perl
use lib "lib";
use blopcgi;

$blop->read_conf();
$blop->load_theme();

my $path = $cgi->param("path") || "";

my @tags;
if ($path =~ m{^tag/(.*)$}) {
    my $tags = $1;
    while ($tags =~ m{([^,]+)}g) {
        my $tag = $1;
        $tag =~ s/^\s+|\s+$//g;
        push @tags, $tag;
    }
    listing();
}

my ($year, $month, $day);
if ($path =~ m{^(\d{4})(/(\d+)(/(\d+))?)?($|/)}) {
    $year = $1;
    $month = $3;
    $day = $5;
    listing();
}

my $category = $blop->category(url => $path);
if ($category) {
    listing();
}

my $post = $blop->post(url => $path);
if ($post) {
    if (!$blop->admin && !$post->was_published) {
        not_found();
    }
    post();
}

my $page = $blop->page(url => $path);
if ($page) {
    if (!$blop->admin && !$page->was_published) {
        not_found();
    }
    page();
}

not_found();

sub listing {
    $blop->{display_tags} = \@tags if @tags;
    $blop->{display_category} = $category;
    $blop->{display_year} = $year;
    $blop->{display_month} = $month;
    $blop->{display_day} = $day;

    if ($blop->{conf}{cat_latest} && $category) {
        $post = $category->latest_post() or die "No posts.\n";
        post();
    }

    $blop->{listing} = 1;

    my $limit = $cgi->param("limit");
    $limit = $blop->{conf}{ppp} if !defined $limit;
    $limit = 3 if !defined $limit;
    if ($limit !~ /^\d+$/) {
        die "Invalid limit param.\n";
    }

    my $offset = $cgi->param("offset");
    $offset = 0 if !defined $offset;
    if ($offset !~ /^\d+$/) {
        die "Invalid offset param.\n";
    }

    my $where = "";
    my $join = "";

    if ($category && $category->{special} && $category->{special} eq "allcat") {
        # ok
    }
    elsif ($category && $category->{special} && $category->{special} eq "uncat") {
        $where .= "and p.categoryid=0\n";
    }
    elsif ($category) {
        $where .= "and p.categoryid=$category->{categoryid}\n";
    }

    if (@tags) {
        $join = "left join tags t on t.postid=p.postid";
        $where .= "and t.name in (" .
                  join(", ", map $blop->dbh->quote($_), @tags) .
                  ")\n";
    }

    if ($year) {
        $where .= "and year(p.published) = $year\n";
    }
    if ($month) {
        $where .= "and month(p.published) = $month\n";
    }
    if ($day) {
        $where .= "and day(p.published) = $day\n";
    }

    my $search = $cgi->param("s");
    if ($search && length($search)) {
        my $s = $blop->dbh->quote($search);
        $join = "left join tags t on t.postid=p.postid";
        $where .= "and (p.content regexp $s or p.title regexp $s or\n" .
                  "c.name regexp $s or t.name regexp $s)\n";
    }

    my $now = $blop->dbh->quote($blop->now->str);

    my $query = <<EOSQL;
select sql_calc_found_rows
    p.*,
    c.name category_str,
    c.url category_url
from
    posts p
    left join categories c on c.categoryid=p.categoryid
    $join
where
    p.published <= $now
    $where
group by p.postid
order by p.published desc
limit $limit
offset $offset
EOSQL
    my $sth = $blop->dbh->prepare($query);
    $sth->execute();
    my @posts;
    while (my $post = $sth->fetchrow_hashref()) {
        $post = bless $post, "Blop::Post";
        push @posts, $post;
    }

    $sth = $blop->dbh->prepare("select found_rows()");
    $sth->execute();
    my ($found_rows) = $sth->fetchrow_array();
    my $navigation = Blop::Navigation->new($limit, $offset, $found_rows, "post");

    print $blop->http_header();
    print $blop->template(
        "listing.html", category => $category, tags => \@tags, posts => \@posts,
        navigation => $navigation);
    exit;
}

sub post {
    my $categoryid = $cgi->param("cat");
    if ($categoryid) {
        $category = $blop->category(categoryid => $categoryid)
            or die "Invalid categoryid.\n";
    }
    $blop->{display_post} = $post;
    $blop->{display_category} = $category;
    print $blop->http_header();
    print $blop->template("post.html", post => $post, category => $category);
    exit;
}

sub page {
    $blop->{display_page} = $page;
    print $blop->http_header();
    print $blop->template("page.html", page => $page);
    exit;
}

sub not_found {
    $blop->{not_found} = 1;
    print $blop->http_header("Status" => "404 Not Found");
    print $blop->template("not-found.html", path => $path);
    exit;
}

