package Bootylite::Renderer;

use Mojo::Base -base;

# Subclasses must define a file name extension
has extension => sub { die 'not implemented' };

# Subclasses must implement a render method
# which should transform plaintext to html.
# See Bootylite::Markdown for an example.
sub render { die 'not implemented' }

!! 42;
__END__
