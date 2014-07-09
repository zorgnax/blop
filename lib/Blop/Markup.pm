package Blop::Markup;
use strict;
use warnings;
use Blop::BBCode;

sub new {
    my ($class, %args) = @_;
    my $self = bless \%args, $class;
    return $self;
}

sub parse {
    my ($self, $str) = @_;
    my @a;
    $$str =~ m/\G \n+/xmsgc;
    while (1) {
        my $preformatted = $self->parse_preformatted($str);
        if ($preformatted) {
            push @a, $preformatted;
            $self->parse_newlines($str, \@a);
            next;
        }
        if ($$str =~ m{\G ( ^> [^\n]* (\n ^> [^\n]*)* )}xmsgc) {
            my $text = $1;
            $text =~ s{^>[ ]?}{}gxms;
            my $quoted = $self->parse(\$text);
            push @a, {type => "quoted", content => $quoted};
            $self->parse_newlines($str, \@a);
            next;
        }
        my $header = $self->parse_header($str);
        if ($header) {
            push @a, $header;
            $self->parse_newlines($str, \@a);
            next;
        }
        if ($$str =~ m{\G \s* ((\*[ ]*){3,}|(-[ ]*){3,}) (\n|$) \n*}xmsgc) {
            push @a, {type => "hr"};
            next;
        }
        my $item = $self->parse_item($str, \@a);
        if ($item) {
            next;
        }
        my $paragraph = $self->parse_paragraph_content($str);
        if ($paragraph) {
            $self->add_paragraph($paragraph, \@a);
            $self->parse_newlines($str, \@a);
            next;
        }
        my $html = $self->parse_html_element($str);
        if ($html) {
            push @a, $html;
            $self->parse_newlines($str, \@a);
            next;
        }
        last;
    }
    return \@a;
}

sub add_paragraph {
    my ($self, $paragraph, $a) = @_;
    if (@{$paragraph->{content}} == 1) {
        my $item = $paragraph->{content}[0];
        if ($item && ref $item eq "HASH") {
            if ($item->{type} eq "bbcode") {
                $item->{paragraph} = 1;
                if ($item->{settings}{block}) {
                    push @$a, $item;
                    return;
                }
            }
        }
    }
    push @$a, $paragraph;
}

sub parse_newlines {
    my ($self, $str, $a) = @_;
    if ($$str =~ m/\G (\n+)/xmsgc) {
        push @$a, $1;
    }
}

sub parse_preformatted {
    my ($self, $str) = @_;
    my $retval = $$str =~ m{
        \G (
            ^ [ ]{4}[^\n]* (\n|\z)
            (([ ]{4}[^\n]*|[ ]*)(\n|\z))*
        )
    }xmsgc;
    return if !$retval;
    my $text = $1;
    if ($text =~ m{(\n+)$}) {
        $text = substr($text, 0, -length($1));
        pos($$str) -= length($1);
    }
    $text =~ s{^([ ]{4}|\t)}{}gxms;
    my $pre = {type => "preformatted", content => $text};
    return $pre;
}

sub parse_item {
    my ($self, $str, $a) = @_;
    my $bullet_rx = qr{^[ ]{0,3}([\*\+-]|\d+\.)[ ]+}xms;
    my $retval = $$str =~ m{
        \G $bullet_rx (.+?) ((?=\n$bullet_rx) | (?=\n\n\S) | $)
    }xsgc;
    return if !$retval;
    my $bullet = $1;
    my $text = $2;
    $$str =~ m/\G (\n*)/xmsgc;
    $text =~ s{^([ ]{0,4}|\t)}{}gxms;
    my $content = $self->parse(\$text);
    if ($content && ref $content eq "ARRAY") {
        if (@$content == 1 && $text !~ /\n/) {
            $content = $content->[0]{content};
        }
        elsif (@$content > 1 && $text =~ m{^[^\n]+\n$bullet_rx}x) {
            my $x = shift @$content;
            unshift @$content, $x->{content};
        }
    }
    my $item = {type => "item", bullet => $bullet, content => $content};
    if ($a && ref $a->[-1] && $a->[-1]{type} eq "list") {
        push @{$a->[-1]{content}}, $item;
    }
    else {
        my $list = {type => "list", content => [$item]};
        if ($item->{bullet} =~ /(\d+)/) {
            if ($1 != "1") {
                $list->{start} = $1;
            }
            $list->{ordered} = 1;
        }
        push @$a, $list;
    }
    return $item;
}

sub parse_header {
    my ($self, $str) = @_;
    my $header = {type => "header"};
    my $text;
    if ($$str =~ m{\G (.+) [ \t]* \n (=+|-+) [ \t]* $}xmgc) {
        my $underline = $2;
        $text = $1;
        $header->{level} = $underline =~ /=/ ? 1 : 2;
    }
    elsif ($$str =~ m{\G (\#{1,6}) [ \t]* (.+?) [ \t]* \#* [ \t]* $}xmgc) {
        my $leader = $1;
        $text = $2;
        $header->{level} = length($leader);
    }
    else {
        return;
    }
    my $content = $self->parse_paragraph_content(\$text);
    $header->{content} = $content->{content};
    return $header;
}

sub parse_paragraph_content {
    my ($self, $str) = @_;
    my $content = {type => "paragraph"};
    while (1) {
        my $save_pos = pos($$str);
        if ($$str =~ m{\G \\ (.) }xmsgc) {
            $self->add_str_to_content($content, $1);
            next;
        }
        my $html = $self->parse_html_element($str);
        if ($html && $html->{block}) {
            pos($$str) = $save_pos;
            last;
        }
        if ($html) {
            push @{$content->{content}}, $html;
            next;
        }
        my $bbcode = $self->parse_bbcode_element($str);
        if ($bbcode) {
            push @{$content->{content}}, $bbcode;
            next;
        }
        if ($$str =~ m{\G \*\* (?=\S)}xmsgc) {
            my $bc = $self->parse_paragraph_content($str);
            my $bold = {type => "bold", content => $bc->{content}};
            if ($$str =~ m{\G \*\*}xmsgc) {
                push @{$content->{content}}, $bold;
                next;
            }
            else {
                pos($$str) = $save_pos;
            }
        }
        if ($$str =~ m{\G \* (?!\*) (?=\S)}xmsgc) {
            my $ic = $self->parse_paragraph_content($str);
            my $italics = {type => "italics", content => $ic->{content}};
            if ($$str =~ m{\G \*}xmsgc) {
                push @{$content->{content}}, $italics;
                next;
            }
            else {
                pos($$str) = $save_pos;
            }
        }
        if ($$str =~ m{\G (`+) (.+?) \1}xmsgc) {
            my $code = $2;
            $code =~ s/^\s+|\s+$//g;
            push @{$content->{content}}, {type => "code", content => $code};
            next;
        }
        if ($$str =~ m{\G \b ((http|ftp)s?://[^'",<>\[\]\(\)\s]+) (?<!\.)}xmsgc) {
            push @{$content->{content}}, {type => "link", content => $1};
            next;
        }
        if ($$str =~ m{\G (?=\n[ ]{0,3}([\*\+-]|\d+\.)[ ]+) }xmsgc ||
            $$str =~ m{\G (?=\n>)}xmsgc) {
            last;
        }
        if ($$str =~ m{\G (?!\n(?:\n|$)) (?!\[\/) (?!\*) (.)}xmsgc ||
            $$str =~ m{\G (?<!\S) (\*)}xmsgc) {
            $self->add_str_to_content($content, $1);
            next;
        }
        last;
    }
    return if !$content->{content};
    return $content;
}

sub add_str_to_content {
    my ($self, $content, $str) = @_;
    if ($content->{content} && !ref $content->{content}[-1]) {
        $content->{content}[-1] .= $str;
    }
    else {
        push @{$content->{content}}, $str;
    }
}

sub parse_bbcode_element {
    my ($self, $str) = @_;
    return if $$str !~ m{\G \[ ([^/\s\]=]+) ([^\]]*?) (/?)\]}xmsgc;
    my $tag = $1;
    my $attr = $2;
    my $slash = $3;
    my $settings = Blop::BBCode::settings($self, $tag);
    return "[$tag$attr/]" if $slash && !$settings;
    my $elem = {type => "bbcode", tag => $tag, attr => $attr};
    $elem->{settings} = $settings;
    return $elem if $slash && $settings;
    if ($settings && $settings->{norecurse}) {
        $$str =~ m{\G (.*?) \[/\Q$tag\E\] }xmsgc;
        my $content = $1;
        $elem->{content} = $content;
        return $elem;
    }
    my $content = $self->parse_paragraph_content($str);
    $content = $content->{content};
    my $close;
    if ($$str =~ m{\G (\[/\Q$tag\E\]) }xmsgc) {
        $close = $1;
    }
    if (!$settings) {
        return ["[$tag$attr]", $content, $close];
    }
    if (!$close) {
        return [$elem, $content];
    }
    $elem->{content} = $content;
    return $elem;
}

sub parse_html_element {
    my ($self, $str) = @_;
    my $elem;
    if ($$str =~ m{\G < (!--) (.*?) -->}xmsgc) {
        my $tag = $1;
        my $attr = $2;
        $elem = {type => "html", tag => $tag, attr => $attr};
    }
    elsif ($$str =~ m{\G < ([^/\s>=]+) ([^>]*) />}xmsgc) {
        my $tag = $1;
        my $attr = $2;
        $elem = {type => "html", tag => $tag, attr => $attr};
    }
    elsif ($$str =~ m{\G < ([^/\s>=]+) ([^>]*) >}xmsgc) {
        my $tag = $1;
        my $attr = $2;
        my $content = $self->parse_html_content($str);
        $$str =~ m{\G </\Q$tag\E> }xmsgc;
        $elem = {type => "html", tag => $tag, attr => $attr, content => $content};
    }
    if ($elem && $elem->{tag} =~ m{^ (p|div|h[1-6]|blockquote|pre|table|
                                      dl|ol|ul|script|noscript|form|fieldset|
                                      iframe|math|ins|del|hr|!--) $}ix) {
        $elem->{block} = 1;
    }
    if ($elem && $elem->{content} && !$elem->{block}) {
        for my $item (@{$elem->{content}}) {
            if (ref $item && $item->{block}) {
                $elem->{block} = 1;
            }
        }
    }
    return $elem;
}

sub parse_html_content {
    my ($self, $str) = @_;
    my @a;
    while (1) {
        my $elem = $self->parse_html_element($str);
        if ($elem) {
            push @a, $elem;
            next;
        }
        if ($$str =~ m{\G (?!</)(.)}xmsgc) {
            if (defined $a[-1] && !ref $a[-1]) {
                $a[-1] .= $1;
            }
            else {
                push @a, $1;
            }
            next;
        }
        last;
    }
    return if !@a;
    return \@a;
}

sub convert {
    my ($self, $markup) = @_;
    return "" if !defined $markup;
    $markup =~ s/\r\n|\r|\n/\n/g;
    my $elem = $self->parse(\$markup);
    my $html = $self->display($elem);
    return $html;
}

sub escape_html {
    my ($str) = @_;
    $str ||= "";
    $str =~ s/&(?!\S+;)/&amp;/g;
    $str =~ s/>/&gt;/g;
    $str =~ s/</&lt;/g;
    return $str;
}

sub display {
    my ($self, $elem) = @_;
    if (!defined $elem) {
        return "";
    }
    if (!ref $elem) {
        return escape_html($elem);
    }
    if (ref $elem eq "ARRAY") {
        my $html = "";
        for my $item (@$elem) {
            $html .= $self->display($item);
        }
        return $html;
    }
    if ($elem->{type} eq "paragraph") {
        return $self->display_paragraph($elem);
    }
    elsif ($elem->{type} eq "list") {
        return $self->display_list($elem);
    }
    elsif ($elem->{type} eq "link") {
        return $self->display_link($elem);
    }
    elsif ($elem->{type} eq "hr") {
        return $self->display_hr($elem);
    }
    elsif ($elem->{type} eq "preformatted" || $elem->{type} eq "code") {
        return $self->display_code($elem);
    }
    elsif ($elem->{type} eq "html") {
        return $self->display_html($elem);
    }
    elsif ($elem->{type} eq "bold") {
        return $self->display_bold($elem);
    }
    elsif ($elem->{type} eq "italics") {
        return $self->display_italics($elem);
    }
    elsif ($elem->{type} eq "header") {
        return $self->display_header($elem);
    }
    elsif ($elem->{type} eq "quoted") {
        return $self->display_quoted($elem);
    }
    elsif ($elem->{type} eq "bbcode") {
        return Blop::BBCode::display($self, $elem);
    }
    die "UNKNOWN TYPE: $elem->{type}";
}

sub display_paragraph {
    my ($self, $elem) = @_;
    return "<p>" . $self->display($elem->{content}) . "</p>";
}

sub display_list {
    my ($self, $elem) = @_;
    my $tag = $elem->{ordered} ? "ol" : "ul";
    my $start = $elem->{start} ? " start=\"$elem->{start}\"" : "";
    my $html = "<$tag$start>\n";
    my $items = $elem->{content} || [];
    for my $item (@$items) {
        $html .= "<li>" . $self->display($item->{content}) . "</li>\n";
    }
    $html .= "</$tag>\n\n";
    return $html;
}

sub display_link {
    my ($self, $elem) = @_;
    return "<a href=\"$elem->{content}\">$elem->{content}</a>";
}

sub display_hr {
    my ($self, $elem) = @_;
    return "<hr/>\n\n";
}

sub display_code {
    my ($self, $elem) = @_;
    my $code = $elem->{content} || "";
    $code =~ s/&/&amp;/g;
    $code =~ s/>/&gt;/g;
    $code =~ s/</&lt;/g;
    my $html = "<code>$code</code>";
    $html = "<pre>$html</pre>" if $elem->{type} eq "preformatted";
    return $html;
}

sub display_html {
    my ($self, $elem) = @_;
    if ($elem->{tag} eq "!--") {
        return "<!--$elem->{attr}-->";
    }
    elsif ($elem->{content}) {
        return "<$elem->{tag}$elem->{attr}>" .
               $self->display($elem->{content}) . "</$elem->{tag}>";
    }
    else {
        return "<$elem->{tag}$elem->{attr}/>";
    }
}

sub display_bold {
    my ($self, $elem) = @_;
    return "<b>" . $self->display($elem->{content}) . "</b>";
}

sub display_italics {
    my ($self, $elem) = @_;
    return "<i>" . $self->display($elem->{content}) . "</i>";
}

sub display_header {
    my ($self, $elem) = @_;
    return "<h$elem->{level}>" . $self->display($elem->{content}) .
           "</h$elem->{level}>";
}

sub display_quoted {
    my ($self, $elem) = @_;
    return "<blockquote>" . $self->display($elem->{content}) . "</blockquote>";
}

1;

