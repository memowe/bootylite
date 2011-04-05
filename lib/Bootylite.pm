package Bootylite;

use Mojo::Base -base;
use Mojo::Asset::File;
use Bootylite::Article;

has articles_dir    => sub { die 'no articles directory given' };
has encoding        => 'utf-8';

# Bootylite::Article objects
has articles => sub {
    my $self = shift;

    # glob markdown files
    my @articles;
    my @md_files = sort glob $self->articles_dir . '/*.md';

    # scan articles
    foreach my $filename (@md_files) {
        push @articles, Bootylite::Article->new(
            filename    => $filename,
            encoding    => $self->encoding,
        );
    }

    return \@articles;
};

# get article by url
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

# refresh articles
sub refresh { delete shift->{articles} }

# get the whole tag cloud as a hashref: tagname => amount
sub get_tags {
    my $self = shift;

    # collect tags
    my %amount;
    foreach my $article (@{$self->articles}) {
        $amount{$_}++ for @{$article->meta->{tags}};
    }

    return \%amount;
}

# get all articles for a tag
sub get_articles_by_tag {
    my $self    = shift;
    my $tag     = lc shift;

    # collect articles that match
    return grep { $tag ~~ @{$_->meta->{tags}} } @{$self->articles};
}

!! 42;

__END__
