package Blop::Section;
use strict;
use warnings;
use Blop;
use parent "Blop::Entry";

sub new {
    my ($class, $name) = @_;
    return undef if !$name || $name !~ /^(sidebar|footer|ps)$/;
    my $blop = Blop::instance();
    my $self = bless {name => $name}, $class;
    $self->{content} = $blop->{conf}{$name};
    return $self;
}

sub files {
    my ($self, $sort) = @_;
    my @files;
    my $blop = Blop::instance();
    my $paths = $self->get_file_paths($sort);
    for my $path (@$paths) {
        next if -d $path;
        $path =~ m{([^/]+)$};
        my $name = $1;
        my $file = {
            name => $name,
            path => $path,
            url => "/" . $self->content_url . "/files/$name",
            fullurl => $self->content_fullurl . "/files/$name",
            size => $blop->human_readable(-s $path),
        };
        push @files, $file;
    }
    return \@files;
}

sub content_url {
    my ($self) = @_;
    return $self->{content_url} if $self->{content_url};
    return "sect/$self->{name}";
}

sub content_path {
    my ($self) = @_;
    my $blop = Blop::instance();
    return $blop->{base} . $self->content_url;
}

sub content_fullurl {
    my ($self) = @_;
    my $blop = Blop::instance();
    return $blop->{urlbase} . "/" . $self->content_url;
}

sub parsed_content {
    my ($self) = @_;
    my $markup = Blop::Markup->new(entry => $self);
    return $markup->convert($self->{content});
}

sub update_content {
    my ($self, %args) = @_;
    my $markup = Blop::Markup->new(entry => $self, update => 1, %args);
    return $markup->convert($self->{content});
}

1;

