#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use Test::More tests => 30;
use Test::Mojo;

use FindBin '$Bin';
use lib "$Bin/../lib";

# use custom Bootylite to test
$ENV{MOJO_HOME}   = "$Bin/../";
$ENV{MOJO_CONFIG} = 't/bootylite_plugins.conf';
require "$ENV{MOJO_HOME}/bootylite.pl";
my $t = Test::Mojo->new;

# startup and index
$t->get_ok('/')->status_is(200)->content_is('foo=42,bar=666');

# other pages
$t->get_ok('/page/1')           ->status_is(200)->content_is('test paged');
$t->get_ok('/articles/test2')   ->status_is(200)->content_is('test article');
$t->get_ok('/articles')         ->status_is(200)->content_is('test archive');
$t->get_ok('/tag/foo')          ->status_is(200)->content_is('test tag');
$t->get_ok('/tags')             ->status_is(200)->content_is('test tags');
$t->get_ok('/pages/foo_bar_baz')->status_is(200)->content_is('test page');
$t->get_ok('/feed.xml')         ->status_is(200)->content_is('test feed');
$t->get_ok('/feed/foo.xml')     ->status_is(200)->content_is('test tag feed');
$t->get_ok('/refresh')          ->status_is(200)->content_is('test refresh');

__END__
