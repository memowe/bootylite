Bootylite - a simple file system based blog
===========================================

> **No trackbacks, no comments, no admin interface.  
> Just plain file based blogging with a feed and extra pages.**

After vti's great Bootylicious becoming too big and unmaintained this is
the next try to build a simple file system based blog on Mojolicious.

And here's how it works:

* write articles as text files and store them in the `articles` directory.
* done.

Look at

1. the `articles` directory to see examples
2. the `pages` directory to see examples
3. the `bootylite.conf` file to customize Bootylite.
4. the code.

The renderer for articles and pages is determined by the file name extension.
These renderers ship with Bootylite:

* .md -> Bootylite::Renderer::Markdown
* .html -> Bootylite::Renderer::HTML

It's easy to extend Bootylite to get more Renderers: just use
Bootylite::Renderer as a base class.

COPYRIGHT AND LICENCE
---------------------

Copyright (c) 2011 Mirko Westermeier, mail@memowe.de

See the file `MIT-LICENSE` in this distribution for details.
