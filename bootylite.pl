#!/usr/bin/env perl

use FindBin '$Bin';
use lib "$Bin/lib";
use Mojolicious::Lite;
use Bootylite;
use Text::Markdown 'markdown';
use POSIX 'strftime';

my $config = plugin 'config';

my $booty = Bootylite->new(
    articles_dir    => $config->{articles_dir},
    encoding        => $config->{file_encoding},
);

app->helper(markdown => sub { markdown $_[1] });
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
%   my $teaser = $article->teaser // $article->content;
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
        <div class="teaser"><%== markdown $teaser %></div>
    </div>
% }
</div>

@@ layouts/bootyblack.html.ep
<!doctype html><html>
  <head><title><%= title %></title></head>
  <body><%= content %></body>
</html>
