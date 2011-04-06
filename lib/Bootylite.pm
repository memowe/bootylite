package Bootylite;

use Mojo::Base -base;
use Bootylite::Article;
use Mojo::Loader;

has articles_dir    => sub { die 'no articles directory given' };
has encoding        => 'utf-8';
has articles        => sub { shift->_build_articles };  # aref of Articles
has renderers       => sub { shift->_build_renderers }; # href: ext => renderer

sub _build_articles {
    my $self = shift;

    # glob article files
    my @articles;
    my @article_files = sort glob $self->articles_dir . '/*';

    # scan articles
    foreach my $filename (@article_files) {
        push @articles, Bootylite::Article->new(
            filename    => $filename,
            encoding    => $self->encoding,
        );
    }

    return \@articles;
}

sub _build_renderers {
    my $self = shift;

    # search for renderers
    my $loader      = Mojo::Loader->new;
    my $renderers   = $loader->search('Bootylite::Renderer');
    
    # build renderers
    my %renderer;
    foreach my $r (@$renderers) {

        # load
        my $error = $loader->load($r);
        die $error if $error;

        # really a renderer?
        my $renderer = $r->new;
        next unless $r->isa('Bootylite::Renderer');
        
        # register
        my $ext = lc $renderer->extension;
        $renderer{$ext} = $renderer;
    }

    # done!
    return \%renderer;
}

sub get_article {
    my ($self, $url) = @_;

    # scan articles
    foreach my $article (@{$self->articles}) {

        # found!
        return $article if $article->url eq lc $url;
    }

    # not found!
    return;
}

sub refresh {
    my $self = shift;

    # articles will load on demand lazily
    delete $self->{articles};
}

sub get_tags {
    my $self = shift;

    # collect tags
    my %amount;
    foreach my $article (@{$self->articles}) {
        $amount{$_}++ for @{$article->meta->{tags}};
    }

    return \%amount;
}

sub get_articles_by_tag {
    my $self    = shift;
    my $tag     = lc shift;

    # collect articles that match
    return grep { $tag ~~ @{$_->meta->{tags}} } @{$self->articles};
}

sub render_article_part {
    my ($self, $article, $part) = @_;

    # try to find the right renderer
    my $ext = $article->extension;
    my $renderer = $self->renderers->{$ext};
    die "couldn't find a $ext renderer" unless $renderer;

    # render
    my $text = $article->$part // return;
    return $renderer->render($text);
}

!! 42;

__END__
