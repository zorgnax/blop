package Blop::Entry;
use strict;
use warnings;

sub sort_files {
    my ($self, $files, $sort) = @_;
    if ($sort && $sort =~ /^time(\s+desc)?$/) {
        my $desc = $1;
        if ($desc) {
            return [sort {$b->{time}{epoch} <=> $a->{time}{epoch}} @$files];
        }
        else {
            return [sort {$a->{time}{epoch} <=> $b->{time}{epoch}} @$files];
        }
    }
    elsif ($sort && $sort =~ /^(name|(name\s+desc)|(desc))$/) {
        my $desc = $2 || $3;
        if ($desc) {
            return [sort {$b->{name} cmp $a->{name}} @$files];
        }
        else {
            return [sort {$a->{name} cmp $b->{name}} @$files];
        }
    }
    else {
        return [sort {$a->{name} cmp $b->{name}} @$files];
    }
}

sub files {
    my ($self, $sort) = @_;
    my $files = [];
    my $blop = Blop::instance();
    my @paths = glob ($self->content_path . "/files/*");
    for my $path (@paths) {
        my @stat = stat($path);
        next if -d _;
        my $time = Blop::Date->new_epoch($stat[9]);
        $path =~ m{([^/]+)$};
        my $name = $1;
        my $file = {
            name => $name,
            path => $path,
            url => "/" . $self->content_url . "/files/$name",
            fullurl => $self->content_fullurl . "/files/$name",
            size => $blop->human_readable(-s $path),
            time => $time,
        };
        push @$files, $file;
    }
    $files = $self->sort_files($files, $sort);
    return $files;
}

1;
