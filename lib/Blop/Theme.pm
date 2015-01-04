package Blop::Theme;
use strict;
use warnings;
use Blop;

sub new {
    my ($class, $name) = @_;
    my $self = bless {name => $name}, $class;
    my $blop = Blop::instance();
    $self->{path} = "$blop->{base}themes/$name";
    return $self;
}

sub list {
    my ($class) = @_;
    my $blop = Blop::instance();
    my @themes;
    push @themes, Blop::Theme->new("default");
    for my $path (sort glob "$blop->{base}themes/*") {
        my ($name) = $path =~ m{([^/]+)$};
        next if $name eq "default";
        my $theme = Blop::Theme->new($name);
        push @themes, $theme;
    }
    return \@themes;
}

sub url {
    my ($self, $file) = @_;
    my $blop = Blop::instance();
    if (!$file) {
        return "$blop->{urlbase}/themes/$self->{name}";
    }
    elsif ($self->{name} && $self->{name} ne "default" &&
        -e "$blop->{base}themes/$self->{name}/$file") {
        return "$blop->{urlbase}/themes/$self->{name}/$file";
    }
    elsif (-e "$blop->{base}themes/default/$file") {
        return "$blop->{urlbase}/themes/default/$file";
    }
    return undef;
}

sub template_include_path {
    my ($self) = @_;
    my $path = "";
    my $blop = Blop::instance();
    if ($self->{name} && $self->{name} ne "default") {
        $path .= "$blop->{base}themes/$self->{name}:";
    }
    $path .= "$blop->{base}themes/default";
    return $path;
}

sub conf {
    my ($self) = @_;
    return $self->{conf} if exists $self->{conf};
    my $file = "$self->{path}/theme.conf";
    $self->{conf} = eval {Blop::Config::read($file)} || {};
    return $self->{conf};
}

sub desc {
    my ($self) = @_;
    return Blop::Markup->new->convert($self->conf->{desc});
}

sub date {
    my ($self) = @_;
    return $self->{date} if exists $self->{date};
    $self->{date} = Blop::Date->new($self->conf->{date});
    return $self->{date};
}

sub selected {
    my ($self) = @_;
    my $blop = Blop::instance();
    if ($blop->{conf}{theme} && $blop->{conf}{theme} eq $self->{name}) {
        return 1;
    }
    return 0;
}

sub body_classes {
    my ($self) = @_;
    my @out;
    my $blop = Blop::instance();
    my $path = $blop->cgi->param("path") || "";
    push @out, "home" if !length($path);
    push @out, "listing" if $blop->{listing};
    if ($blop->{display_post}) {
        push @out, "single";
        push @out, "postid-" . $blop->{display_post}{postid};
    }
    if ($blop->{display_year}) {
        push @out, "archive";
    }
    if ($blop->{display_tags}) {
        push @out, "tags";
    }
    if ($blop->{display_category}) {
        if ($blop->{display_category}{special}) {
            push @out, $blop->{display_category}{special};
        }
        else {
            push @out, "category";
            push @out, "categoryid-" . $blop->{display_category}{categoryid};
        }
    }
    if ($blop->{display_page}) {
        push @out, "page";
        push @out, "pageid-" . $blop->{display_page}{pageid};
    }
    if ($blop->cgi->param("s")) {
        push @out, "search";
    }
    if ($blop->{not_found}) {
        push @out, "error404";
    }
    if ($blop->admin) {
        push @out, "logged-in";
    }
    return join " ", @out;
}

sub page_menu {
    my ($self, %args) = @_;
    my $out = "<ul>\n";
    my $blop = Blop::instance();
    my $pages;
    if ($args{page}) {
        $pages = $args{page}{children} or return "";
    }
    else {
        $pages = $blop->pages;
    }
    for my $page (@$pages) {
        $out .= "<li class=\"page-item\">";
        $out .= "<a href=\"" . $page->fullurl . "\">" . $page->label . "</a>";
        $out .= $self->page_menu(page => $page);
        $out .= "</li>\n";
    }
    $out .= "</ul>\n";
    return $out;
}

1;
