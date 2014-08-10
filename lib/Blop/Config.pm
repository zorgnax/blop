package Blop::Config;
use strict;
use warnings;

sub read {
    my ($file) = @_;
    my %conf;
    open my $fh, "<", $file or die "Can't open $file: $!\n";
    my $name = "";
    while (my $line = <$fh>) {
        if ($line =~ /^([\w_-]+)(\s*=\s*|\s+)(.*)$/) {
            $name = $1;
            $conf{$name} = $3;
        }
        elsif ($name && $line =~ /^[ \t]+(.*)$/) {
            $conf{$name} .= "\n$1";
        }
        elsif ($name && $line =~ /^[ \t]*$/) {
            $conf{$name} .= "\n";
        }
    }
    close $fh;
    for (values %conf) {
        s/^\s+|\s+$//g;
    }
    return \%conf;
}

sub write {
    my ($file, $conf) = @_;
    open my $fh, ">", $file or die "Can't open $file: $!\n";
    for my $name (sort keys %$conf) {
        print $fh "$name = $conf->{$name}\n";
    }
    close $fh;
}

1;

