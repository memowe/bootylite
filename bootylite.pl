#!/usr/bin/env perl

use FindBin '$Bin';
use lib "$Bin/lib";
use Mojolicious::Lite;
use Bootylite;
use POSIX 'strftime';

# load configuration from bootylite.conf
my $config = plugin 'config';

# prepare for some booty action!
my $booty = Bootylite->new(
    articles_dir    => $config->{articles_dir},
    encoding        => $config->{file_encoding},
);

my $rs = $booty->renderers; # TODO whytf do I need this?

# article render helpers
app->helper(first2html => sub {
    $booty->render_article_part($_[1], 'first')
});
app->helper(second2html => sub {
    $booty->render_article_part($_[1], 'second')
});

# strftime helper for date and time formatting stuff
app->helper(strftime => sub { shift; strftime @_ });

get '/' => sub {
    my $self = shift;

    # get first articles
    my @articles = @{$booty->articles}[0 .. $config->{posts_per_page} - 1];

    # store
    $self->stash(articles => [ grep { defined } @articles ]);
} => 'index';

get '/tag/:tag' => sub {
    die 'TODO';
} => 'tag';

app->start;
__DATA__

@@ index.html.ep
% layout 'bootyblack';
% title 'Welcome to Bootylite';
<div id="articles">
% foreach my $article (@$articles) {
    <div class="article">
        <h2><%= $article->meta->{title} // 'No title' %></h2>
        <div class="meta">
            <span class="time">
                <%= strftime '%D %T', localtime $article->time =%>
            </span>,
            <span class="tags">Tags:
%       foreach my $tag (@{$article->meta->{tags} // []}) {
                <a href="<%= url_for 'tag', tag => $tag %>">
                    <%= $tag =%>
                </a>
%       }
            </span>
        </div>
        <div class="teaser"><%== first2html $article %></div>
    </div>
% }
</div>

@@ layouts/bootyblack.html.ep
<!doctype html><html>
  <head><title><%= title %></title></head>
  <body><%= content %></body>
</html>
