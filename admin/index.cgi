#!/usr/bin/perl
use lib "../lib";
use blopcgi;

$blop->read_conf();
$blop->require_admin();

print $blop->http_header();
print $blop->template("admin.html");

