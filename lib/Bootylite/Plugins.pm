package Bootylite::Plugins;

use Mojo::Base -base;
use Mojo::Util 'camelize';
use Mojo::Loader 'load_class';

has plugins => sub { [] };

sub add {
    my ($self, $name, $conf) = @_;

    # try to load
    $name = camelize $name;
    my $module  = "Bootylite::Plugin::$name";
    my $error   = load_class $module;
    die $error->to_string           if ref $error;
    die "plugin $name not found"    if $error;

    # create, configure and add
    my $plugin = $module->new($conf);
    push @{$self->plugins}, $plugin;
}

sub call_startup    { $_->startup(@_)   for @{shift->plugins} };
sub call_index      { $_->index(@_)     for @{shift->plugins} };
sub call_paged      { $_->paged(@_)     for @{shift->plugins} };
sub call_article    { $_->article(@_)   for @{shift->plugins} };
sub call_archive    { $_->archive(@_)   for @{shift->plugins} };
sub call_tag        { $_->tag(@_)       for @{shift->plugins} };
sub call_tags       { $_->tags(@_)      for @{shift->plugins} };
sub call_page       { $_->page(@_)      for @{shift->plugins} };
sub call_feed       { $_->feed(@_)      for @{shift->plugins} };
sub call_tag_feed   { $_->tag_feed(@_)  for @{shift->plugins} };
sub call_draft      { $_->draft(@_)     for @{shift->plugins} };
sub call_refresh    { $_->refresh(@_)   for @{shift->plugins} };

!! 42;
__END__
