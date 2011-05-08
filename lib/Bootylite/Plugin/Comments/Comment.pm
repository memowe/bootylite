package Bootylite::Plugin::Comments::Comment;

use Mojo::Base -base;
use Mojo::Asset::File;
use File::Spec::Functions 'splitpath';
use Time::Local 'timelocal';
use Mojo::ByteStream 'b';

has article_url => sub { die 'no article_url given' };
has filename    => sub { die 'no file name given' };
has encoding    => 'utf-8';
has render_cb   => sub { \&_default_render };
has time        => sub { shift->_build_time };
has raw_content => sub { shift->_build_raw_content };
has meta        => sub { shift->_build_and_inject_content_data->meta };
has html        => sub { shift->_build_and_inject_content_data->html };

# default renderer
sub _default_render {
    my $str = shift;

    # no html allowed
    $str = b($str)->html_escape;

    # line break cleanup
    $str =~ s/^\n+//;
    $str =~ s/\n*$/\n\n/;
    $str =~ s/\n\n+/\n\n/;

    # double line breaks: <p></p>
    $str =~ s|(.*?)\n\n|<p>$1</p>|sg;

    # single line breaks: <br>
    $str =~ s/\n/<br>\n/g;

    # prettify
    $str =~ s|</p>|</p>\n\n|g;

    return $str;
}

# build time from filename
sub _build_time {
    my $self = shift;

    # extract file name
    my (undef, undef, $filename) = splitpath($self->filename);

    # parse
    die 'filename not parseable: ' . $filename unless $filename =~ /^
        (\d\d\d\d)  # year
        -(\d\d)     # month
        -(\d\d)     # day
        -(\d\d)     # hour
        -(\d\d)     # minute
        -(\d\d)     # second
    /ix;

    # build time
    return timelocal($6, $5, $4, $3, $2 - 1, $1);
}

# slurp that shit
sub _build_raw_content {
    my $self = shift;

    # slurp
    my $file    = Mojo::Asset::File->new(path => $self->filename);
    my $encoded = $file->slurp;

    # decode
    return b($encoded)->decode($self->encoding)->to_string;
}

# inject meta data and content
sub _build_and_inject_content_data {
    my $self = shift;
    my $raw  = $self->raw_content;

    # extract and kill meta data
    my %meta        = ();
    $meta{lc $1}    = $2 while $raw =~ s/^(\w+): (.+)\n+//;

    # render content
    my $html = $self->render_cb->($raw);

    # inject and chain
    return $self->meta(\%meta)->html($html);
}

# save raw_content to disk
sub save {
    my $self = shift;

    # preparation
    my $mode = sprintf '>:encoding(%s)', $self->encoding;
    open my $cfh, $mode, $self->filename or die $!;

    # save
    print $cfh $self->raw_content;
    close $cfh;

    # enable chaining
    return $self;
}

!! 42;

__END__
