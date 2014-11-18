package Blop::Backup;
use strict;
use warnings;
use Blop;

sub dump_database {
    my $blop = Blop::instance;
    my $conf = Blop::Config::read("$blop->{base}blop.conf");
    my $sth = $blop->dbh->prepare("show tables");
    $sth->execute;
    while (my ($table) = $sth->fetchrow_array) {
        my $file = "$blop->{base}admin/priv/$table.sql";
        my $size1 = -s $file || 0;
        print "Dumping $table to $file";
        my @cmd = ("mysqldump", "-h", $conf->{dbhost}, "-u", $conf->{dbuser},
                   "-p$conf->{dbpass}", $conf->{dbtable}, $table,
                   "--skip-extended-insert");
        open my $cmd_fh, "-|", @cmd or die "$!\n";
        open my $fh, ">", $file or die "Can't open $file: $!\n";
        while (my $line = <$cmd_fh>) {
            print $fh $line;
        }
        close $fh;
        close $cmd_fh;
        my $size2 = -s $file;
        print " change: " . $blop->human_readable($size2 - $size1) . "\n";
    }
}

1;

