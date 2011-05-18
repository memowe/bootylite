package Bootylite::Renderer::HTML;

use Mojo::Base 'Bootylite::Renderer';

has extension => 'html';

sub render { $_[1] };

!! 42;
__END__
