#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use Test::More tests => 93;
use Test::Mojo;

use FindBin '$Bin';
use lib "$Bin/../lib";

$ENV{MOJO_HOME} = "$Bin/../";
require "$ENV{MOJO_HOME}/bootylite.pl";
my $t = Test::Mojo->new;

# inject test directories
$t->app->booty->articles_dir("$Bin/articles");
$t->app->booty->pages_dir("$Bin/pages");

# home page
$t->get_ok('/')->status_is(200);
$t->text_is('title' => 'Bootylite')->text_is('h1', 'Home');
$t->element_exists('div#articles');
my @articles = reverse @{$t->app->booty->articles};
foreach my $i (0 .. 3) {
    my $url     = $articles[$i]->url;
    my $title   = $articles[$i]->meta->{title};
    my $n       = $i + 1;
    $t->text_like(".article:nth-child($n) a[href\$=articles/$url]", qr/$title/);
}
is(
    $t->tx->res->dom->at('div.article:first-child .teaser p')->all_text,
    'foo teaser',
    'div.article:nth-child(1) .teaser p',
);
$t->text_is('.article:nth-child(2) .teaser p', 'Hello ');
$t->text_is('.article:nth-child(3) .teaser p', '€');
$t->text_is('.article:nth-child(4) .teaser p', '€');
$t->text_is('#pager a', 'Earlier');
$t->element_exists('#pager a[href$=/page/2]');

# second page
$t->get_ok('/page/2')->status_is(200);
$t->text_is('title', 'Bootylite - Page 2')->text_is('h1', 'Page 2');
$t->element_exists('div#articles');
foreach my $i (4 .. 5) {
    my $url     = $articles[$i]->url;
    my $title   = $articles[$i]->meta->{title};
    my $n       = $i - 3;
    $t->text_like(".article:nth-child($n) a[href\$=articles/$url]", qr/$title/);
}
$t->text_is('.article:nth-child(1) .teaser p', '€');
$t->text_is('.article:nth-child(2) .teaser', '');

# latest article
my $url = '/articles/' . $articles[0]->url;
$t->get_ok($url)->status_is(200);
$t->text_is('title', 'Bootylite - Test that shit, yo!');
$t->text_is('h1', 'Test that shit, yo!');
$t->element_exists('.teaser')->element_exists('#content');

# archive
$t->get_ok('/articles')->status_is(200);
$t->text_is('title', 'Bootylite - Archive')->text_is('h1', 'Archive');
$t->text_is('h2', '2011')->text_is('ul.months > li > strong', 'April');
@articles = reverse @articles;
foreach my $i (0 .. 5) {
    my $url     = $articles[$i]->url;
    my $title   = $articles[$i]->meta->{title};
    my $n       = $i + 1;
    $t->text_like(
        "ul.articles li:nth-child($n) a[href\$=/articles/$url]",
        qr/$title/,
    );
}

# tag search
$t->get_ok('/tag/foo')->status_is(200);
$t->text_is('title', 'Bootylite - Tag foo')->text_is('h1', 'Tag foo');
$t->element_exists('#articles');
my $articles = $t->tx->res->dom->at('#articles')->children;
is(scalar(@$articles), 3, 'found 3 articles');

# tag cloud
$t->get_ok('/tags')->status_is(200);
$t->text_is('title', 'Bootylite - All tags')->text_is('h1', 'All tags');
$t->element_exists('#tags');
foreach my $tag (qw(foo bar baz)) {
    $t->text_is("#tags a[href\$=/tag/$tag]", $tag);
}

# menu with pages
$t->text_is('#menu a[href$=/pages/foo_bar_baz]', 'Test that shit, yo!');

# foo_bar_baz page
$t->get_ok('/pages/foo_bar_baz')->status_is(200);
$t->text_is('title', 'Bootylite - Test that shit, yo!');
$t->text_is('h1', 'Test that shit, yo!')->text_is('#page em', 'page');

# atom feed
@articles = @{$t->app->booty->articles};
$t->get_ok('/feed.xml')->status_is(200)->content_type_like(qr/xml/);
my $encoding = 'utf-8';
like(
    $t->tx->res->body,
    qr/<\?xml version="1\.0" encoding="$encoding"\?>/,
    'right feed encoding'
);
$t->text_is('title', 'Bootylite');
$t->text_is('author name', 'Zaphod Beeblebrox');
$articles = $t->tx->res->dom->find('feed entry');
is(scalar(@$articles), scalar(@articles), 'right number of articles in feed');
foreach my $i (0 .. $#articles) {
    my $url     = $articles[$i]->url;
    my $title   = $articles[$i]->meta->{title} // '';
    ok(defined($articles->[$i]->at("link[href\$=/articles/$url]")),'right url');
    is($articles->[$i]->at('title')->text, $title, 'right title');
}

# atom tag feed
$t->get_ok('/feed/void.xml')->status_is(404);
my @foo = $t->app->booty->get_articles_by_tag('foo');
$t->get_ok('/feed/foo.xml')->status_is(200)->content_type_like(qr/xml/);
my $foo = $t->tx->res->dom->find('feed entry');
is(scalar(@$foo), scalar(@foo), 'right number of foo tagged articles in feed');
foreach my $i (0 .. $#foo) {
    my $url     = $foo[$i]->url;
    my $title   = $foo[$i]->meta->{title} // '';
    ok(defined($foo->[$i]->at("link[href\$=/articles/$url]")),'right url');
    is($foo->[$i]->at('title')->text, $title, 'right title');
}

__END__
