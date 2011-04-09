#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use Test::More tests => 6;

use FindBin '$Bin';
use lib "$Bin/../lib";

use_ok('Bootylite::Renderer::Markdown');
use_ok('Bootylite::Renderer::HTML');

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

# build html renderer
my $hr = Bootylite::Renderer::HTML->new;
isa_ok($hr, 'Bootylite::Renderer::HTML', 'constructor return value');

# render html
$html = <<EOD;
<!doctype html><html><head><title>Hello world!</title></head>
<body><p>Hello world!</p></body></html>
EOD
is($hr->render($html), $html, 'right html "output"');

__END__
