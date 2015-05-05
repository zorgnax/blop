package Blop::Entry;
use strict;
use warnings;

sub get_file_paths {
    my ($self, $sort) = @_;
    my @paths = glob ($self->content_path . "/files/*");
    if ($sort && $sort =~ /^time(\s+desc)?$/) {
        my $desc = $1;
        my %mtime;
        for my $path (@paths) {
            $mtime{$path} = (stat($path))[9];
        }
        if ($desc) {
            @paths = sort {$mtime{$b} <=> $mtime{$a}} @paths;
        }
        else {
            @paths = sort {$mtime{$a} <=> $mtime{$b}} @paths;
        }
    }
    elsif ($sort && $sort =~ /^(name|(name\s+desc)|(desc))$/) {
        my $desc = $2 || $3;
        if ($desc) {
            @paths = reverse sort @paths;
        }
        else {
            @paths = sort @paths;
        }
    }
    else {
        @paths = sort @paths;
    }
    return \@paths;
}

1;
