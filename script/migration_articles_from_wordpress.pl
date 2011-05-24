#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use WordPress::XMLRPC;

#Configuration
my $username     = 'your_wordpress_username';
my $password     = 'your_wordpress_admin';
my $url          = 'your_wordpress_url';
#Number of items to migrate
my $number_post   =  1000;
my $path_article = "$ENV{HOME}/src/articles";

my $wordpress = WordPress::XMLRPC->new({
    username => $username,
    password => $password,
    proxy    => $url,
});
my $get_post  = $wordpress->getRecentPosts($number_post);

foreach my $article ( @{$get_post} ) {
    my $year  = substr($article->{date_created_gmt}, 0, 4);
    my $month = substr($article->{date_created_gmt}, 4, 2);
    my $day   = substr($article->{date_created_gmt}, 6, 2);
    my $hour  = substr($article->{date_created_gmt}, 9, 2);
    my $min   = substr($article->{date_created_gmt}, 12, 2);

    my $title  = $article->{wp_slug};
    $title     =~ s/-/_/g;

    my $filename = $year . '-' . $month . '-' . $day . '-' . $hour . '-' . $min . '_' . $title . '.html';

    open (ARTICLES, ">:encoding(UTF-8)", "$path_article/$filename");
    print ( ARTICLES "Title: " . $article->{title}, "\n");
    print ( ARTICLES "Tags: " . $article->{mt_keywords}, "\n" );
    print ( ARTICLES "\n" );
    print ( ARTICLES $article->{description});
    close(ARTICLES);

    print "The article $title was migrate in $filename", "\n";
}

