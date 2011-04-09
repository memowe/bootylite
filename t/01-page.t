#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use Test::More tests => 9;

use FindBin '$Bin';
use lib "$Bin/../lib";

use_ok('Bootylite::Page');

# build object
my $pfn = "$Bin/pages/foo_bar_baz.md";
my $p   = Bootylite::Page->new(filename => $pfn);
isa_ok($p, 'Bootylite::Page', 'constructor return value');
is_deeply($p, {filename => $pfn}, 'right structure');

# build url part
is($p->url, 'foo_bar_baz', 'right url part');

# file name extension
is($p->extension, 'md', 'right file name extension');

# build decoded raw content
my $content = $p->raw_content;
like($content, qr/This page rocks/, 'right raw content');
like($content, qr/€/, 'right decoded raw content');

# build meta data
is_deeply($p->meta, {
    title   => 'Test that shit, yo!',
    tags    => [qw(quux quuux)],
}, 'right meta data');

# build content
is($p->content, "This page rocks.€\n", 'right content');

__END__
