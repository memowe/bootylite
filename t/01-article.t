#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use Test::More tests => 22;

use FindBin '$Bin';
use lib "$Bin/../lib";

use_ok('Bootylite::Article');

# get article filenames
my @afn = sort glob("$Bin/articles/*");

# build object
my $a = Bootylite::Article->new(filename => $afn[0]);
isa_ok($a, 'Bootylite::Article', 'constructor return value');
is_deeply($a, {filename => $afn[0]}, 'right structure');

# build time
is_deeply($a->time, 1301608800, 'right time');

# build url part
is($a->url, 'no_hour_and_minute', 'right url part');

# file name extension
is($a->extension, 'md', 'right file name extension');

# build another article
$a = Bootylite::Article->new(filename => $afn[1]);

# build time
is_deeply($a->time, 1302003420, 'right time');

# build url part
is($a->url, 'test2', 'right url part');

# file name extension
is($a->extension, 'md', 'right file name extension');

# build decoded raw content
my $content = $a->raw_content;
like($content, qr/Test that shit, yo!/, 'right raw content');
like($content, qr/€/, 'right decoded raw content');
like($content, qr/foo/, 'right raw content');

# build meta data
is_deeply($a->meta, {
    title   => 'Test that shit, yo!',
    tags    => [qw(foo bar)],
}, 'right meta data');

# build content data
is($a->first, "€\n\nfoo\n", 'right first part');
is($a->separator, undef, 'no separator found');
is($a->second, undef, 'no second part');

# build an article with second part
$a = Bootylite::Article->new(filename => $afn[2]);
is($a->first, "€\n\n", 'right first part');
is($a->separator, undef, 'no separator found');
is($a->second, "foo\n", 'right second part');

# build an article with separator text
$a = Bootylite::Article->new(filename => $afn[3]);
is($a->first, "€\n\n", 'right first part');
is($a->separator, 'qux quux', 'right separator');
is($a->second, "foo\n", 'right second part');

__END__
