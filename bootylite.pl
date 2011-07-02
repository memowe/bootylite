#!/usr/bin/env perl

use FindBin '$Bin';
use lib "$Bin/lib";
use Mojolicious::Lite;
use Bootylite;
use Bootylite::Plugins;
use POSIX 'strftime';
use List::Util qw(min max);

# load configuration from bootylite.conf
my $config = plugin 'config';

# set cookie secret
app->secret($config->{secret} // 'Bootylite');

# use the right character encoding
plugin charset => {charset => $config->{encoding}};

# prepare for some booty action!
my $booty = Bootylite->new(
    articles_dir    => $config->{articles_dir},
    pages_dir       => $config->{pages_dir},
    drafts_dir      => $config->{drafts_dir},
    encoding        => $config->{file_encoding},
);
app->helper(booty => sub { $booty });

# page/article render helpers
app->helper(first2html => sub {
    shift->booty->render_page_part(shift, 'first')
});
app->helper(second2html => sub {
    shift->booty->render_page_part(shift, 'second')
});
app->helper(content2html => sub {
    shift->booty->render_page_part(shift, 'content')
});

# date and time formatting
app->helper(strftime => sub { shift; strftime @_ });
app->helper(date => sub {
    shift->strftime($config->{date_format}, localtime shift->time)
});
app->helper(feed_date => sub {
    shift->strftime('%Y-%m-%dT%H:%M:%SZ', gmtime shift->time)
});

# register plugins
my $plugins = Bootylite::Plugins->new;
if ($config->{plugins} and ref $config->{plugins} eq 'HASH') {
    while (my ($name, $conf) = each %{$config->{plugins}}) {
        $plugins->add($name, $conf);
    }
}

# plugin startup hook
$plugins->call_startup(app);

# home page
get '/' => sub {
    my $self = shift;

    # get first page of articles
    my $perpage     = $self->config->{articles_per_page};
    my @articles    = reverse @{$self->booty->articles};
    my $max         = min($perpage - 1, $#articles);
    my @first_page  = @articles[0 .. $max];

    # store
    $self->stash(
        articles        => \@first_page,
        has_next_page   => $perpage < @articles,
    );

    $plugins->call_index($self);
} => 'index';

# paged "home" page
get '/page/:page' => [page => qr/[1-9]\d*/] => sub {
    my $self = shift;

    # get articles
    my @articles = reverse @{$self->booty->articles};

    # in range?
    my $perpage = $self->config->{articles_per_page};
    my $page    = $self->param('page');
    $self->render_not_found and return
        unless ($page - 1) * $perpage < @articles;

    # calculate
    my $start       = ($page - 1) * $perpage;
    my $end         = min($start + $perpage - 1, $#articles);
    my @paged       = @articles[$start .. $end];
    my $prev_page   = $page > 1 ? $page - 1 : undef;
    my $next_page   = $end < $#articles ? $page + 1 : undef;

    # store
    $self->stash(
        articles    => \@paged,
        prev_page   => $prev_page,
        next_page   => $next_page,
    );

    $plugins->call_paged($self);
} => 'paged';

# one article
get '/articles/:article_url' => sub {
    my $self = shift;

    # get that article
    my $url     = $self->param('article_url');
    my $article = $self->booty->get_article($url);
    $self->render_not_found and return unless $article;

    # store
    $self->stash(article => $article);

    $plugins->call_article($self);
} => 'article';

# archive
get '/articles' => sub {
    my $self = shift;

    # get all articles
    my $articles = $self->booty->articles;

    # order by year, month
    my %articles;
    foreach my $article (@$articles) {

        # extract year, month
        my ($y, $m) = (localtime $article->time)[5, 4];
        my $year    = $y + 1900;
        my $month   = $m + 1;

        # create array on demand
        $articles{$year}{$month} = []
            unless defined $articles{$year}{$month};

        # insert
        push @{$articles{$year}{$month}}, $article;
    }

    # store
    $self->stash(articles => \%articles);

    $plugins->call_archive($self);
} => 'archive';

# articles by tag
get '/tag/:tag' => sub {
    my $self = shift;

    # get articles
    my $tag         = $self->param('tag');
    my @articles    = reverse $self->booty->get_articles_by_tag($tag);
    $self->render_not_found and return unless @articles;

    # store
    $self->stash(
        tag         => $tag,
        articles    => \@articles,
    );

    $plugins->call_tag($self);
} => 'tag';

# get the whole tag cloud
get '/tags' => sub {
    my $self = shift;

    # get tag cloud: {tag => amount}
    my $amount  = $self->booty->get_tags;

    # store
    $self->stash(
        tags    => [sort keys %$amount],
        amount  => $amount,
    );

    $plugins->call_tags($self);
} => 'tags';

# get a page
get '/pages/:page_url' => sub {
    my $self = shift;

    # get that page
    my $url     = $self->param('page_url');
    my $page    = $self->booty->get_page($url);
    $self->render_not_found and return unless $page;

    # store
    $self->stash(page => $page);

    $plugins->call_page($self);
} => 'page';

# atom feed
get '/feed' => sub {
    my $self = shift;

    # get articles
    my @articles = @{$self->booty->articles};

    # store
    $self->stash(articles => \@articles);

    $plugins->call_feed($self);
} => 'feed';

# atom feed by tag
get '/feed/:tag' => sub {
    my $self = shift;

    # get articles
    my $tag         = $self->param('tag');
    my @articles    = $self->booty->get_articles_by_tag($tag);
    $self->render_not_found and return unless @articles;

    # store
    $self->stash(articles => \@articles);

    $plugins->call_tag_feed($self);
} => 'tag_feed';

# render articles before publishing
get $config->{drafts_url} . '/:draft_url' => sub {
    my $self = shift;

    # get draft
    my $url     = $self->param('draft_url');
    my $draft   = $self->booty->get_draft($url);
    $self->render_not_found and return unless $draft;

    # store
    $self->stash(draft => $draft);

    $plugins->call_draft($self);
} => 'draft';

# refresh the bootylite
get $config->{refresh_url} => sub {
    my $self = shift;

    # refresh
    $self->booty->refresh;

    # done.
    $plugins->call_refresh($self);
    $self->res->headers->content_type('text/html');
    $self->render_text('Done');
} => 'refresh';

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
% if ($has_next_page) {
<p id="pager"><a href="<%= url_for 'paged', page => 2 %>">Earlier</a></p>
% }

@@ paged.html.ep
% layout 'bootyblack';
% title config('name') . ' - Page ' . $page;
<h1>Page <%= $page %></h1>
%= include 'list_articles', single => 0
<p id="pager">
% if (defined $prev_page) {
    <a href="<%= url_for 'paged', page => $prev_page %>">Later</a>
% }
% if (defined $prev_page and defined $next_page) {
    &ndash;
% }
% if (defined $next_page) {
    <a href="<%= url_for 'paged', page => $next_page %>">Earlier</a>
% }
</p>

@@ article.html.ep
% layout 'bootyblack';
% title config('name') . ' - ' . $article->meta->{title};
%= include 'show_article', article => $article, single => 1

@@ archive.html.ep
% layout 'bootyblack';
% title config('name') . ' - Archive';
% my @months = qw(
%   January February March April May June
%   July August September October November December
% );
<h1>Archive</h1>
% foreach my $year (sort {$a<=>$b} keys %$articles) {
<h2><%= $year %></h2>
<ul class="months">
%   foreach my $month (sort {$a<=>$b} keys %{$articles->{$year}}) {
    <li><strong><%= $months[$month-1] %></strong>
%=      include 'list_articles_short', articles => $articles->{$year}{$month}
    </li>
%   }
</ul>
% }

@@ tag.html.ep
% my $feed_url = url_for 'tag_feed', tag => $tag, format => 'xml';
% layout 'bootyblack', tag_feed_url => $feed_url;
% title config('name') . ' - Tag ' . $tag;
<h1>Tag <%= $tag %></h1>
%= include 'list_articles', single => 0

@@ tags.html.ep
% layout 'bootyblack';
% title config('name') . ' - All tags';
<h1>All tags</h1>
<div id="tags">
% use List::Util qw(min max);
% my $min_size  = config 'tag_cloud_min';
% my $max_size  = config 'tag_cloud_max';
% my $min       = min values %$amount;
% my $max       = max values %$amount;
% my $count     = @$tags;
% foreach my $tag (@$tags) {
%   my $ratio   = $amount->{$tag} / $max;
%   my $size    = $min_size + $ratio * ($max_size - $min_size);
%   my $sstr    = sprintf '%.2f', $size;
%   my $url     = url_for 'tag', tag => $tag;
    <a href="<%= $url %>" style="font-size: <%= $sstr %>em"><%= $tag %></a>
% }
</div>

@@ page.html.ep
% layout 'bootyblack';
% title config('name') . ' - ' . $page->meta->{title};
<div id="page">
    <h1><%= $page->meta->{title} %></h1>
    <div id="content"><%== content2html $page %></div>
</div>

@@ draft.html.ep
% layout 'bootyblack';
% title config('name') . ' - ' . $draft->meta->{title};
%= include 'show_article', article => $draft, single => 1

@@ feed.xml.ep
<?xml version="1.0" encoding="<%= config 'encoding' %>"?>
<feed xmlns="http://www.w3.org/2005/Atom">
    <id><%= url_for('index')->to_abs %></id>
    <title><%= config 'name' %></title>
    <updated><%= feed_date $articles->[-1] %></updated>
    <author><name><%= config 'author' %></name></author>
    <link rel="self" href="<%= url_for('feed', format => 'xml')->to_abs %>"/>
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

@@ tag_feed.xml.ep
%= include 'feed';

@@ list_articles_short.html.ep
<ul class="articles">
% foreach my $article (@$articles) {
%   my $url = url_for 'article', article_url => $article->url;
    <li>
        <strong><a href="<%= $url %>">
            <%= $article->meta->{title} =%>
        </a></strong><br>
        <span class="meta">
            <span class="time"><%= date $article %></span>,
            <span class="tags">Tags:
%   foreach my $tag (@{$article->meta->{tags} // []}) {
                <a href="<%= url_for 'tag', tag => $tag %>"><%= $tag %></a>
%   }
            </span>
        </span>
    </li>
% }
</ul>

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
                <a href="<%= url_for 'tag', tag => $tag %>"><%= $tag %></a>
%       }
            </span>
%   if ($single) {
%       if ($article->prev) {
            <br><span class="prev_article">Previous: <a href="
                <%= url_for 'article', article_url => $article->prev->url =%>
            "><%= $article->prev->meta->{title} %></a></span>
%       }
%       if ($article->next) {
            <br><span class="next_article">Next: <a href="
                <%= url_for 'article', article_url => $article->next->url =%>
            "><%= $article->next->meta->{title} %></a></span>
%       }
%   }
        </div>
%   if ($single) {
%       if ($article->second) {
        <div class="teaser"><%== first2html $article %></div>
        <div id="content"><%== second2html $article %></div>
%       } else {
        <div id="content"><%== first2html $article %></div>
%       }
%   } else {
        <div class="teaser"><%== first2html $article %></div>
%       if ($article->second) {
        <p><a href="<%= url_for 'article', article_url => $article->url %>">
            <%= $article->separator // config 'separator' =%>
        </a></p>
%       }
%   }
    </div>

@@ not_found.html.ep
% layout 'bootyblack';
% title config('name') . ' - NOT FOUND!';
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
<link rel="alternate" type="application/atom+xml" title="ATOM feed" href="
    <%= url_for 'feed', format => 'xml' =%>
">
% { no strict 'vars'; if (defined $tag_feed_url) {
<link rel="alternate" type="application/atom+xml" title="ATOM tag feed" href="
    <%= $tag_feed_url =%>
">
% } }
</head>
<body>
<div id="header"><a href="<%= url_for 'index' %>">
    <%= config 'name' =%>
</a></div>
<ul id="menu">
    <li><a href="<%= url_for 'index' %>">Home</a></li>
    <li><a href="<%= url_for 'archive' %>">Archive</a></li>
    <li><a href="<%= url_for 'tags' %>">Tags</a></li>
% foreach my $page (@{booty->pages}) {
    <li><a href="<%= url_for 'page', page_url => $page->url %>">
        <%= $page->meta->{title} =%>
    </a></li>
% }
</ul>
<div id="main">
%= content
</div>
<address>
    &copy; <%= strftime '%Y', localtime %> <%= config 'author' %><br>
    <span id="footer"><%== config 'footer' %></span>
</address>
</body>
</html>

@@ screen_style.css.ep
% my $left = '25%';
html, body { margin: 0; padding: 0 }
body { font-family: Helvetica, sans-serif; line-height: 145%; color: #ddd;
    background: black url('/mojolicious-pinstripe.gif') repeat }
#header { margin: 100px 0 50px <%= $left %>;}
#header a { color: white; text-decoration: none; font-size: 2em;
    letter-spacing: 2ex; text-shadow: 0 0 30px white }
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
.article .meta { font-size: .8em; line-height: 120% }
.article .tags a { text-decoration: none; font-weight: bold }
.article .tags a:hover { text-decoration: underline }
.article .teaser, .article #content, #page #content { max-width: 80ex }
.article .teaser { font-weight: bold }
#articles .teaser { font-weight: normal }
ul.articles { font-size: .8em; line-height: 145% }
ul.articles .tags a { text-decoration: none; font-weight: bold }
#tags { margin: 3em 0 0; line-height: 200% }
#tags a { font-weight: bold; text-decoration: none; padding: 0 .5ex }
#tags a:hover { color: white }
#pager { font-size: .8em; margin: 2em 0 0; background-color: #222;
    padding: .2em .5em .1em }
address { margin: 0 0 10px <%= $left %>; padding: 30px 50px; text-align: right;
    background-color: #444; border: solid #111; border-width: 0 0 2px 2px;
    font-size:.8em; letter-spacing:.2ex; font-style: normal; line-height: 130% }
address a { color: inherit }
#footer { color: #888 }
pre { background-color: #222; padding: .5em 2ex; line-height: 130%;
    overflow: auto; max-width: 100ex }

@@ print_style.css.ep
html, body { margin: 0; padding: 0; color: black; background-color: white }
body { font-family: serif; line-height: 120% }
#header, #menu, #footer { display: none }
#main, address { border: none }
a { text-decoration: none; color: black }
