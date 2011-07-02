package Bootylite::Plugin;

use Mojo::Base -base;

# Subclasses may override these methods

# will be called once at startup
sub startup {
    my ($self, $app) = @_;
}

# will be called before index page rendering
sub index {
    my ($self, $c) = @_;
}

# will be called before (paged) home page rendering
sub paged {
    my ($self, $c) = @_;
}

# will be called before article page rendering
sub article {
    my ($self, $c) = @_;
}

# will be called before archive page rendering
sub archive {
    my ($self, $c) = @_;
}

# will be called before tag page rendering
sub tag {
    my ($self, $c) = @_;
}

# will be called before tag cloud rendering
sub tags {
    my ($self, $c) = @_;
}

# will be called before page rendering
sub page {
    my ($self, $c) = @_;
}

# will be called before feed rendering
sub feed {
    my ($self, $c) = @_;
}

# will be called before tag feed rendering
sub tag_feed {
    my ($self, $c) = @_;
}

# will be called before draft rendering
sub draft {
    my ($self, $c) = @_;
}

# will be called after refreshing
sub refresh {
    my ($self, $c) = @_;
}

!! 42;
__END__
