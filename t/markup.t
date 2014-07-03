#!/usr/bin/perl
use strict;
use warnings;
use lib "lib";
use Blop::Markup;
use Test::More;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

if (@ARGV) {
    my ($file) = @ARGV;
    open my $fh, "<", $file or die "$!\n";
    my $text = do {local $/; <$fh>};
    close $fh;
    print "$text\n";
    my $markup = Blop::Markup->new();
    my $obj = $markup->parse(\$text);
    print Dumper($obj) . "\n";
    my $html = $markup->display($obj);
    print "$html\n";
    exit;
}

for my $file (<t/markup/*.text>) {
    $file =~ m{([^/]+)\.[^\.]+$};
    my $test = $1;
    open my $fh, "<", $file or die "Can't open $file: $!\n";
    my $text = do {local $/; <$fh>};
    close $fh;
    my $markup = Blop::Markup->new();
    my $got = $markup->convert($text);
    open $fh, ">", "t/markup/$test.got"
        or die "Can't open t/markup/$test.got: $!\n";
    print $fh $got;
    close $fh;
    system "diff", "-up", "t/markup/$test.html", "t/markup/$test.got";
    ok !($? >> 8), $test;
}

done_testing;

