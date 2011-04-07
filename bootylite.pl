#!/usr/bin/env perl

use FindBin '$Bin';
use lib "$Bin/lib";
use Mojolicious::Lite;
use Bootylite;
use POSIX 'strftime';
use List::Util 'sum';

# load configuration from bootylite.conf
my $config = plugin 'config';

# use the right character encoding
plugin charset => {charset => $config->{encoding}};

# prepare for some booty action!
my $booty = Bootylite->new(
    articles_dir    => $config->{articles_dir},
    encoding        => $config->{file_encoding},
);
app->helper(booty => sub { $booty });

# article render helpers
app->helper(first2html => sub {
    shift->booty->render_article_part(shift, 'first')
});
app->helper(second2html => sub {
    shift->booty->render_article_part(shift, 'second')
});

# date and time formatting stuff
app->helper(date => sub {
    strftime $config->{date_format}, localtime $_[1]->time
});

# date and time formatting for the feed
app->helper(feed_date => sub {
    strftime '%Y-%m-%dT%H:%M:%SZ', gmtime $_[1]->time
});

# home page redirect
get '/' => sub { shift->redirect_to('index', format => 'html') };

# home page (html or feed)
get '/index' => sub {
    my $self = shift;

    # get articles
    my $articles = $self->booty->articles;

    # store reverse
    $self->stash(articles => [reverse @{$self->booty->articles}]);
} => 'index';

# one article
get '/article/:article_url' => sub {
    my $self = shift;

    # get that article
    my $url     = $self->param('article_url');
    my $article = $self->booty->get_article($url);
    $self->render_not_found and return unless $article;

    # store
    $self->stash(article => $article);
} => 'article';

# articles by tag
get '/tag/:tag' => sub {
    my $self = shift;

    # get articles
    my $tag         = $self->param('tag');
    my @articles    = $self->booty->get_articles_by_tag($tag);
    $self->render_not_found and return unless @articles;

    # store
    $self->stash(
        tag         => $tag,
        articles    => \@articles,
    );
} => 'tag';

# get the whole tag cloud
get '/tags' => sub {
    my $self = shift;

    # get tag cloud: {tag => amount}
    my $amount  = $self->booty->get_tags;
    my $sum     = sum values %$amount;

    # store
    $self->stash(
        tags    => [keys %$amount],
        amount  => $amount,
        sum     => $sum,
    );
} => 'tags';

app->start;
__DATA__

@@ index.html.ep
% layout 'bootyblack';
% title config 'name';
<h1><%= config 'name' %></h1>
%= include 'list_articles', single => 0

@@ index.xml.ep
<?xml version="1.0" encoding="<%= config 'encoding' %>"?>
<feed xmlns="http://www.w3.org/2005/Atom">
    <id><%= url_for('index', format => 'html')->to_abs %></id>
    <title><%= config 'name' %></title>
    <updated><%= feed_date $articles->[-1] %></updated>
    <author><name><%= config 'author' %></name></author>
    <link rel="self" href="<%= url_for('index', format => 'xml')->to_abs %>"/>
    <generator>Bootylite</generator>
% foreach my $article (@$articles) {
%   my $url = url_for 'article', article_url => $article->url;
    <entry>
        <id><%= $url->to_abs %></id>
        <title><%= $article->meta->{title} %></title>
        <updated><%= feed_date $article %></updated>
        <author><name><%= config 'author' %></name></author>
        <link rel="alternate" href="<%= $url->to_abs %>"/>
        <summary type="html"><%= first2html $article =%></summary>
%   foreach my $tag (@{$article->meta->{tags}}) {
        <category term="<%= $tag %>"/>
%   }
    </entry>
% }
</feed>

@@ article.html.ep
% layout 'bootyblack';
% title config('name') . ' - ' . $article->meta->{title};
%= include 'show_article', article => $article, single => 1

@@ tag.html.ep
% layout 'bootyblack';
% title config('name') . ' - ' . $tag;
%= include 'list_articles', single => 0

@@ tags.html.ep
% layout 'bootyblack';
% title config('name') . ' - Tagcloud';
<div id="tags">
% foreach my $tag (@$tags) {
%   my $ratio   = config('tag_cloud_scale') * $amount->{$tag} / $sum;
%   my $size    = sprintf '%2.2fem', $ratio;
%   my $url     = url_for 'tag', tag => $tag;
    <a href="<%= $url %>" style="font-size: <%= $size %>"><%= $tag %></a>
% }
</div>

@@ list_articles.html.ep
<div id="articles">
% foreach my $article (@$articles) {
%=  include 'show_article', article => $article, single => $single
% }
</div>

@@ show_article.html.ep
    <div class="article">
% my $hl_tag = $single ? 'h1' : 'h2';
        <<%= $hl_tag %>>
%   unless ($single) {
            <a href="<%= url_for 'article', article_url => $article->url %>">
%   }
                <%= $article->meta->{title} =%>
%   unless ($single) {
            </a>
%   }
        </<%= $hl_tag %>>
        <div class="meta">
            <span class="time"><%= date $article %></span>,
            <span class="tags">Tags:
%       foreach my $tag (@{$article->meta->{tags} // []}) {
                <a href="<%= url_for 'tag', tag => $tag %>"><%= $tag =%></a>
%       }
            </span>
        </div>
        <div class="teaser"><%== first2html $article %></div>
%   if ($single) {
        <div id="content"><%== second2html $article %></div>
%   } else {
%       if ($article->second) {
        <p><a href="<%= url_for 'article', article_url => $article->url %>">
            <%= $article->separator // config 'separator' =%>
        </a></p>
%       }
%   }
    </div>

@@ layouts/bootyblack.html.ep
<!doctype html><html>
  <head><title><%= title %></title></head>
  <body><%= content %></body>
</html>
