package blopcgi;
use strict;
use warnings;
use Blop;

my $blop;

sub import {
    my ($class, %args) = @_;
    $blop = Blop->new(json => $args{json}, text => $args{text});
    $blop->find_bases();
    strict->import;
    warnings->import;
    no strict "refs";
    my $caller = caller;
    *{$caller . "::blop"} = \$blop;
    *{$caller . "::cgi"} = \$blop->cgi;
    *{$caller . "::dump"} = sub {$blop->dump(@_)};
}

sub simple_output_error {
    if ($blop && $blop->{json}) {
        print "Content-Type: application/json\n\n";
        print "{\"error\": 1, \"mesg\": " . Blop->escape_json_str(@_) . "}\n";
    }
    elsif ($blop && $blop->{text}) {
        print "Content-Type: text/plain\n\n";
        print "@_";
    }
    else {
        print "Status: 500 Internal Server Error\n";
        print "Content-Type: text/html; charset=utf-8\n\n";
        print Blop->escape_html(@_);
    }
    exit 255;
}

sub output_error {
    if ($blop && $blop->{json}) {
        print "Content-Type: application/json\n\n";
        print "{\"error\": 1, \"mesg\": " . Blop->escape_json_str(@_) . "}\n";
    }
    elsif ($blop && $blop->{text}) {
        print "Content-Type: text/plain\n\n";
        print "@_";
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
