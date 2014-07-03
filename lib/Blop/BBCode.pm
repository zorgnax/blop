package Blop::BBCode;
use strict;
use warnings;

my %bbcode = (
    hr => {block => 1, display => \&display_hr},
    link => {display => \&display_link},
    code => {block => 1, norecurse => 1, display => \&display_code},
    listing => {block => 1, norecurse => 1, display => \&display_listing},
    gallery => {block => 1, norecurse => 1, update => \&update_gallery,
                display => \&display_gallery},
    thumb => {norecurse => 1, update => \&update_thumb, display => \&display_thumb},
    image => {norecurse => 1, display => \&display_image},
);

my @bbcode_rx = (
    {rx => qr{code-\S+}, settings => "code"},
);

sub settings {
    my ($markup, $tag) = @_;
    return if !defined $tag;
    return $bbcode{$tag} if $bbcode{$tag};
    for my $bbr (@bbcode_rx) {
        next if $tag !~ /$bbr->{rx}/;
        if (ref $bbr->{settings}) {
            return $bbr->{settings};
        }
        else {
            return $bbcode{$bbr->{settings}};
        }
    }
    return;
}

sub display {
    my ($markup, $elem) = @_;
    if ($elem->{settings}{update} || $elem->{settings}{display}) {
        parse_attr($markup, $elem);
    }
    if ($markup->{update} && $elem->{settings}{update}) {
        $elem->{settings}{update}($markup, $elem);
    }
    if ($elem->{settings}{display}) {
        return $elem->{settings}{display}($markup, $elem);
    }
    elsif ($elem->{content}) {
        return "[$elem->{tag}$elem->{attr}]" .
               $markup->display($elem->{content}) . "[/$elem->{tag}]";
    }
    else {
        return "[$elem->{tag}$elem->{attr}/]";
    }
}

sub parse_attr {
    my ($markup, $elem) = @_;
    if (!$elem->{norecurse}) {
        $elem->{str} = $markup->display($elem->{content});
    }
    my $attr = $elem->{attr};
    while (1) {
        $attr =~ m{\G\s*}xmsgc;
        my ($key, $value);
        if ($attr =~ m{\G ([^\s=]+) \s* = \s*}xmsgc) {
            $key = $1;
        }
        if ($attr =~ m{\G "((\\"|[^"])*)"}xmsgc ||
            $attr =~ m{\G '((\\'|[^'])*)'}xmsgc ||
            $attr =~ m{\G (\S+)}xmsgc) {
            $value = $1;
            $value =~ s/\\(.)/$1/g;
        }
        else {
            last;
        }
        if ($key) {
            $elem->{hash}{$key} = $value;
        }
        else {
            push @{$elem->{args}}, $value;
        }
    }
}

sub display_hr {
    my ($markup, $elem) = @_;
    return "<hr/>";
}

sub display_link {
    my ($markup, $elem) = @_;
    my $title = "";
    if ($elem->{args}[1]) {
        $title = $elem->{args}[1];
        $title =~ s/"/&quot;/g;
        $title = " title=\"$title\"";
    }
    return "<a href=\"$elem->{args}[0]\"$title>$elem->{str}</a>";
}

sub display_code {
    my ($markup, $elem) = @_;
    my $code = $elem->{content} || "";
    $code =~ s/&/&amp;/g;
    $code =~ s/>/&gt;/g;
    $code =~ s/</&lt;/g;
    $code =~ s/"/&quot;/g;
    my $html = "<code>$code</code>";
    $html = "<pre>$html</pre>" if $elem->{paragraph};
    return $html;
}

sub display_listing {
    my ($markup, $elem) = @_;
    return "TODO LISTING";
}

sub update_gallery {
    my ($markup, $elem) = @_;
}

sub display_gallery {
    my ($markup, $elem) = @_;
    return "TODO GALLERY";
}

sub update_thumb {
    my ($markup, $elem) = @_;
}

sub display_thumb {
    my ($markup, $elem) = @_;
    return "TODO THUMB";
}

sub display_image {
    my ($markup, $elem) = @_;
    return "TODO IMAGE";
}

1;

