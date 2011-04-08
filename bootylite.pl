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

# date and time formatting
app->helper(strftime => sub { shift; strftime @_ });
app->helper(date => sub {
    shift->strftime($config->{date_format}, localtime shift->time)
});
app->helper(feed_date => sub {
    shift->strftime('%Y-%m-%dT%H:%M:%SZ', gmtime shift->time)
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

# pseudo static style sheets
get '/screen_style';
get '/print_style';

app->start;
__DATA__

@@ index.html.ep
% layout 'bootyblack';
% title config 'name';
<h1>Home</h1>
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
<h1>Tag <%= $tag %></h1>
%= include 'list_articles', single => 0

@@ tags.html.ep
% layout 'bootyblack';
% title config('name') . ' - Tagcloud';
<h1>All tags</h1>
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
%   if ($single) {
        <h1><%= $article->meta->{title} %></h1>
%   } else {
        <h2><a href="<%= url_for 'article', article_url => $article->url %>">
                <%= $article->meta->{title} =%>
        </a></h2>
%   }
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

@@ not_found.html.ep
% layout 'bootyblack';
% title config('name') . '- NOT FOUND!';
<h1>Whoops!</h1>
<p>I couldn't find what you were looking for. Sorry!</p>

@@ layouts/bootyblack.html.ep
<!doctype html>
<html>
<head>
<title><%= title %></title>
<link rel="stylesheet" type="text/css" media="screen" href="
    <%= url_for 'screen_style', format => 'css' =%>
">
<link rel="stylesheet" type="text/css" media="print" href="
    <%= url_for 'print_style', format => 'css' =%>
">
</head>
<body>
<div id="header"><%= config 'name' %></div>
<ul id="menu">
    <li><a href="<%= url_for 'index', format => 'html' %>">Home</a></li>
    <li><a href="<%= url_for 'tags' %>">Tags</a></li>
</ul>
<div id="main">
%= content
</div>
<address>
    &copy; <%= strftime '%Y', localtime %> <%= config 'author' %><br>
    <span id="powered">
        Powered by <a href="http://gihub.com/memowe/bootylite">Bootylite</a>
        on <a href="http://mojolicio.us/">Mojolicious::Lite</a>
        on <a href="http://perl.org/">Perl</a>
    </span>
</address>
</body>
</html>

@@ screen_style.css.ep
% my $left = '25%';
html, body { margin: 0; padding: 0 }
body { font-family: Helvetica, sans-serif; line-height: 145%; color: #ddd;
    background: black url('/mojolicious-pinstripe.gif') repeat }
#header { margin: 100px 0 50px <%= $left %>; font-size: 2em;
    letter-spacing: 2ex; color: white; text-shadow: 0 0 30px white }
#menu { display: block; margin: 0 0 10px <%= $left %>; padding: 0 }
#menu li { display: inline; margin: 0 15px 0 5px; padding: 0; list-style: none }
#menu a { text-decoration: none; color: #888; letter-spacing: .5ex }
#menu a:hover { color: white; text-shadow: 0 0 15px white }
#main { margin: 0 0 0 <%= $left %>; padding: 30px 50px 50px 50px;
    background-color: #333;
    border: solid #111; border-width: 2px 0 0 2px }
#main a { color: inherit }
#main h1 { font-size: 1.5em; font-weight: normal; background-color: #222;
    margin: 0 0 1em; padding: .5em .8em .4em; letter-spacing: .3ex }
#main h2 { font-size: 1.2em; font-weight: bold; border-bottom: 1px solid #999;
    margin: 1.5em 0 1em; padding: 0 0 .3em; letter-spacing: -.05ex }
#main h2 a { text-decoration: none; color: white }
.article .meta { font-size: .8em }
.article .tags a { text-decoration: none; font-weight: bold }
.article .tags a:hover { text-decoration: underline }
.article .teaser, .article #content { max-width: 80ex }
.article .teaser { font-weight: bold }
#articles .teaser { font-weight: normal }
#tags { margin: 3em 0 0 }
#tags a { font-weight: bold; text-decoration: none; padding: 0 .5ex }
#tags a:hover { color: white }
address { margin: 0 0 10px <%= $left %>; padding: 30px 50px; text-align: right;
    background-color: #444; border: solid #111; border-width: 0 0 2px 2px;
    font-size:.8em; letter-spacing:.2ex; font-style: normal; line-height: 130% }
address #powered { color: #888 }
address a { color: inherit }

@@ print_style.css.ep
html, body { margin: 0; padding: 0; color: black; background-color: white }
body { font-family: serif; line-height: 120% }
#header, #menu, address #powered { display: none }
#main, address { border: none }
a { text-decoration: none; color: black }
