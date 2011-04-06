package Bootylite::Renderer::Markdown;

use Mojo::Base 'Bootylite::Renderer'; 
use Text::Markdown;

has extension => 'md';

has parser => sub { Text::Markdown->new(empty_element_suffix => '>') };

sub render { shift->parser->markdown(shift) };

!! 42;
__END__
