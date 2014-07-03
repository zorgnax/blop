package Blop::Tag;
use strict;
use warnings;
use Blop;

sub new {
    my ($class, %args) = @_;
    return undef if !%args;
    my $blop = Blop::instance();
    my $where = join " and ", map "$_=" . $blop->dbh->quote($args{$_}), keys %args;
    my $sth = $blop->dbh->prepare(<<EOSQL);
select * from tags where $where
EOSQL
    $sth->execute();
    my $tag = $sth->fetchrow_hashref();
    return undef if !$tag;
    $tag = bless $tag, $class;
    return $tag;
}

1;

