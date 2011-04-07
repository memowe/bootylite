#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use Test::More tests => 100;
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
foreach my $i (1 .. $#articles+1) {
    my $url     = $articles[$i-1]->url;
    my $title   = $articles[$i-1]->meta->{title} // '';
    $t->text_like(
        "div.article:nth-child($i) h2 a[href\$=article/$url]",
        qr/$title/,
    );
}
is(
    $t->tx->res->dom->at('div.article:first-child .teaser p')->all_text,
    'foo teaser',
    'div.article:nth-child($i) .teaser p',
);
$t->text_is('div.article:nth-child(2) .teaser p', '€');
$t->text_is('div.article:nth-child(3) .teaser p', '€');
$t->text_is('div.article:nth-child(4) .teaser p', '€');

__END__
