package blopcgi;
use strict;
use warnings;
use Blop;
use Cwd;

my $blop;

sub import {
    my ($class, %args) = @_;
    my ($base, $urlbase, $pluginbase, $pluginurlbase) = find_bases();
    $blop = Blop->new(base => $base, urlbase => $urlbase, js => $args{js});
    strict->import;
    warnings->import;
    no strict "refs";
    my $caller = caller;
    *{$caller . "::blop"} = \$blop;
    *{$caller . "::cgi"} = \$blop->cgi;
    *{$caller . "::dump"} = sub {$blop->dump(@_)};
}

sub find_bases {
    my $base = "";
    my $urlbase = $ENV{SCRIPT_NAME} || "";
    $urlbase =~ s{/+[^/]+$}{};
    my $rel = "";
    my $dir = Cwd::cwd;
    while (length($dir)) {
        if (-e "$dir/.blop" && -e "$dir/index.cgi") {
            last;
        }
        $dir =~ s{(/+[^/]+)$}{};
        $rel = "$1$rel";
        $base .= "../";
        $urlbase =~ s{/+[^/]+$}{};
    }
    my $pluginbase;
    my $pluginurlbase;
    if ($rel =~ m{^(/plugin/[^/]+)}) {
        $pluginurlbase = "$urlbase$1";
        $pluginbase = $base;
        $pluginbase =~ s{../../$}{};
    }
    return ($base, $urlbase, $pluginbase, $pluginurlbase);
}

sub simple_output_error {
    if ($blop && $blop->{js}) {
        print "Content-Type: application/json\n\n";
        print "{\"error\": 1, \"mesg\": " . Blop->escape_json_str(@_) . "}\n";
    }
    else {
        print "Status: 500 Internal Server Error\n";
        print "Content-Type: text/html; charset=utf-8\n\n";
        print Blop->escape_html(@_);
    }
    exit 255;
}

sub output_error {
    if ($blop && $blop->{js}) {
        print "Content-Type: application/json\n\n";
        print "{\"error\": 1, \"mesg\": " . Blop->escape_json_str(@_) . "}\n";
    }
    else {
        print "Status: 500 Internal Server Error\n";
        print "Content-Type: text/html; charset=utf-8\n\n";
        print $blop->template("error.html", error => Blop->escape_html(@_));
    }
    exit 255;
}

# Some features are broken until after compilation
BEGIN {$SIG{__DIE__} = sub {simple_output_error(@_) if !$^S}}
INIT  {$SIG{__DIE__} = sub {output_error(@_) if !$^S}}

1;
