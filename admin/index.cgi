#!/usr/bin/perl
use lib "../lib";
use blopcgi;

$blop->read_conf();
$blop->require_admin();

my $sth = $blop->dbh->prepare(<<EOSQL);
select sql_calc_found_rows * from log order by date desc, logid desc limit 15
EOSQL
$sth->execute();
my @logs;
while (my $log = $sth->fetchrow_hashref()) {
    $log = bless $log, "Blop::Log";
    push @logs, $log;
}

print $blop->http_header();
print $blop->template("admin.html", logs => \@logs);

