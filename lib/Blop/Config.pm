package Blop::Config;
use strict;
use warnings;

sub read {
    my ($file) = @_;
    my %conf;
    open my $fh, "<", $file or die "Can't open $file: $!\n";
    while (my $line = <$fh>) {
        next if $line !~ /^\s*([\w_-]+)(\s*=\s*|\s+)(.+)$/;
        my $name = $1;
        my $value = $3;
        $value =~ s/^\s+|\s+$//g;
        $conf{$name} = $value;
    }
    close $fh;
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

