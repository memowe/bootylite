#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use Test::More tests => 46;
use Test::Mojo;

use FindBin '$Bin';
use lib "$Bin/../lib";

$ENV{MOJO_HOME} = "$Bin/../";
require "$ENV{MOJO_HOME}/bootylite.pl";
my $t = Test::Mojo->new;
$t->app->log->level('error');

# inject test articles directory
$t->app->booty->articles_dir("$Bin/articles");

# home page redirect
$t->max_redirects(0);
$t->get_ok('/')->status_is(302);

# home page
$t->max_redirects(1);
$t->get_ok('/')->status_is(200);
like($t->tx->req->url, qr|/index.html$|, 'got /index.html');
$t->text_is('title' => $t->app->config('name'));
$t->element_exists('div#articles');
my @articles = reverse @{$t->app->booty->articles};
foreach my $i (0 .. $#articles) {
    my $url     = $articles[$i]->url;
    my $title   = $articles[$i]->meta->{title} // '';
    my $n       = $i + 1;
    $t->text_like(".article:nth-child($n) a[href\$=article/$url]", qr/$title/);
}
is(
    $t->tx->res->dom->at('div.article:first-child .teaser p')->all_text,
    'foo teaser',
    'div.article:nth-child($i) .teaser p',
);
$t->text_is('div.article:nth-child(2) .teaser p', '€');
$t->text_is('div.article:nth-child(3) .teaser p', '€');
$t->text_is('div.article:nth-child(4) .teaser p', '€');

# latest article
my $url = '/article/' . $articles[0]->url;
$t->get_ok($url)->text_is('h1', 'Test that shit, yo!');
$t->element_exists('.teaser')->element_exists('#content');

# tag search
$t->get_ok('/tag/foo')->text_is('h1', 'Tag foo')->element_exists('#articles');
my $articles = $t->tx->res->dom->at('#articles')->children;
is(scalar(@$articles), 2, 'found two articles');

# tag cloud
$t->get_ok('/tags')->text_is('h1', 'All tags')->element_exists('#tags');
foreach my $tag (qw(foo bar baz)) {
    $t->text_is("#tags a[href\$=/tag/$tag]", $tag);
}

# atom feed
@articles = reverse @{$t->app->booty->articles};
$t->get_ok('/index.xml')->content_type_like(qr/xml/);
my $encoding = $t->app->config('encoding');
like(
    $t->tx->res->body,
    qr/<\?xml version="1\.0" encoding="$encoding"\?>/,
    'right feed encoding'
);
$t->text_is('title', $t->app->config('name'));
$t->text_is('author name', $t->app->config('author'));
my $feed_dom = $t->tx->res->dom;
$articles = $feed_dom->find('feed entry');
is(scalar(@$articles), scalar(@articles), 'right number of articles in feed');
foreach my $i (0 .. $#articles) {
    my $url     = $articles[$i]->url;
    my $title   = $articles[$i]->meta->{title} // '';
    ok(defined($articles->[$i]->at("link[href\$=/article/$url]")), 'right url');
    is($articles->[$i]->at('title')->text, $title, 'right title');
}

__END__
