#!/usr/bin/perl
use lib "../lib";
use blopcgi;

$blop->read_conf();
$blop->require_admin();

print "Content-Type: text/html; charset=utf-8\n\n";
print $blop->template("admin.html");

