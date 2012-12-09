#!/usr/bin/env perl

use 5.010000;

use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME            => 'Bootylite',
    VERSION_FROM    => 'lib/Bootylite.pm',
    AUTHOR          => 'Mirko Westermeier <mail@memowe.de>',
    EXE_FILES       => ['bootylite.pl'],
    PREREQ_PM => {
        'Mojolicious'           => '3.64',
        'Text::Markdown'        => '1.0',
        'Time::Local'           => '1.0',   # core
        'POSIX'                 => '1.0',   # core
        'List::Util'            => '1.0',   # core
    },
    test            => {TESTS => 't/*.t t/*/*.t t/*/*/*.t'}
);
