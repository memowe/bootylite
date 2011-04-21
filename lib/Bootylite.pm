package Bootylite;

use Mojo::Base -base;
use Bootylite::Article;
use Mojo::Loader;

has articles_dir    => sub { die 'no articles directory given' };
has pages_dir       => sub { die 'no pages directory given' };
has encoding        => 'utf-8';
has articles        => sub { shift->_build_articles };  # aref of Articles
has pages           => sub { shift->_build_pages };     # aref of Pages
has renderers       => sub { shift->_build_renderers }; # href: ext => renderer

sub _build_articles {
    my $self = shift;

    # glob article files
    my @articles;
    my @article_files   = sort glob $self->articles_dir . '/*';
    @article_files      = grep { ! /\.bak$/ } @article_files;

    # scan articles
    foreach my $filename (@article_files) {
        push @articles, Bootylite::Article->new(
            filename    => $filename,
            encoding    => $self->encoding,
        );
    }

    # link articles
    foreach my $i (0 .. $#articles) {
        $articles[$i]->prev($articles[$i-1]) if $i > 0;
        $articles[$i]->next($articles[$i+1]) if $i < $#articles;
    }

    return \@articles;
}

sub _build_pages {
    my $self = shift;

    # glob page files
    my @pages;
    my @page_files  = glob $self->pages_dir . '/*';
    @page_files     = grep { ! /\.bak$/ } @page_files;

    # scan pages
    foreach my $filename (@page_files) {
        push @pages, Bootylite::Page->new(
            filename    => $filename,
            encoding    => $self->encoding,
        );
    }

    # sort with sort meta header
    @pages = sort { $a->meta->{sort} <=> $b->meta->{sort} } @pages;

    return \@pages;
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

sub get_page {
    my ($self, $url) = @_;

    # scan pages
    foreach my $page (@{$self->pages}) {

        # found!
        return $page if $page->url eq lc $url;
    }

    # not found!
    return;
}

sub refresh {
    my $self = shift;

    # they will load on demand lazily
    delete $self->{articles};
    delete $self->{pages};
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
    my @matching;
    foreach my $article (@{$self->articles}) {
        my @tags = @{$article->meta->{tags}};
        push @matching, $article if $tag ~~ @tags;
    }

    return @matching;
}

sub render_page_part {
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
