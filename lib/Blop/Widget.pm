package Blop::Widget;
use strict;
use warnings;
use Blop;

our %widgets = (
    categories => {name => "Categories", example => "[categories /]", block => 1, norecurse => 1, display => \&display_categories},
    tags => {name => "Tags", example => "[tags /]", block => 1, norecurse => 1, display => \&display_tags},
    search => {name => "Search", example => "[search /]", block => 1, norecurse => 1, display => \&display_search},
    archives => {name => "Date Archives", example => "[archives /]", block => 1, norecurse => 1, display => \&display_archives},
    "admin-links" => {name => "Admin Links", example => "[admin-links /]", block => 1, norecurse => 1, display => \&display_admin_links},
);

sub display_categories {
    my ($markup, $elem) = @_;
    return "" if $markup->{update};
    my $blop = Blop::instance() or return "";
    return $blop->template("categories-widget.html", elem => $elem);
}

sub display_search {
    my ($markup, $elem) = @_;
    return "" if $markup->{update};
    my $blop = Blop::instance() or return "";
    return $blop->template("search-widget.html", elem => $elem);
}

sub display_archives {
    my ($markup, $elem) = @_;
    return "" if $markup->{update};
    my $blop = Blop::instance() or return "";
    return $blop->template("archives-widget.html", elem => $elem);
}

sub display_admin_links {
    my ($markup, $elem) = @_;
    return "" if $markup->{update};
    my $blop = Blop::instance() or return "";
    return $blop->template("admin-links-widget.html", elem => $elem);
}

sub display_tags {
    my ($markup, $elem) = @_;
    return "" if $markup->{update};
    my $blop = Blop::instance() or return "";
    my $tags = $blop->tags;
    my $max_posts = 0;
    for my $tag (@$tags) {
        $max_posts = $tag->{posts} if $tag->{posts} > $max_posts;
    }
    for my $tag (@$tags) {
        $tag->{size} = int (8 + $tag->{posts} / $max_posts * 50) . "px";
    }
    return $blop->template("tags-widget.html", elem => $elem);
}

1;

