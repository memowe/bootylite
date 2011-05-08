package Bootylite::Plugin::Comments;

use Mojo::Base 'Bootylite::Plugin';
use Bootylite::Plugin::Comments::Comment;
use Bootylite::Article;
use Mojo::ByteStream 'b';

has comments_dir    => sub { die 'no comments directory given' };
has encoding        => 'utf-8';
has 'render_cb';
has 'submit_bridge';
has all_comments    => sub { shift->_inject_comments->all_comments };
has comments        => sub { shift->_inject_comments->comments }; # {url => []}
has moderated       => 1;

sub _inject_comments {
    my $self = shift;

    # glob article directories
    my @article_dirs = sort glob $self->comments_dir . '/*';

    # build
    my (%all_comments, %comments);
    foreach my $dir (@article_dirs) {
        my (@all_comments, @comments);

        # build article url
        $dir =~ m|([^/]+)$|;
        my $url = $1;

        # scan all comment files in the directory
        foreach my $filename (sort glob "$dir/*") {

            # build
            my $comment = Bootylite::Plugin::Comments::Comment->new(
                filename    => $filename,
                encoding    => $self->encoding,
                article_url => $url,
            );

            # set non-default renderer
            $comment->render_cb($self->render_cb) if $self->render_cb;

            # push comments
            push @all_comments, $comment;
            push @comments, $comment
                unless $self->moderated and $comment->meta->{hidden};
        }

        # build comments hashes
        $all_comments{$url} = \@all_comments;
        $comments{$url}     = \@comments;
    }

    # inject and chain
    return $self->all_comments(\%all_comments)->comments(\%comments);
}

sub startup {
    my ($self, $app) = @_;

    # inject all_comments attribute
    Bootylite::Article->attr(all_comments => sub {
        $self->all_comments->{shift->url} // [];
    });

    # inject comments attribute
    Bootylite::Article->attr(comments => sub {
        $self->comments->{shift->url} // [];
    });

    # inject all_comment_count attribute
    Bootylite::Article->attr(all_comment_count => sub {
        scalar @{shift->all_comments};
    });

    # inject comment_count attribute
    Bootylite::Article->attr(comment_count => sub {
        scalar @{shift->comments};
    });

    # create a route to fetch posted comments
    my $r = $self->submit_bridge // $app->routes;
    $r->route('/comment')->via('post')->to(cb => sub {
        $self->post_comment(@_);
    })->name('post_comment');

    # create a route to build a comment feed
    $app->routes->route('/comment_feed')->to(cb => sub {
        $self->comment_feed(@_);
    })->name('comment_feed');
}

# post a comment
sub post_comment {
    my ($self, $c) = @_;

    # cleanup
    my $article_url = $c->param('article_url');
    my $name        = $c->param('name');
    my $mail        = $c->param('mail');
    my $ip          = $c->tx->remote_address;
    my $comment     = $c->param('comment');
    s/[\r\n]+/ /g for $name, $mail;

    # create a file name
    my ($sec, $min, $hour, $day, $m, $y) = localtime;
    my $mon         = $m + 1;
    my $year        = $y + 1900;
    my $dir         = $self->comments_dir . '/' . $article_url;
    my $fn_mask     = join '-' => '%4d', ('%02d') x 5;
    my $filename    = sprintf $fn_mask, $year, $mon, $day, $hour, $min, $sec;
    my $num         = 0;
    my $path        = sprintf '%s/%s-%04d', $dir, $filename, $num;
    $path = sprintf '%s/%s-%04d', $dir, $filename, ++$num while -e $path;

    # create raw_content
    my $hidden      = $self->moderated ? '1' : '0';
    my $raw_content = sprintf <<'EOF', $name, $mail, $ip, $hidden, $comment;
Name: %s
Mail: %s
IP: %s
HIDDEN: %s

%s
EOF

    # save comment
    Bootylite::Plugin::Comments::Comment->new(
        filename    => $path,
        raw_content => $raw_content,
    )->save;

    # done
    $c->flash(comment_saved => 1);
    $self->refresh($c);
    my $url = $c->url_for('article', article_url => $article_url);
    $c->redirect_to($url . '#comments');
}

# a feed of all comments
sub comment_feed {
    my ($self, $c) = @_;

    # right format?
    $c->redirect_to('comment_feed', format => 'xml') and return
        unless $c->stash('format') eq 'xml';

    # build flattened comments list
    my @comments = map {@$_} values %{$self->all_comments};
    @comments = sort {$a->time <=> $b->time} @comments;

    my $feed_url = $c->url_for('comment_feed', format => 'xml')->to_abs;
    my $feed = '<?xml version="1.0" encoding="'.$c->config('encoding').'"?>';
    $feed .= '<feed xmlns="http://www.w3.org/2005/Atom">';
    $feed .= '<id>' . $feed_url . '</id>';
    $feed .= '<title>' . $c->config('name') . ' comment feed</title>';
    $feed .= '<updated>' . $c->feed_date($comments[-1]) . '</updated>';
    $feed .= '<link rel="self" href="' . $feed_url . '"/>';
    foreach my $comm (@comments) {
        my $aurl = $comm->article_url;
        my $url  = $c->url_for('article', article_url => $aurl)->to_abs;
        my $html = b($comm->html)->html_escape;
        $feed .= '<entry>';
        $feed .= '<id>' . $url->to_abs . '#comments</id>';
        $feed .= '<link rel="alternate" href="' . $url . '#comments"/>';
        $feed .= '<title>'
                . 'Comment from ' . $comm->meta->{name} . ', '
                . $c->date($comm) . '</title>';
        $feed .= '<updated>' . $c->feed_date($comm) . '</updated>';
        $feed .= '<author><name>' . $comm->meta->{name} . '</name></author>';
        $feed .= '<content type="html">' . $html . '</content>';
        $feed .= '</entry>';
    }
    $feed .= '</feed>';

    $c->res->headers->content_type('application/atom+xml');
    $c->render_text($feed);
}

# no need to overwrite the article and listing hooks.
# comment_count and comments are available as Article methods

sub refresh {
    my ($self, $c) = @_;

    # refresh articles too
    $c->booty->refresh;

    # they will load on demand lazily
    delete $self->{comments};
}

!! 42;

__END__
