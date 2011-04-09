#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use Test::More tests => 12;

use Mojo::ByteStream 'b';
use FindBin '$Bin';
use lib "$Bin/../lib";
use Bootylite;

# build object
my $dir = "$Bin/pages";
my $b   = Bootylite->new(pages_dir => $dir);

# build pages
my @fns     = sort glob("$dir/*");
my @pages   = @{$b->pages};
is(scalar(@pages), 1, 'found 1 page');
my $page = shift @pages;
isa_ok($page, 'Bootylite::Page', 'page');
is($page->filename, $fns[0], 'right filename');

# get page by url
my $p = $b->get_page('foo_bar_baz');
ok(defined($p), 'page found by url');
isa_ok($p, 'Bootylite::Page', 'found page');
is($p->url, 'foo_bar_baz', 'found the right page');
is($p->content, "This *page* rocks.€\n", 'right content');

# caching
my $url = $p->url;
my $fn  = $p->filename;
my $raw = $p->raw_content;
rename $fn, "$fn.bak" or die $!;
is($b->get_page($url)->raw_content, $raw, "$url is still in cache");
$b->refresh;
is($b->get_page($url), undef, "$url is gone");
rename "$fn.bak", $fn or die $!;
is($b->get_page($url), undef, "$url is still gone");
$b->refresh;
is($b->get_page($url)->raw_content, $raw, "$url is back");

# render a markdown document
$p = $b->get_page('foo_bar_baz');
is(
    $b->render_page_part($p, 'content'),
    "<p>This <em>page</em> rocks.€</p>\n",
    'right html'
);

__END__
