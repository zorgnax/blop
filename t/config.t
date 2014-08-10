#!/usr/bin/perl
use strict;
use warnings;
use lib "lib";
use Blop::Config;
use Blop::Test;
use Data::Dumper;

my $conf = Blop::Config::read("t/config/test.conf");

ok $conf->{foo} eq "bar", "simple";
ok $conf->{face} eq "palm", "equal sign";
ok $conf->{smokey} eq "a cat", "multiple word";
ok $conf->{one} eq "with leading whitespace", "two lines";
ok $conf->{desc} eq "a multiline\nconfig option\nis with leading whitespace", "multiple lines";

done_testing;

