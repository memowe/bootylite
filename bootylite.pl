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
app->secrets([$config->{secret} // 'Bootylite']);

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

# relative urls with url_for
# as in Mojolicious::Plugin::RelativeUrlFor
my $url_for = *Mojolicious::Controller::url_for{CODE};
{ no strict 'refs'; no warnings 'redefine';
    *Mojolicious::Controller::url_for = sub {
        my $c = shift;

        # create urls
        my $url     = $url_for->($c, @_)->to_abs;
        my $req_url = $c->req->url->to_abs;

        # return relative version if request url exists
        if ($req_url->to_string) {

            # use old Mojo::URL::to_rel
            my $rel_url = $url->clone;
            if ($rel_url->is_abs) {

                # Scheme and authority
                my $base = $req_url || $rel_url->base;
                $rel_url->base($base)->scheme(undef);
                $rel_url->userinfo(undef)->host(undef)->port(undef)
                    if $base->authority;

                # Path
                my @parts      = @{$rel_url->path->parts};
                my $base_path  = $base->path;
                my @base_parts = @{$base_path->parts};
                pop @base_parts unless $base_path->trailing_slash;
                while (@parts && @base_parts && $parts[0] eq $base_parts[0]) {
                    shift @$_ for \@parts, \@base_parts;
                }
                my $path = $rel_url->path(Mojo::Path->new)->path;
                $path->leading_slash(1) if $rel_url->authority;
                $path->parts([('..') x @base_parts, @parts]);
                $path->trailing_slash(1) if $url->path->trailing_slash;
            }

            # "repair" if empty
            return Mojo::URL->new('./') unless $rel_url->to_string;
            return $rel_url;
        }

        # or change nothing
        return $url;
    };
}

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
    $self->res->headers->content_type('text/html');
    $self->render(text => 'Done');
    $plugins->call_refresh($self);
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
<p class="pager"><%= link_to paged => {page => 2} => (class => 'btn small') => begin %>Earlier<% end %></p>
% }

@@ paged.html.ep
% layout 'bootyblack';
% title config('name') . ' - Page ' . $page;
<h1>Page <%= $page %></h1>
%= include 'list_articles', single => 0
<p class="pager">
% if (defined $prev_page) {
    <%= link_to paged => {page => $prev_page} => (class => 'btn small') => begin %>Later<% end %>
% }
% if (defined $next_page) {
    <%= link_to paged => {page => $next_page} => (class => 'btn small') => begin %>Earlier<% end %>
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
    <%= link_to $url => (style => 'font-size: ' . $sstr . 'em') => begin %><%= $tag %><% end %>
% }
</div><!-- tags -->

@@ page.html.ep
% layout 'bootyblack';
% title config('name') . ' - ' . $page->meta->{title};
<div class="page">
    <h1><%= $page->meta->{title} %></h1>
    <div class="page-content"><%== content2html $page %></div>
</div><!-- page -->

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
        <strong>
            <a href="<%= $url %>"><%= $article->meta->{title} %></a>
        </strong><br>
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
    <p class="meta">
        <span class="time"><%= date $article %></span>,
        <span class="tags">Tags:
%   foreach my $tag (@{$article->meta->{tags} // []}) {
            <a href="<%= url_for 'tag', tag => $tag %>"><%= $tag %></a>
%   }
        </span>
    </p>
    <div class="article-content">
%   if ($single) {
%       if ($article->second) {
        <div class="teaser"><%== first2html $article %></div>
        <div class="content"><%== second2html $article %></div>
%       } else {
        <div class="content"><%== first2html $article %></div>
%       }
%   } else {
        <div class="teaser"><%== first2html $article %></div>
%       if ($article->second) {
        <p><a href="<%= url_for 'article', article_url => $article->url %>">
            <%= $article->separator // config 'separator' =%>
        </a></p>
%       }
%   }
    </div><!-- article-content -->
%   if ($single) {
        <div class="pager">
%       if ($article->prev) {
            <p class="prev_article meta">Previous: <%= link_to article => {article_url => $article->prev->url} => begin %><%= $article->prev->meta->{title} %><% end %></p>
%       }
%       if ($article->next) {
            <p class="next_article meta">Next: <%= link_to article => {article_url => $article->next->url} => begin %><%= $article->next->meta->{title} %><% end %></p>
%       }
        </div>
%   }

</div><!-- article -->

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
<%= stylesheet '/styles.css' %>
<link rel="alternate" type="application/atom+xml" title="ATOM feed" href="<%= url_for 'feed', format => 'xml' %>">
% if (defined stash 'tag_feed_url') {
<link rel="alternate" type="application/atom+xml" title="ATOM tag feed" href="<%= stash 'tag_feed_url' %>">
% }
</head>
<body>
<div id="top">
    <div id="inner">
        <p id="name">
            <%= link_to config('name') => 'index' %>
        </p>
        <ul id="navi">
            <li><%= link_to Home    => 'index' %></li>
            <li><%= link_to Archive => 'archive' %></li>
            <li><%= link_to Tags    => 'tags' %></li>
% foreach my $page (@{booty->pages}) {
%   my $url = url_for 'page', page_url => $page->url;
            <li><a href="<%= $url %>"><%= $page->meta->{title} %></a></li>
% }
        </ul>
    </div><!-- inner -->
</div><!-- top -->
<div id="content">
%= content
</div><!-- content -->
<div id="footer">
    <p>&copy; <%= strftime '%Y', localtime %> <%= config 'author' %></p>
</div><!-- footer -->
</body>
</html>
