#!/usr/bin/perl
use lib "../lib";
use blopcgi;
use Blop::Visits;

$blop->read_conf();
$blop->require_admin();

my $sth = $blop->dbh->prepare(<<EOSQL);
select * from log order by date desc, logid desc limit 15
EOSQL
$sth->execute();
my @logs;
while (my $log = $sth->fetchrow_hashref()) {
    $log = bless $log, "Blop::Log";
    push @logs, $log;
}

my $visits = Blop::Visits::visits();

print $blop->http_header();
print $blop->template("admin.html", logs => \@logs, visits => $visits);

