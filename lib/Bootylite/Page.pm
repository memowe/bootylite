package Bootylite::Page;

use Mojo::Base -base;
use Mojo::Asset::File;
use File::Spec::Functions 'splitpath';
use Time::Local 'timelocal';
use Mojo::ByteStream 'b';

has filename    => sub { die 'no file name given' };
has encoding    => 'utf-8';
has url         => sub { shift->_build_and_inject_filename_data->url };
has extension   => sub { shift->_build_and_inject_filename_data->extension };
has raw_content => sub { shift->_build_raw_content };
has meta        => sub { shift->_build_and_inject_content_data->meta };
has content     => sub { shift->_build_and_inject_content_data->content };

# inject url and extension from filename
sub _build_and_inject_filename_data {
    my $self = shift;

    # extract file name
    my (undef, undef, $filename) = splitpath($self->filename);

    # parse
    die 'filename not parseable: ' . $filename unless $filename =~ /^
        (\w+)       # url part
        \.([a-z]+)  # extension
    $/ix;

    # build url part and extension
    my $url  = lc $1;
    my $ext  = lc $2;

    # inject and chain
    return $self->url($url)->extension($ext);
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

    # arrify tags
    $meta{tags} = [ split /,\s*/ => $meta{tags} // '' ];

    # content is what meta isn't
    my $content = $raw;

    # inject and chain
    return $self->meta(\%meta)->content($content);
}

!! 42;
__END__
