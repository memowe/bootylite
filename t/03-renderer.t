#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use Test::More tests => 3;

use FindBin '$Bin';
use lib "$Bin/../lib";

use_ok('Bootylite::Renderer::Markdown');

# build markdown renderer
my $mdr = Bootylite::Renderer::Markdown->new;
isa_ok($mdr, 'Bootylite::Renderer::Markdown', 'constructor return value');

# render markdown
my $markdown = <<EOD;
Hello **world**!

foo  
bar
EOD
my $html = <<EOD;
<p>Hello <strong>world</strong>!</p>

<p>foo <br>
bar</p>
EOD
is($mdr->render($markdown), $html, 'right html output');

__END__
