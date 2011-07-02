#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use Test::More tests => 13;

use FindBin '$Bin';
use lib "$Bin/../lib";
use Bootylite;

# build object
my $dir = "$Bin/drafts";
my $b   = Bootylite->new(drafts_dir => $dir);

# build drafts
my @fns     = sort glob("$dir/*");
my @drafts  = @{$b->drafts};
is(scalar(@drafts), 2, 'found 2 drafts');
my $draft1  = shift @drafts;
isa_ok($draft1, 'Bootylite::Article', 'first draft');
is($draft1->filename, $fns[0], 'right filename');
my $draft2  = shift @drafts;
isa_ok($draft2, 'Bootylite::Article', 'second draft');
is($draft2->filename, $fns[1], 'right filename');

# get drafts by url
my $d1 = $b->get_draft('draft1');
ok(defined($d1), 'draft1 found by url');
isa_ok($d1, 'Bootylite::Article', 'found draft1');
is($d1->url, 'draft1', 'found the right draft');
is($d1->first, "first draft\n", 'right content');
my $d2 = $b->get_draft('draft2');
ok(defined($d2), 'draft2 found by url');
isa_ok($d2, 'Bootylite::Article', 'found draft2');
is($d2->url, 'draft2', 'found the right draft');
is($d2->first, "second draft\n", 'right content');

__END__
