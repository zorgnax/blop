package Blop::BBCode;
use strict;
use warnings;
use Blop;
use Image::Magick;

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
    my $url = $elem->{args}[0] || "";
    my $blop = Blop::instance();
    if ($blop && $url =~ m{^/}) {
        $url = "$blop->{urlbase}$url";
    }
    return "<a href=\"$url\"$title>$elem->{str}</a>";
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
    my $blop = Blop::instance() or return "";
    my $entry = $markup->{entry} or return "";
    my $html = "<ul class=\"listing\">\n";
    my $files = $entry->files;
    for my $file (@$files) {
        $html .= "<li><a href=\"$file->{fullurl}\">" .
                 $blop->escape_html($file->{name}) .
                 "</a> <span class=\"muted\">" . $file->{size} .
                 "</span></li>\n";
    }
    $html .= "</ul>";
    return $html;
}

sub update_gallery {
    my ($markup, $elem) = @_;
    my $entry = $markup->{entry} or return;
    if ($markup->{file}) {
        create_thumb($entry, $markup->{file}, $elem->{hash}{size}, "force");
        return;
    }
    my $files = $entry->files;
    for my $file (@$files) {
        create_thumb($entry, $file->{name}, $elem->{hash}{size});
    }
}

sub update_thumb {
    my ($markup, $elem) = @_;
    my $entry = $markup->{entry} or return;
    my $name = $elem->{args}[0] or return;
    if ($markup->{file}) {
        if ($markup->{file} eq $name) {
            create_thumb($entry, $name, $elem->{hash}{size}, "force");
        }
        return;
    }
    create_thumb($entry, $name, $elem->{hash}{size});
}

sub create_thumb {
    my ($entry, $file_name, $size, $force) = @_;
    return if $file_name !~ /\.(jpe?g|gif|png)$/i;
    my $blop = Blop::instance() or return;
    my %default = (small => "x125>", medium => "x250>", large => "700>");
    $size ||= "medium";
    my $geometry = $blop->{conf}{"gallery_$size"} || $default{$size} || $size;
    my $dir = create_thumb_dir($entry);
    my $thumb = "$dir/$file_name";
    $thumb =~ s{(\.\w+)$}{.$size$1};
    return if -e $thumb && !$force;
    my $magick = Image::Magick->new;
    my $path = $entry->content_path . "/$file_name";
    $magick->Read($path);
    $magick->Resize(geometry => $geometry);
    $magick->Write($thumb);
}

sub create_thumb_dir {
    my ($entry) = @_;
    my $dir = $entry->content_path;
    if (!-e $dir) {
        mkdir $dir or die "Can't mkdir $dir: $!\n";
    }
    $dir = "$dir/thumb";
    if (!-e $dir) {
        mkdir $dir or die "Can't mkdir $dir: $!\n";
    }
    return $dir;
}

sub display_gallery {
    my ($markup, $elem) = @_;
    my $entry = $markup->{entry} or return "";
    my $blop = Blop::instance();
    my $size = $elem->{hash}{size} || "medium";
    my $html = "<div class=\"gallery\">\n";
    my $files = $entry->files;
    for my $file (@$files) {
        next if $file->{name} !~ /\.(jpe?g|gif|png)$/i;
        my $thumb = $entry->content_fullurl . "/thumb/$file->{name}";
        $thumb =~ s{(\.\w+)$}{.$size$1};
        $html .= "<a href=\"" . $file->{fullurl} . "\"><img src=\"" .
                 $thumb . "\"/></a>\n";
    }
    $html .= "</div>\n";
    return $html;
}

sub display_thumb {
    my ($markup, $elem) = @_;
    my $entry = $markup->{entry} or return "";
    my $name = $elem->{args}[0] or return "";
    my $blop = Blop::instance();
    my $size = $elem->{hash}{size} || "medium";
    my $thumb = $entry->content_fullurl . "/thumb/$name";
    $thumb =~ s{(\.\w+)$}{.$size$1};
    my $url = $entry->content_fullurl . "/$name";
    my $html = "<a href=\"$url\"><img src=\"$thumb\"/></a>\n";
    return $html;
}

sub display_image {
    my ($markup, $elem) = @_;
    my $entry = $markup->{entry} or return "";
    my $name = $elem->{args}[0] or return "";
    my $url = $entry->content_fullurl . "/$name";
    my $html = "<img src=\"$url\"/>\n";
    return $html;
}

1;

