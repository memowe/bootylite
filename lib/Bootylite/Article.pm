package Bootylite::Article;

use Mojo::Base -base;
use Mojo::Asset::File;
use File::Spec::Functions 'splitpath';
use Time::Local 'timelocal';
use Mojo::ByteStream 'b';

# lazyness ftw
has filename    => sub { die 'no file name given' };
has encoding    => 'utf-8';
has time        => sub { shift->_build_and_inject_filename_data->time };
has url         => sub { shift->_build_and_inject_filename_data->url };
has extension   => sub { shift->_build_and_inject_filename_data->extension };
has raw_content => sub { shift->_build_raw_content };
has meta        => sub { shift->_build_and_inject_content_data->meta };
has first       => sub { shift->_build_and_inject_content_data->first };
has separator   => sub { shift->_build_and_inject_content_data->separator };
has second      => sub { shift->_build_and_inject_content_data->second };

# inject date and url from filename
sub _build_and_inject_filename_data {
    my $self = shift;

    # extract file name
    my (undef, undef, $filename) = splitpath($self->filename);

    # parse
    die 'filename not parseable: ' . $filename unless $filename =~ /^
        (\d\d\d\d)          # year
        -(\d\d)             # month
        -(\d\d)             # day
        (?:-(\d\d)-(\d\d))? # optional: hour and minute
        _(.*)               # url part
        \.([a-z]+)          # extension
    $/ix;

    # build date, url part and extension
    my $time = timelocal(0, $5 // 0, $4 // 0, $3, $2 - 1, $1);
    my $url  = lc $6;
    my $ext  = lc $7;

    # inject and chain
    return $self->time($time)
                ->url($url)
                ->extension($ext);
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

# split content in meta data, first part, separator and second part and inject
sub _build_and_inject_content_data {
    my $self = shift;
    my $raw  = $self->raw_content;

    # extract and kill meta data
    my %meta        = ();
    $meta{lc $1}    = $2 while $raw =~ s/^(\w+): (.+)\n+//;

    # arrify tags
    $meta{tags} = [ split /,\s*/ => $meta{tags} // '' ];

    # extract first part, separator and second part
    die 'content unparseable: ' . $raw unless $raw =~ /\A
        (.*?)               # first part
        (?:                 # optional second part
            ^\[cut\]        # separator start
            [ \t]*          # separator separator
            ([^\n]+)?       # optional separator text
            \n+             # separator end
            (.*)            # second part
        )?                  # end of optional second part
    \z/smx;
    
    # build
    my $first       = $1;
    my $separator   = $2;
    my $second      = $3;

    # inject and chain
    return $self->meta(\%meta)
                ->first($first)
                ->separator($separator)
                ->second($second);
}

!! 42;
__END__
